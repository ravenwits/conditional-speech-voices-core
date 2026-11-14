"""Create a provider manifest, then measure its supplied recordings for the builder."""
import argparse
import json
import math
from html import escape
from urllib.parse import quote
import statistics
from pathlib import Path
import re
import subprocess
from build_voice_pack import CONTRACT


TRIAL_GROUPS = {
    'Dialogue': ('Explore_1', 'Explore_2', 'Explore_3', 'FoodEaten_1'),
    'Whisper': ('Whisper_Thirst_1', 'Whisper_Thirst_2', 'NativeWhisperCall_1'),
    'Shout': ('NativeCall_1', 'NativeCall_2', 'NativeCall_3'),
    'Breath': ('NativeBreath_1', 'NativeBreath_2'),
    'Effort': ('NativeEffort_1', 'NativeEffort_2', 'NativeEffort_3'),
    'Pain': ('NativePain_1', 'NativePain_2', 'NativePain_3'),
}


def listen_trial(manifest):
    config = json.loads(manifest.read_text(encoding='utf-8'))
    if not config.get('trial'):
        raise ValueError('This command requires a manifest created with init --trial')
    bank = config['bank']
    voice = bank['voices'][0]['id']
    cards = []
    for category, slots in TRIAL_GROUPS.items():
        cards.append(f'<h2>{escape(category)}</h2>')
        for slot in slots:
            clip = bank['data']['clips'][voice + '_' + slot]
            source = config['assets'][clip['sound']]['source']
            caption = escape(bank['lines'].get(slot, slot))
            if (manifest.parent / source).is_file():
                player = f'<audio controls preload="none" src="{quote(source)}"></audio>'
            else:
                player = f'<p>Missing: {escape(source)}</p>'
            cards.append(f'<article><h3>{escape(slot)}</h3><p>{caption}</p>{player}</article>')
    output = manifest.with_suffix('.listen.html')
    output.write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8">'
        '<title>Voice trial</title><style>body{max-width:740px;margin:2rem auto;padding:0 1rem;'
        'font:16px system-ui}article{margin:1rem 0;padding:0.5rem 1rem;border:1px solid #bbb}'
        'audio{width:100%}</style><h1>Voice trial</h1>'
        '<p>Playback uses the supplied recordings at their original levels.</p>'
        + ''.join(cards)
        + '<script>document.addEventListener("play",e=>document.querySelectorAll("audio")'
          '.forEach(a=>{if(a!==e.target)a.pause()}),true)</script></html>',
        encoding='utf-8',
    )
    return output


def initialize(output, voice, language, female=False, trial=False, texts=None):
    if not re.fullmatch(r'[a-z][a-z0-9_]*', voice) or not re.fullmatch(r'[A-Z_]{2,8}', language):
        raise ValueError('Use a lowercase voice ID and an uppercase language code')
    if output.exists():
        raise ValueError('Manifest already exists')
    bank = json.loads(Path(__file__).with_name('voice-template-v1.json').read_text(encoding='utf-8'))
    bank.update(id='csv.' + voice, language=language, revision='1.0.0', contract=1)
    bank['voices'] = [dict(id=voice, name=voice.title(), prefix='VoiceCSV' + voice.title().replace('_', '') + 'P',
                          base='VoiceFemale' if female else 'VoiceMale', preview='NativeCall_1',
                          previewLines=['Explore_2', 'Explore_3', 'FoodEaten_1', 'Panic_3', 'Thirst_1', 'Injured_3'],
                          previewLast='Injured_3')]
    assets = {}
    required = set(CONTRACT['slots'])
    if bank.get('needTiers') == 1:
        required.update(CONTRACT['extensions']['needTiers']['slots'])
    if bank.get('criticalHealth') == 1:
        required.update(CONTRACT['extensions']['criticalHealth']['slots'])
    if trial:
        required = {slot for slots in TRIAL_GROUPS.values() for slot in slots}
        if not required <= bank["lines"].keys():
            raise ValueError("Trial slots are missing from the voice template")
        bank["lines"] = {slot: bank["lines"][slot] for slot in sorted(required)}
    for line in sorted(required):
        key = voice + '_' + line
        sound = 'CSV_' + key
        bank['data']['clips'][key] = dict(sound=sound, duration=0, gain=1)
        assets[sound] = dict(source='audio/' + key + '.mp3', volume=1.2)
    config = dict(schema=1, module='CSV_' + voice.upper(), modId='CSV-Voice-' + voice,
                  name=voice.title() + ' Voice', author='Your name',
                  description='Voice pack for Conditional Speech Voices Core.', bank=bank, assets=assets)
    if trial:
        config["trial"] = True
    from voice_project import setup
    setup(config, texts)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding='utf-8')


