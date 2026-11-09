"""Create a provider manifest, then measure its supplied recordings for the builder."""
import argparse
import json
import math
from pathlib import Path
import re
import subprocess
from build_voice_pack import CONTRACT


def initialize(output, voice, language, female=False):
    if not re.fullmatch(r'[a-z][a-z0-9_]*', voice) or not re.fullmatch(r'[A-Z_]{2,8}', language):
        raise ValueError('Use a lowercase voice ID and an uppercase language code')
    if output.exists():
        raise ValueError('Manifest already exists')
    bank = json.loads(Path(__file__).with_name('voice-template-v1.json').read_text(encoding='utf-8'))
    bank.update(id='csv.' + voice, language=language, revision='1.0.0', contract=1)
    bank['voices'] = [dict(id=voice, name=voice.title(), prefix='VoiceCSV' + voice.title().replace('_', '') + 'P',
                          base='VoiceFemale' if female else 'VoiceMale', preview='NativeCall_1')]
    assets = {}
    required = set(CONTRACT['slots'])
    if bank.get('needTiers') == 1:
        required.update(CONTRACT['extensions']['needTiers']['slots'])
    if bank.get('criticalHealth') == 1:
        required.update(CONTRACT['extensions']['criticalHealth']['slots'])
    for line in sorted(required):
        key = voice + '_' + line
        sound = 'CSV_' + key
        bank['data']['clips'][key] = dict(sound=sound, duration=0, gain=1)
        assets[sound] = dict(source='audio/' + key + '.mp3', volume=1.2)
    config = dict(schema=1, module='CSV_' + voice.upper(), modId='CSV-Voice-' + voice,
                  name=voice.title() + ' Voice', author='Your name',
                  description='Voice pack for Conditional Speech Voices Core.', bank=bank, assets=assets)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding='utf-8')


def measure(manifest, ffmpeg):
    config = json.loads(manifest.read_text(encoding='utf-8'))
    measurements = {}
    for sound, asset in config['assets'].items():
        path = (manifest.parent / asset['source']).resolve()
        if not path.is_file():
            raise ValueError('Missing recording ' + str(path))
        result = subprocess.run([ffmpeg, '-v', 'error', '-i', str(path), '-f', 's16le',
                                 '-ac', '1', '-ar', '16000', 'pipe:1'], capture_output=True, check=True)
        duration = round(len(result.stdout) / 32)
        if duration <= 0:
            raise ValueError('Empty decoded recording ' + sound)
        result = subprocess.run([ffmpeg, '-hide_banner', '-nostats', '-i', str(path), '-af',
            'loudnorm=I=-20:TP=-1:LRA=11:print_format=json', '-f', 'null', '-'],
            capture_output=True, text=True, check=True)
        stats = json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]
        peak = float(stats['input_tp'])
        if not math.isfinite(peak):
            raise ValueError('Silent or invalid recording ' + sound)
        measurements[sound] = (duration, 10 ** ((-1 - peak) / 20) / asset.get('volume', 1.2))
    for key, clip in config['bank']['data']['clips'].items():
        clip['duration'], config['bank']['peaklimits'][key] = measurements[clip['sound']]
    temporary = manifest.with_suffix('.measured.tmp')
    temporary.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(manifest)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('init')
    create.add_argument('manifest', type=Path)
    create.add_argument('--voice', required=True)
    create.add_argument('--language', required=True)
    create.add_argument('--female', action='store_true')
    scan = commands.add_parser('measure')
    scan.add_argument('manifest', type=Path)
    scan.add_argument('--ffmpeg', required=True)
    args = parser.parse_args()
    if args.command == 'init':
        initialize(args.manifest, args.voice, args.language, args.female)
    else:
        measure(args.manifest, args.ffmpeg)
    print('Prepared', args.manifest)
