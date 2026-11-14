"""Local recording projects. No recording service or account is required."""
import copy
import hashlib
import json
import math
import re
import shutil
from pathlib import Path
import subprocess
import tempfile
from functools import lru_cache
import studio_schema
from recording_limits import MAX_CAPTION, MAX_SECONDS

TOOLS = Path(__file__).resolve().parent
MAX_AUDIO = 16 * 1024 * 1024


def read(path):
    value=json.loads(Path(path).read_text(encoding='utf-8-sig'))
    # Repair the old loudness cache's undefined short-clip measurement only.
    for row in value.get('authoring',{}).get('measurements',{}).values():
        loudness=row.get('loudness',{})
        level=loudness.get('integratedLUFS')
        if isinstance(level,(int,float)) and not math.isfinite(level): loudness['integratedLUFS']=None
    return value


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as f:
        temporary = Path(f.name)
        f.write(data)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def contained(root, relative):
    root = Path(root).resolve()
    path = (root / relative).resolve()
    if path == root or not path.is_relative_to(root):
        raise ValueError('Project paths must stay inside the project directory')
    return path


def digest(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def voice_id(config):
    voices = config['bank']['voices']
    if len(voices) != 1:
        raise ValueError('The editor works on one voice per project')
    return voices[0]['id']


def slots(config):
    prefix = voice_id(config) + '_'
    return {key[len(prefix):]: clip for key, clip in config['bank']['data']['clips'].items()
            if key.startswith(prefix)}


def category(slot):
    return studio_schema.entry(slot)['category']


def guidance(slot):
    kind = category(slot)
    base = {
        'Whisper': 'A quiet, close whisper. Keep the meaning of the reference line.',
        'Shout': 'A projecting call to attract attention, not a pain scream.',
        'Breath': 'Breathing only. Do not read a caption or an instruction aloud.',
        'Effort': 'A brief physical effort grunt. No spoken sentence.',
        'Pain': 'A brief involuntary pain reaction. Do not invent a cause of injury.',
        'Nonverbal': 'Perform the named physical reaction. The caption is a reference, not an instruction to read aloud.',
        'Dialogue': '',
    }[kind]
    profiles = {
        'angry': 'Angry and frustrated, without changing the meaning.',
        'breathless': 'Speak between short breaths. Keep the words understandable.',
        'frightened': 'Audibly frightened, with strained and unsteady delivery.',
        'sad': 'Sad and vulnerable, with restrained tears rather than theatrical sobbing.',
        'congested': 'Speak with a blocked nose; keep the words understandable.',
        'slurred': 'Slightly slurred speech; do not turn it into a joke.',
        'stammer': 'Stammer under stress, with brief broken starts.',
    }
    definition=studio_schema.entry(slot)
    contextual = {
        'AfterHumanShaken': 'Shaken after killing a person. Let shock interrupt the words; no triumph or theatrical sobbing.',
        'AfterZombieShaken': 'Shaken after a zombie encounter. An unsteady voice, still processing what happened.',
        'AfterHumanSteady': 'Controlled but troubled after killing a person. Quiet reflection, not celebration.',
        'AfterZombieSteady': 'Composed after a zombie encounter, with lingering strain. Not cheerful or triumphant.',
    }
    if definition['group'] in contextual:
        base += ' ' + contextual[definition['group']]
    if definition['delivery'] in profiles:
        base += ' ' + profiles[definition['delivery']]
    if definition['group']=='CriticalFading':
        base += ' Very weak, fading speech with interrupted breaths, not a strong shout.'
    levels=definition.get('needLevels',[])
    if levels:
        severity={1:'Mild need. A passing observation, without distress.',2:'Noticeable discomfort. Let it interrupt the thought.',3:'Severe discomfort. Strained, but still able to finish the sentence.',4:'Extreme need. Weak or distressed; leave room for breath.'}
        base += ' ' + ' '.join(severity[level] for level in levels if level in severity)
    return base.strip()


def recording_note(config,slot):
    authoring=config.get('authoring',{})
    recorded=authoring.get('recordingGuidance',{}).get(slot)
    if recorded: return recorded
    saved=authoring.get('directions',{}).get(slot)
    old_default=authoring.get('referenceDirections',{}).get(slot)
    if saved is None or saved==old_default: return guidance(slot)
    return saved


def context(slot):
    return studio_schema.entry(slot)['group']


def set_caption(bank, slot, text):
    bank['lines'][slot] = text
    # Captions also occur in selection catalogs. Keep all owned copies together.
    def visit(value):
        if isinstance(value, dict):
            if value.get('id') == slot and 'text' in value:
                value['text'] = text
            for child in value.values(): visit(child)
        elif isinstance(value, list):
            for child in value: visit(child)
    for name in ('data', 'extras', 'expressions', 'whispers'):
        visit(bank.get(name, {}))


def text_catalog(language, source=None):
    path = Path(source) if source else TOOLS / ('texts-' + language + '.json')
    if not path.is_file(): return {}
    value = read(path)
    if 'bank' in value:
        if value['bank']['language'] != language:
            raise ValueError('Text source language does not match the new project')
        return value['bank']['lines']
    if value.get('language') != language or not isinstance(value.get('lines'), dict):
        raise ValueError('Text catalog must declare its language and lines')
    return value['lines']


def setup(config, texts=None):
    template = read(TOOLS / 'voice-template-v1.json')
    localized = text_catalog(config['bank']['language'], texts)
    authoring = config.setdefault('authoring', {})
    authoring.setdefault('reviews', {})
    authoring.setdefault('directions', {})
    authoring['references'] = {slot: template['lines'].get(slot, '') for slot in slots(config)}
    authoring['referenceDirections'] = {slot: guidance(slot) for slot in slots(config)}
    for slot in slots(config):
        if slot in localized:
            set_caption(config['bank'], slot, localized[slot])


@lru_cache(maxsize=4096)
def audio_digest(path, size, modified, changed):
    return digest(path)


def fingerprint(config, slot, root, clip=None):
    clip = clip or slots(config)[slot]
    path = contained(root, config['assets'][clip['sound']]['source'])
    value = [config['bank']['lines'].get(slot, ''),
             recording_note(config,slot),
             audio_digest(str(path),path.stat().st_size,path.stat().st_mtime_ns,path.stat().st_ctime_ns) if path.is_file() else None, clip.get('gain', 1),
             config['assets'][clip['sound']].get('volume', 1.2)]
    return hashlib.sha256(json.dumps(value, ensure_ascii=False).encode()).hexdigest()


def status(config, slot, root, clip=None):
    clip = clip or slots(config)[slot]
    path = contained(root, config['assets'][clip['sound']]['source'])
    if not path.is_file(): return 'missing'
    review = config.get('authoring', {}).get('reviews', {}).get(slot, {})
    if not review: return 'pending'
    if review.get('fingerprint') != fingerprint(config, slot, root, clip): return 'pending'
    return review.get('status', 'pending')


def rows(manifest):
    config = read(manifest)
    schema_error=None
    try: studio_schema.validate(config)
    except ValueError as error: schema_error=str(error)
    result = []
    for slot, clip in (slots(config).items() if not schema_error else []):
        definition=studio_schema.entry(slot)
        result.append(dict(slot=slot, category=category(slot), family=definition['family'], delivery=definition['delivery'], context=context(slot), text=config['bank']['lines'].get(slot, ''),
            reference=config.get('authoring', {}).get('references', {}).get(slot, ''),
            direction=recording_note(config,slot),
            guidance=config.get("authoring",{}).get("recordingGuidance",{}).get(slot) or guidance(slot),
            state=status(config, slot, manifest.parent, clip),
            audioEdit={k:v for k,v in config.get('authoring',{}).get('audioEdits',{}).get(slot,{}).items() if k in ('gainDb','semitones','speed','trimStart','trimEnd')}))
    return dict(canUndoReview=bool(config.get('authoring',{}).get('lastBulkReview')),limits=dict(caption=MAX_CAPTION,seconds=MAX_SECONDS,audioBytes=MAX_AUDIO),steamProfile=config.get('steamProfile',''),name=config['name'], author=config['author'], description=config['description'], voice=voice_id(config),
                language=config['bank']['language'], packVersion=config['bank']['revision'], trial=bool(config.get('trial')),
                revision=digest(manifest), rows=result, schemaError=schema_error, coverage={state:sum(r['state']==state for r in result) for state in ['missing','pending','approved','redo']})


def edit(manifest, slot, text, direction, state):
    config = read(manifest)
    studio_schema.validate(config)
    if slot not in slots(config): raise ValueError('Unknown recording slot')
    if state not in ('pending', 'approved', 'redo'): raise ValueError('Unknown review state')
    if not isinstance(text, str) or not text.strip() or len(text) > MAX_CAPTION:
        raise ValueError(f'Supply a caption of 1 to {MAX_CAPTION} characters')
    if not isinstance(direction, str) or len(direction) > 4000:
        raise ValueError('Direction is too long')
    set_caption(config['bank'], slot, text.strip())
    authoring = config.setdefault('authoring', {})
    authoring.setdefault('directions', {})[slot] = direction
    if state == 'approved' and status(config, slot, manifest.parent) == 'missing':
        raise ValueError('Import a recording before approving it')
    authoring.setdefault('reviews', {})[slot] = dict(status=state, fingerprint=fingerprint(config, slot, manifest.parent))
    write(manifest, config)


def import_audio(manifest, slot, source, ffmpeg):
    revision = digest(manifest)
    config = read(manifest)
    studio_schema.validate(config)
    if slot not in slots(config): raise ValueError('Unknown recording slot')
    source = Path(source)
    if not source.is_file() or source.stat().st_size > MAX_AUDIO:
        raise ValueError('Supply a local recording no larger than 16 MiB')
    clip = slots(config)[slot]
    target = contained(manifest.parent, 'audio/' + voice_id(config) + '_' + slot + '.mp3')
    target.parent.mkdir(parents=True, exist_ok=True)
    # Decode imports from any supported format; reject invalid and overlong takes.
    with tempfile.TemporaryDirectory(dir=target.parent) as folder:
        converted = Path(folder) / 'take.mp3'
        subprocess.run([ffmpeg, '-nostdin', '-v', 'error', '-format_whitelist', 'wav,flac,mp3,ogg,aac,mov,mp4,m4a,3gp,3g2,mj2,matroska,webm',
                        '-i', str(source), '-t', str(MAX_SECONDS+1),
                        '-map_metadata', '-1', '-vn', '-ac', '1', '-ar', '44100', '-codec:a',
                        'libmp3lame', '-b:a', '96k', str(converted)], check=True, capture_output=True, timeout=90)
        decoded = subprocess.run([ffmpeg, '-nostdin', '-v', 'error', '-i', str(converted),
                                  '-f', 's16le', '-ac', '1', '-ar', '16000', 'pipe:1'],
                                  check=True, capture_output=True, timeout=90).stdout
        if not 0 < len(decoded) <= MAX_SECONDS * 32000:
            raise ValueError(f'Recording must be between 0 and {MAX_SECONDS} seconds; it was not imported')
        if digest(manifest) != revision:
            raise ValueError('Project changed during import. Retry without concurrent edits.')
        converted.replace(target)
    config['assets'][clip['sound']]['source'] = target.relative_to(manifest.parent).as_posix()
    clip['duration'] = 0
    config['bank']['peaklimits'].pop(voice_id(config) + '_' + slot, None)
    config.setdefault('authoring', {}).setdefault('reviews', {}).pop(slot, None)
    config['authoring'].get('audioEdits',{}).pop(slot,None)
    config['authoring'].get('measurements',{}).pop(clip['sound'],None)
    write(manifest, config)


def refresh(manifest, apply=False, preserve_trial=False):
    """Upgrade a trial or refresh required definitions; preserve text, takes and reviews."""
    from prepare_voice_pack import initialize
    old = read(manifest)
    voice = old['bank']['voices'][0]
    with tempfile.TemporaryDirectory() as directory:
        fresh_path = Path(directory) / 'full.json'
        initialize(fresh_path, voice['id'], old['bank']['language'], voice['base'] == 'VoiceFemale', trial=bool(preserve_trial and old.get('trial')))
        fresh = read(fresh_path)
    old_slots, new_slots = slots(old), slots(fresh)
    old_refs = old.get('authoring', {}).get('references', {})
    new_refs = fresh['authoring']['references']
    old_directions = old.get('authoring', {}).get('referenceDirections', {})
    new_directions = fresh['authoring']['referenceDirections']
    diff = dict(added=sorted(new_slots.keys() - old_slots.keys()),
                removed=sorted(old_slots.keys() - new_slots.keys()),
                changed=sorted(s for s in new_slots.keys() & old_slots.keys()
                               if old_refs.get(s, old['bank']['lines'].get(s)) != new_refs.get(s)
                               or old_directions.get(s, guidance(s)) != new_directions[s]))
    if not apply: return diff
    for name in ('name', 'author', 'description', 'poster', 'modId', 'module', 'steamProfile'):
        if name in old: fresh[name] = old[name]
    fresh['bank'].update(id=old['bank']['id'], revision=old['bank']['revision'])
    fresh['bank']['voices'][0].update(voice)
    fresh['authoring'].update(copy.deepcopy(old.get('authoring', {})))
    fresh['authoring']['references'] = new_refs
    fresh['authoring']['referenceDirections'] = new_directions
    for slot,note in list(fresh['authoring'].get('directions',{}).items()):
        if note==old_directions.get(slot): fresh['authoring']['directions'].pop(slot)
    for slot in new_slots.keys() & old_slots.keys():
        key = voice['id'] + '_' + slot
        fresh['bank']['data']['clips'][key] = old_slots[slot]
        fresh['assets'].pop(new_slots[slot]['sound'], None)
        fresh['assets'][old_slots[slot]['sound']] = old['assets'][old_slots[slot]['sound']]
        if key in old['bank']['peaklimits']:
            fresh['bank']['peaklimits'][key] = old['bank']['peaklimits'][key]
        set_caption(fresh['bank'], slot, old['bank']['lines'][slot])
    # Existing aliases/custom semantic changes need explicit migration, not silent replacement.
    if old['bank'].get('aliases') != fresh['bank'].get('aliases'):
        raise ValueError('Custom aliases differ; migrate this project manually before refreshing')
    for slot in diff['changed']:
        fresh['authoring'].setdefault('reviews', {}).pop(slot, None)
    write(manifest.with_suffix('.before-update.json'), old)
    write(manifest, fresh)
    return diff


def jobs(manifest, rate=0):
    if not math.isfinite(rate) or rate < 0: raise ValueError('Rate must be finite and nonnegative')
    config = read(manifest)
    studio_schema.validate(config)
    result = []
    for slot,clip in slots(config).items():
        state = status(config, slot, manifest.parent,clip)
        if state not in ('missing', 'redo'): continue
        text = config['bank']['lines'].get(slot, '')
        direction = recording_note(config,slot)
        job = dict(slot=slot, text=text, direction=direction, language=config['bank']['language'],
                   filename=slot + '.mp3',
                   category=category(slot), context=context(slot))
        job['id'] = hashlib.sha256(json.dumps(job, sort_keys=True).encode()).hexdigest()
        job['characters'] = len(text) + len(direction)
        job['estimatedUnits'] = round(job['characters'] * rate, 6)
        result.append(job)
    return dict(jobs=result, recordings=len(result), characters=sum(j['characters'] for j in result),
                estimatedUnits=round(sum(j['estimatedUnits'] for j in result), 6),
                note='Estimate only. Record these yourself, or use an optional external command.')


def run_jobs(manifest, command, ffmpeg, budget, rate, max_jobs=18):
    """CLI-only opt-in worker. argv + job.json + output.mp3; never a shell string."""
    lock = manifest.with_suffix('.worker.lock')
    try:
        handle = lock.open('x', encoding='utf-8')
    except FileExistsError:
        raise ValueError('A worker owns this project. If it crashed, confirm it stopped before removing .worker.lock.') from None
    try:
        with handle:
            import os
            handle.write(str(os.getpid())); handle.flush()
            return _run_jobs(manifest, command, ffmpeg, budget, rate, max_jobs)
    finally:
        lock.unlink(missing_ok=True)


def _run_jobs(manifest, command, ffmpeg, budget, rate, max_jobs):
    if not command or not math.isfinite(budget) or budget < 0 or rate <= 0 or max_jobs < 1:
        raise ValueError('Supply a command, positive unit rate, job limit and finite budget')
    ledger_path = manifest.with_suffix('.work.json')
    ledger = read(ledger_path) if ledger_path.exists() else dict(reservedUnits=0, entries=[])
    unresolved = {e['id'] for e in ledger['entries'] if e['state'] == 'reserved'}
    queue = jobs(manifest, rate)['jobs']
    if any(j['id'] in unresolved for j in queue):
        raise ValueError('An interrupted job is unresolved. Import its output or resolve its ledger entry before retrying; do not pay twice.')
    completed = 0
    for job in queue[:max_jobs]:
        if ledger['reservedUnits'] + job['estimatedUnits'] > budget: break
        entry = dict(id=job['id'], slot=job['slot'], units=job['estimatedUnits'], state='reserved')
        ledger['entries'].append(entry)
        ledger['reservedUnits'] = round(ledger['reservedUnits'] + job['estimatedUnits'], 6)
        write(ledger_path, ledger)
        folder = manifest.parent / 'work' / (job['id'] + '-' + str(len(ledger['entries'])))
        folder.mkdir(parents=True, exist_ok=True)
        request, output = folder / 'job.json', folder / 'output.mp3'
        job['maxUnits'] = job['estimatedUnits']
        write(request, job)
        try:
            subprocess.run(command + [str(request.resolve()), str(output.resolve())],
                           check=True, capture_output=True, timeout=300)
            import_audio(manifest, job['slot'], output, ffmpeg)
        except Exception:
            # Keep the reservation and output for recovery. Never retry automatically.
            raise ValueError('Worker did not finish. Its reservation remains; check the saved job before retrying.') from None
        entry['state'] = 'imported'
        write(ledger_path, ledger)
        completed += 1
    return dict(completed=completed, reservedUnits=ledger['reservedUnits'], remaining=len(jobs(manifest, rate)['jobs']))


def resolve_job(manifest, job_id):
    path = manifest.with_suffix('.work.json')
    ledger = read(path)
    found = False
    for entry in ledger['entries']:
        if entry['id'] == job_id and entry['state'] == 'reserved':
            entry['state'] = 'checked'
            found = True
    if not found: raise ValueError('No unresolved reservation with that ID')
    # Acknowledging failure never refunds an unknown external charge.
    write(path, ledger)
    return dict(message='Retry allowed; previously reserved units still count against the budget.')


def import_folder(manifest, folder, ffmpeg):
    config = read(manifest)
    mapping = {}
    for slot in slots(config):
        mapping[slot] = slot
        mapping[voice_id(config) + '_' + slot] = slot
    selected, ignored = {}, []
    for path in sorted(Path(folder).iterdir()):
        if not path.is_file(): continue
        slot = mapping.get(path.stem)
        if slot is None or path.suffix.lower() not in ('.mp3','.wav','.flac','.ogg','.m4a','.aac','.aiff'):
            ignored.append(path.name)
            continue
        if slot in selected: raise ValueError('More than one input for ' + slot)
        if status(config,slot,manifest.parent) in ('missing','redo'): selected[slot] = path
    imported = []
    for slot, source in selected.items():
        import_audio(manifest,slot,source,ffmpeg)
        imported.append(slot)
    return dict(imported=imported, ignored=ignored,
                note='Existing takes are kept unless explicitly marked Record again. Rerun to resume remaining imports.')


def workshop_project(manifest, output, ffmpeg, core):
    config = read(manifest)
    if output.exists():
        raise ValueError('Output already exists. Increase the pack version before building again.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
        staged = Path(temporary) / 'workshop'
        mod = staged / 'Contents' / 'mods' / config['modId']
        result = package(manifest, mod, ffmpeg, core)
        poster = mod / '42' / 'poster.png'
        shutil.copy2(poster if poster.is_file() else TOOLS / 'workshop-preview.png', staged / 'preview.png')
        lines = ['version=1', 'title=' + config['name'],
                 'description=' + config['description'], 'tags=', 'visibility=private']
        (staged / 'workshop.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
        staged.rename(output)
    return {**result, 'output': str(output),
            'mod': str(output / 'Contents' / 'mods' / config['modId'])}


def package(manifest, output, ffmpeg, core):
    from prepare_voice_pack import measure
    from build_voice_pack import build
    config = read(manifest)
    studio_schema.validate(config)
    if config.get('trial'): raise ValueError('Promote the trial before packaging')
    pending = [slot for slot,clip in slots(config).items() if status(config, slot, manifest.parent,clip) != 'approved']
    if pending: raise ValueError(f'{len(pending)} recordings still need import or listening approval')
    measure(manifest, ffmpeg)
    count = build(manifest, output, core)
    return dict(recordings=count, output=str(output),
                note='File, measurement and Core registry checks passed. Live listening remains necessary.')


def review_many(manifest, selected, state):
    revision = digest(manifest)
    config = read(manifest)
    studio_schema.validate(config)
    known = slots(config)
    if state not in ('approved', 'redo'): raise ValueError('Unknown review state')
    if not isinstance(selected, list) or not selected or len(selected)>len(known): raise ValueError('Select recordings to review')
    if any(not isinstance(slot,str) or slot not in known for slot in selected) or len(set(selected))!=len(selected):
        raise ValueError('Unknown or repeated recording slot')
    if any(status(config,slot,manifest.parent,known[slot])=='missing' for slot in selected):
        raise ValueError('Missing recordings cannot be reviewed')
    reviews=config.setdefault('authoring',{}).setdefault('reviews',{})
    before={slot:reviews.get(slot) for slot in selected}
    for slot in selected:
        reviews[slot]=dict(status=state,fingerprint=fingerprint(config,slot,manifest.parent,known[slot]))
    config['authoring']['lastBulkReview']=dict(before=before,after={slot:reviews[slot] for slot in selected})
    if digest(manifest)!=revision: raise ValueError('Project changed. Reload before reviewing.')
    write(manifest,config)
    return dict(message=f'{len(selected)} recordings '+('approved.' if state=='approved' else 'marked for a retake. Files were kept.'))


def undo_review(manifest):
    revision=digest(manifest)
    config=read(manifest)
    authoring=config.setdefault('authoring',{})
    change=authoring.get('lastBulkReview')
    if not change: raise ValueError('No bulk review to undo')
    reviews=authoring.setdefault('reviews',{})
    known=slots(config)
    for slot, after in change['after'].items():
        if slot not in known or reviews.get(slot)!=after or fingerprint(config,slot,manifest.parent,known[slot])!=after['fingerprint']:
            raise ValueError('A recording changed after this bulk review. Undo would overwrite newer work.')
    for slot, before in change['before'].items():
        if before is None: reviews.pop(slot,None)
        else: reviews[slot]=before
    del authoring['lastBulkReview']
    if digest(manifest)!=revision: raise ValueError('Project changed. Reload before undoing.')
    write(manifest,config)
    return dict(message=f"Undid review of {len(change['before'])} recordings. Audio files were kept.")


def sync_core(manifest):
    """Reconcile changed Core definitions at open; keep recordings and a backup."""
    config=read(manifest)
    current=hashlib.sha256(json.dumps(studio_schema.load()['inputs'],sort_keys=True).encode()).hexdigest()
    if config.get('authoring',{}).get('coreInputs') == current: return
    if not config.get('authoring',{}).get('coreInputs'):
        try: studio_schema.validate(config)
        except ValueError: refresh(manifest,True,preserve_trial=True)
    else: refresh(manifest,True,preserve_trial=True)
    config=read(manifest)
    config.setdefault('authoring',{})['coreInputs']=current
    write(manifest,config)