def measure(manifest, ffmpeg, allow_missing=False):
    from voice_project import digest, contained, category, voice_id, read, write
    config = read(manifest)
    measurements = {}
    loudness = {}
    cache = config.setdefault('authoring', {}).setdefault('measurements', {})
    reused = {}
    missing=[]
    for sound, asset in config['assets'].items():
        path = contained(manifest.parent, asset['source'])
        if not path.is_file():
            if allow_missing:
                missing.append(sound)
                continue
            raise ValueError('Missing recording ' + str(path))
        checksum = digest(path)
        saved = reused.get((checksum, asset.get('volume', 1.2)), cache.get(sound, {}))
        if saved.get('sha256') == checksum and saved.get('volume') == asset.get('volume', 1.2):
            measurements[sound] = (saved['duration'], saved['peakLimit'])
            loudness[sound] = saved['loudness']
            cache[sound] = saved
            reused[(checksum, asset.get('volume', 1.2))] = saved
            continue
        result = subprocess.run([ffmpeg, '-v', 'error', '-i', str(path), '-f', 's16le',
                                 '-ac', '1', '-ar', '16000', 'pipe:1'], capture_output=True, check=True, timeout=90)
        duration = round(len(result.stdout) / 32)
        if duration <= 0:
            raise ValueError('Empty decoded recording ' + sound)
        result = subprocess.run([ffmpeg, '-hide_banner', '-nostats', '-i', str(path), '-af',
            'loudnorm=I=-20:TP=-1:LRA=11:print_format=json', '-f', 'null', '-'],
            capture_output=True, text=True, check=True, timeout=90)
        stats = json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]
        peak = float(stats['input_tp'])
        integrated=float(stats['input_i'])
        # Integrated loudness is undefined for some very short efforts. Keep that
        # distinct from a silent file and never write Infinity into project JSON.
        loudness[sound] = dict(integratedLUFS=integrated if math.isfinite(integrated) else None, truePeakDB=peak, volume=asset.get('volume',1.2))
        if not math.isfinite(peak):
            raise ValueError('Silent or invalid recording ' + sound)
        measurements[sound] = (duration, 10 ** ((-1 - peak) / 20) / asset.get('volume', 1.2))
        cache[sound] = dict(sha256=checksum, volume=asset.get('volume',1.2), duration=duration,
                           peakLimit=measurements[sound][1], loudness=loudness[sound])
        reused[(checksum, asset.get('volume', 1.2))] = cache[sound]
    for key, clip in config['bank']['data']['clips'].items():
        if clip['sound'] not in measurements: continue
        clip['duration'], config['bank']['peaklimits'][key] = measurements[clip['sound']]
    write(manifest,config)
    report = manifest.with_suffix(".loudness.json")
    groups={}
    for key,clip in config['bank']['data']['clips'].items():
        if clip['sound'] not in loudness: continue
        sound=clip['sound']; row=loudness[sound]
        if row['integratedLUFS'] is None: continue
        kind=category(key[len(voice_id(config))+1:])
        level=row['integratedLUFS']+20*math.log10(row['volume']*clip.get('gain',1))
        groups.setdefault(kind,{})[sound]=level
    flags=[]
    for kind,values in groups.items():
        median=statistics.median(values.values())
        for sound,level in values.items():
            if abs(level-median)>4: flags.append(dict(sound=sound,category=kind,level=level,median=median))
    write(report,dict(recordings=loudness,outliers=flags,missing=missing,
                     unmeasurable=[sound for sound,row in loudness.items() if row['integratedLUFS'] is None],
                     note='Short takes may have no integrated loudness value. Review acting before changing gain; no automatic normalization.'))


