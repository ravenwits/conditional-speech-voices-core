"""Read-only Core catalogue and project boundary checks."""
from functools import lru_cache
import hashlib
import json
from pathlib import Path

TOOLS=Path(__file__).resolve().parent

@lru_cache(maxsize=4)
def _read_version(path, modified, size):
    return json.loads(path.read_text(encoding='utf-8'))


def _read_catalogue(name):
    path = TOOLS / name
    stamp = path.stat()
    return _read_version(path, stamp.st_mtime_ns, stamp.st_size)


def load():
    return _read_catalogue('voice-schema-v1.json')

def source_digest(path):
    # Git checks out text with different line endings on different systems.
    return hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()

def verify_current():
    core=TOOLS.parents[1]
    for relative,expected in load()['inputs'].items():
        path=core/relative
        if not path.is_file() or source_digest(path)!=expected:
            raise ValueError('Studio catalogue is out of date. Re-export it from the current Core code.')

def strip_text(value):
    if isinstance(value,dict): return {k:strip_text(v) for k,v in value.items() if k!='text'}
    if isinstance(value,list): return [strip_text(v) for v in value]
    return value

def template():
    return _read_catalogue('voice-template-v1.json')

def validate(config):
    from prepare_voice_pack import TRIAL_GROUPS
    voice=config['bank']['voices'][0]['id']
    expected=set(load()['slots'])
    if config.get('trial'): expected={s for group in TRIAL_GROUPS.values() for s in group}
    actual=set(config['bank']['data']['clips'])
    if actual!={voice+'_'+s for s in expected}: raise ValueError('Recording slots differ from Core. Update project requirements before editing.')
    bank=config['bank']; reference=template()
    for branch,key in [('data','groups'),('data','contextLines'),('extras','catalog'),
                       ('expressions','catalog'),('whispers','catalog'),('native','replacements'),('native','suffixes')]:
        if strip_text(bank.get(branch,{}).get(key))!=strip_text(reference.get(branch,{}).get(key)):
            raise ValueError('Core-defined '+branch+'.'+key+' cannot be edited in Studio.')
    if bank.get('aliases')!=reference.get('aliases'): raise ValueError('Core aliases cannot be edited in Studio.')
    for key in ('schema','contract','needTiers','criticalHealth'):
        if bank.get(key)!=reference.get(key): raise ValueError('Core-defined '+key+' cannot be edited in Studio.')
    profanity = bank.get('profanity', {})
    base = reference.get('profanity', {})
    ids = profanity.get('ids')
    if (not isinstance(ids, dict)
        or {k:v for k,v in profanity.items() if k != 'ids'} != {k:v for k,v in base.items() if k != 'ids'}
        or any(ids.get(slot) != value for slot,value in base.get('ids', {}).items())
        or any(slot not in load()['slots'] or value is not True for slot,value in ids.items() if slot not in base.get('ids', {}))):
        raise ValueError('Invalid profanity tags. Core tags and rules cannot be changed.')
    for branch in ('native','expressions','whispers','extras'):
        if strip_text(bank.get(branch))!=strip_text(reference.get(branch)):
            raise ValueError('Core-defined '+branch+' cannot be edited in Studio.')

def build_coverage(native_replacements, available_slots):
    """Count the Core situations and required native events covered by these recordings."""
    policy = load()['coverage']
    pools = dict(policy['pools'])
    for event in template()['native']['replacements']:
        if event not in policy['optionalNativeEvents']:
            pools['Native / ' + event] = native_replacements.get(event, [])
    missing = {group: pool for group, pool in pools.items() if available_slots.isdisjoint(pool)}
    return dict(required=len(pools), covered=len(pools) - len(missing),
                missing=list(missing), missingSlots=missing, pools=pools)


def entry(slot):
    try: return load()['slots'][slot]
    except KeyError: raise ValueError('Unknown Core recording slot: '+slot) from None
