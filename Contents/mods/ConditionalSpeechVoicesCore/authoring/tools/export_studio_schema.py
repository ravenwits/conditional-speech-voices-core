"""Export a read-only catalogue from Core Lua. Studio never evaluates gameplay rules."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

TOOLS=Path(__file__).resolve().parent
CORE=TOOLS.parents[1]
MODULES=['PackSemantics','VoiceRequirements','NeedTiers','Rules','Delivery','RecoveryRules',
         'LootRules','OutcomeRules','VehicleRules','VehicleCombatRules','TraitSpeechRules',
         'ReloadRules','PsychologyRules','KillSpeech','CriticalHealth','Conditions']
SOURCES=MODULES+['SemanticSpeech','Concealment','Safety','Channel','Expressions','Whispers',
                 'Selection','Startle','Injury','Recovery','Outcomes','Psychology','Callout','Traits']

def snapshot():
    lua=CORE/'42/media/lua'
    with tempfile.TemporaryDirectory() as tmp:
        out=Path(tmp)/'snapshot.json'
        script=Path(tmp)/'snapshot.lua'
        code="package.path="+json.dumps((lua/'shared/?.lua').as_posix())+"..';'..package.path\n"
        code+="local function clean(v) if type(v)~='table' then if type(v)~='function' then return v end;return nil end;local r={};for k,x in pairs(v)do local c=clean(x);if c~=nil then r[k]=c end end;return r end\nlocal out={}\n"
        for name in MODULES:
            code+="out["+json.dumps(name)+"]=clean(require('CSV/"+name+"'))\n"
        code+="local f=assert(io.open("+json.dumps(out.as_posix())+",'w'));f:write(vim.json.encode(out));f:close()\n"
        script.write_text(code,encoding='utf-8')
        result=subprocess.run([os.environ.get('NVIM','nvim'),'-i','NONE','--headless','-l',str(script)],capture_output=True,timeout=45,env={**os.environ,'NVIM_LOG_FILE':str(Path(tmp)/'nvim.log')})
        if result.returncode or not out.exists(): raise RuntimeError(result.stderr.decode(errors='replace'))
        return json.loads(out.read_text(encoding='utf-8'))

def export():
    data=snapshot(); semantics=data['PackSemantics']
    contract=json.loads((TOOLS/'voice-contract-v1.json').read_text(encoding='utf-8'))
    if set(data['VoiceRequirements']['slots'])!=set(contract['slots']):
        raise ValueError('Core and authoring contract differ. Refresh the contract first.')
    template=json.loads((TOOLS/'voice-template-v1.json').read_text(encoding='utf-8'))
    required=set(contract['slots'])
    for extension in contract['extensions'].values(): required.update(extension['slots'])
    rows={}
    for group,ids in semantics['groups'].items():
        for index,id in enumerate(ids,1): rows[id]=dict(group=group,source=id,delivery='normal',alternative=index)
    for id,entry in semantics['extras'].items():
        rows[id]=dict(group=entry['group'],source=id,delivery=entry.get('delivery','contextual'))
    for id,entry in semantics['contexts'].items():
        rows.setdefault(id,{}).update(entry,source=id)
    for group,ids in data['NeedTiers']['slots'].items():
        for level,id in enumerate(ids,1):
            rows.setdefault(id,dict(group=group,source=id,delivery='normal')).setdefault('needLevels',[]).append(level)
    for id,entry in semantics['expressions'].items():
        rows[id]=dict(group=entry['group'],source=entry['source'],delivery=entry['profile'])
    for source,entry in semantics['whispers'].items():
        rows[entry['id']]=dict(group=entry['group'],source=source,delivery='whisper')
    for group,entries in template['native']['groups'].items():
        for entry in entries:
            rows.setdefault(entry['id'],dict(group=group,source=entry['id'],delivery='native'))
    for event,ids in template['native']['replacements'].items():
        for id in ids:
            row=rows.setdefault(id,dict(group=event,source=id,delivery='native'))
            row.setdefault('nativeEvents',[]).append(event)
    unknown=required-rows.keys()
    if unknown: raise ValueError('Core slots without semantic definitions: '+', '.join(sorted(unknown)))
    source_files={}
    for name in SOURCES:
        for area in ['shared','client']:
            path=CORE/f'42/media/lua/{area}/CSV/{name}.lua'
            if path.exists() and name not in ('PackSemantics','VoiceRequirements'):
                source_files[path.relative_to(CORE).as_posix()]=path.read_text(encoding='utf-8-sig')
    groups={}
    for id in sorted(required):
        row=rows[id]; group=row['group']
        row.pop('id',None);row['slot']=id
        row['nativeEvents']=sorted(row.get('nativeEvents',[]))
        source=rows.get(row['source'],row)
        if row is not source:
            for key in ('needLevels','min','max','threat'):
                if key in source: row[key]=source[key]
        if group not in groups:
            references=[]
            for path,text in source_files.items():
                # Find literal references in actual Core code, never treat an ID's spelling as a rule.
                for n,line in enumerate(text.splitlines(),1):
                    if re.search(r"(['\"])"+re.escape(group)+r"\1|\."+re.escape(group)+r"\b",line):
                        references.append(dict(file=path,line=n));break
            rules=data['Rules']['policies'].get(group)
            family=data['Delivery']['groups'].get(group,'other')
            for module,label in [('PsychologyRules','psychology'),('VehicleCombatRules','vehicle'),('VehicleRules','vehicle'),
                                 ('TraitSpeechRules','traits'),('ReloadRules','combat'),('LootRules','loot'),
                                 ('OutcomeRules','outcome'),('KillSpeech','combat'),('Traits','traits')]:
                if family=='other' and (group in (data[module].get('groups',{}) if isinstance(data.get(module),dict) else {}) or any(r['file'].endswith('/'+module+'.lua') for r in references)):
                    family=label;break
            if group in data['RecoveryRules']: family='relief'
            if row.get('nativeEvents'): family='native'
            groups[group]=dict(id=group,family=family,policy=rules,recovery=data['RecoveryRules'].get(group),references=references)
        events=set(row['nativeEvents'])
        row['category']='Whisper' if row['delivery']=='whisper' else 'Dialogue'
        if events:
            if events & {'WhisperHey','WhisperPsst','WhisperMegaphoneHey','WhisperMegaphonePsst'}:
                row.update(category='Whisper',delivery='whisper')
            elif events & {'ShoutHey','ShoutMegaphoneHey'}: row.update(category='Shout',delivery='shout')
            elif 'Exercise' in events: row.update(category='Breath',delivery='nonverbal')
            elif events & {'MeleeAttack','MeleeShove','MeleeStomp','JumpHigh','JumpLow','ClimbWindow'}: row.update(category='Effort',delivery='nonverbal')
            elif events & {'PainMoodle','PainFromHitBlunt','PainFromBite','PainFromScratch','PainFromFallHigh'}: row.update(category='Pain',delivery='nonverbal')
            elif events & {'LureCmon','LureTsk'}: row.update(category='Dialogue',delivery='normal')
            else: row.update(category='Nonverbal',delivery='nonverbal')
        row['family']=groups[group]['family']
    inputs={p.relative_to(CORE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (CORE/'42/media/lua').rglob('*.lua') if p.name!='BuildIdentity.lua'}
    for name in ['voice-template-v1.json','voice-contract-v1.json','export_studio_schema.py']:
        p=TOOLS/name;inputs[p.relative_to(CORE).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    return dict(version=1,contract=contract['version'],slots={s:rows[s] for s in sorted(required)},
                groups=groups,sources=source_files,inputs=inputs)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    path=TOOLS/'voice-schema-v1.json';value=export()
    text=json.dumps(value,ensure_ascii=False,sort_keys=True,indent=2)+'\n'
    if args.check:
        if not path.exists() or path.read_text(encoding='utf-8')!=text: raise SystemExit('Studio schema is stale. Run export_studio_schema.py.')
    else: path.write_text(text,encoding='utf-8')
    print('PASS Core schema:',len(value['slots']),'slots;',len(value['groups']),'groups')

if __name__=='__main__': main()
