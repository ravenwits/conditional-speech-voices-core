"""Read-only Core catalogue and project boundary checks."""
from functools import lru_cache
import hashlib
import json
from pathlib import Path

TOOLS=Path(__file__).resolve().parent

@lru_cache(maxsize=1)
def load():
    return json.loads((TOOLS/'voice-schema-v1.json').read_text(encoding='utf-8'))

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

@lru_cache(maxsize=1)
def template():
    return json.loads((TOOLS/'voice-template-v1.json').read_text(encoding='utf-8'))

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
    for key in ('schema','contract','needTiers','criticalHealth','profanity'):
        if bank.get(key)!=reference.get(key): raise ValueError('Core-defined '+key+' cannot be edited in Studio.')
    for branch in ('native','expressions','whispers','extras'):
        if strip_text(bank.get(branch))!=strip_text(reference.get(branch)):
            raise ValueError('Core-defined '+branch+' cannot be edited in Studio.')

def entry(slot):
    try: return load()['slots'][slot]
    except KeyError: raise ValueError('Unknown Core recording slot: '+slot) from None