if __name__ == '__main__':
    import sys
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('init')
    create.add_argument('manifest', type=Path)
    create.add_argument('--voice', required=True)
    create.add_argument('--language', required=True)
    create.add_argument('--female', action='store_true')
    create.add_argument('--trial', action='store_true', help='Prepare only 18 listening samples')
    create.add_argument('--texts', type=Path, help='Same-language project or text catalog; no audio is copied')
    listen = commands.add_parser('listen', help='Create a local listening page for a trial')
    listen.add_argument('manifest', type=Path)
    scan = commands.add_parser('measure')
    scan.add_argument('manifest', type=Path)
    scan.add_argument('--ffmpeg', required=True)
    editor = commands.add_parser('edit', help='Open a local recording workbench')
    editor.add_argument('manifest', type=Path)
    editor.add_argument('--ffmpeg', default='ffmpeg')
    editor.add_argument('--core', type=Path, default=Path(__file__).resolve().parents[2])
    editor.add_argument('--port', type=int, default=0)
    editor.add_argument('--no-browser', action='store_true')
    for name in ('promote', 'update'):
        sub = commands.add_parser(name, help='Compare against the current template; --apply preserves existing work')
        sub.add_argument('manifest', type=Path)
        sub.add_argument('--apply', action='store_true')
    queue = commands.add_parser('jobs', help='Export only missing or explicitly rejected recordings')
    queue.add_argument('manifest', type=Path)
    queue.add_argument('--rate', type=float, default=0, help='Optional budget units per caption/direction character')
    record = commands.add_parser('import', help='Import an existing recording into a slot')
    record.add_argument('manifest', type=Path)
    record.add_argument('slot')
    record.add_argument('source', type=Path)
    record.add_argument('--ffmpeg', default='ffmpeg')
    batch = commands.add_parser('import-folder', help='Match files named by slot; resume without replacing existing takes')
    batch.add_argument('manifest', type=Path)
    batch.add_argument('folder', type=Path)
    batch.add_argument('--ffmpeg', default='ffmpeg')
    ready = commands.add_parser('package', help='Measure, check and build approved recordings')
    ready.add_argument('manifest', type=Path)
    ready.add_argument('output', type=Path)
    ready.add_argument('--ffmpeg', default='ffmpeg')
    ready.add_argument('--core', type=Path, default=Path(__file__).resolve().parents[2])
    worker = commands.add_parser('run', help='Optional external worker; not needed for your own recordings')
    worker.add_argument('manifest', type=Path)
    worker.add_argument('--ffmpeg', default='ffmpeg')
    worker.add_argument('--budget', type=float, required=True)
    worker.add_argument('--rate', type=float, required=True)
    worker.add_argument('--max-jobs', type=int, default=18)
    resolve = commands.add_parser('resolve', help='After checking an interrupted external job, allow an explicit retry')
    resolve.add_argument('manifest', type=Path)
    resolve.add_argument('job_id')
    raw = sys.argv[1:]
    command = []
    if raw[:1] == ['run'] and '--' in raw:
        separator = raw.index('--')
        command, raw = raw[separator+1:], raw[:separator]
    args = parser.parse_args(raw)
    if args.command == 'init':
        initialize(args.manifest, args.voice, args.language, args.female, args.trial, args.texts)
    elif args.command == "listen":
        print(listen_trial(args.manifest))
    elif args.command == 'measure':
        measure(args.manifest, args.ffmpeg)
    elif args.command == 'edit':
        from voice_workbench import serve
        serve(args.manifest.resolve(), args.ffmpeg, args.core.resolve(), args.port, not args.no_browser)
    else:
        from voice_project import refresh, jobs, write, import_audio, import_folder, package, run_jobs, resolve_job
        path = args.manifest.resolve()
        if args.command in ('promote', 'update'):
            print(json.dumps(refresh(path, args.apply), indent=2))
        elif args.command == 'jobs':
            output = path.with_suffix('.jobs.json')
            write(output, jobs(path, args.rate))
            print(output)
        elif args.command == 'import':
            import_audio(path, args.slot, args.source.resolve(), args.ffmpeg)
        elif args.command == 'import-folder':
            print(import_folder(path, args.folder.resolve(), args.ffmpeg))
        elif args.command == 'package':
            print(package(path, args.output.resolve(), args.ffmpeg, args.core.resolve()))
        elif args.command == 'run':
            print(run_jobs(path, command, args.ffmpeg, args.budget, args.rate, args.max_jobs))
        elif args.command == 'resolve':
            print(resolve_job(path, args.job_id))
    print('Prepared', args.manifest)
