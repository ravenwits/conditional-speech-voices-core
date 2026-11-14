"""Check the shipped authoring tools without private recordings or production manifests."""
import copy
import json
from pathlib import Path
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(root / 'Contents/mods/ConditionalSpeechVoicesCore/authoring/tools'))
from build_voice_pack import validate, build, CONTRACT, lua
from prepare_voice_pack import initialize

with tempfile.TemporaryDirectory() as temporary:
    directory = Path(temporary)
    manifest = directory / 'pack.json'
    initialize(manifest, 'newvoice', 'DE', True)
    config = json.loads(manifest.read_text(encoding='utf-8'))
    bank = config['bank']
    required = set(CONTRACT['slots']) | set(CONTRACT['extensions']['needTiers']['slots']) | set(CONTRACT['extensions']['criticalHealth']['slots'])
    assert set(bank['data']['clips']) == {'newvoice_' + line for line in required}
    voice = bank['voices'][0]
    assert voice['base'] == 'VoiceFemale' and config['modId'] == 'CSV-Voice-newvoice'
    assert len(voice['previewLines']) == 6 and voice['previewLast'] == 'Injured_3'
    assert all('newvoice_' + line in bank['data']['clips'] for line in voice['previewLines'])
    # Byte fixture tests the builder's file contract, not decoding or listening quality.
    (directory / 'fixture.mp3').write_bytes(b'\0' * 1024)
    for asset in config['assets'].values():
        asset['source'] = 'fixture.mp3'
    for clip in bank['data']['clips'].values():
        clip['duration'] = 1000
    assert len(validate(config, directory)) == len(config['assets'])
    for mutate in (
        lambda c: c['bank']['data']['clips'].pop('newvoice_NativeCall_1'),
        lambda c: c['bank']['lines'].pop('NativeCall_1'),
        lambda c: c['bank']['data']['clips']['newvoice_Pain_1'].update(duration=float('nan')),
        lambda c: c['assets']['CSV_newvoice_NativeCall_1'].update(source='missing.mp3'),
        lambda c: c['bank']['voices'].append(copy.deepcopy(c['bank']['voices'][0])),
        lambda c: c['bank']['voices'][0].update(previewLines=[]),
        lambda c: c['bank']['voices'][0].update(previewLines=['MissingPreview_1']),
        lambda c: c['bank']['voices'][0].update(previewLines=['Panic_3', 'Panic_3']),
        lambda c: c['bank']['voices'][0].update(previewLines=['Panic_3'], previewLast='Injured_3'),
    ):
        broken = copy.deepcopy(config)
        mutate(broken)
        try:
            validate(broken, directory)
        except ValueError:
            pass
        else:
            raise AssertionError('Invalid input accepted')
    legacy = copy.deepcopy(config)
    legacy['bank']['voices'][0].pop('previewLines')
    legacy['bank']['voices'][0].pop('previewLast')
    validate(legacy, directory)
    manifest.write_text(json.dumps(config), encoding='utf-8')
    built=directory/'built'
    build(manifest,built,root/'Contents/mods/ConditionalSpeechVoicesCore')
    from verify_runtime import verify
    bad=built/'42/media/lua/shared/CSV_NEWVOICE/Manifest.lua'
    original=bad.read_text(encoding='utf-8')
    bad.write_text("local b=(function()\n"+original+"\nend)();b.data.groups.Panic[1].id='WrongMeaning';return b",encoding='utf-8')
    try: verify(built,root/'Contents/mods/ConditionalSpeechVoicesCore')
    except ValueError: pass
    else: raise AssertionError('Runtime semantic conflict accepted')
    target = directory / 'existing' 
    target.mkdir()
    marker = target / 'preserve.txt'
    marker.write_text('keep')
    try:
        build(manifest, target)
    except ValueError:
        pass
    else:
        raise AssertionError('Existing package overwritten')
    assert marker.read_text() == 'keep'
assert '\\u' not in lua({'caption': 'Göz gözü görmüyor.'})
print('PASS shipped builder: new voice, missing slots/captions/assets, duration, identity, playlist, legacy preview and output preservation')

# Loudness reporting must separate categories and leave supplied audio unchanged.
from unittest.mock import patch
from types import SimpleNamespace
from prepare_voice_pack import measure
with tempfile.TemporaryDirectory() as temp:
    folder=Path(temp); (folder/'sample.mp3').write_bytes(b'unchanged')
    manifest=folder/'pack.json'
    config={'assets':{},'bank':{'voices':[{'id':'test'}],'data':{'clips':{}},'peaklimits':{}}}
    for i in range(3):
        sound='Whisper_'+str(i);(folder/(sound+'.mp3')).write_bytes(('sample '+str(i)).encode());config['assets'][sound]={'source':sound+'.mp3','volume':1}
        config['bank']['data']['clips']['test_Whisper_AfterHumanShaken_'+str(i+1)]={'sound':sound,'gain':1}
    manifest.write_text(json.dumps(config))
    levels=iter([-28,-28,-18])
    def ffmpeg(args,**kwargs):
        if 'pipe:1' in args:return SimpleNamespace(stdout=b'0'*32000)
        return SimpleNamespace(stderr=json.dumps({'input_tp':'-2','input_i':str(next(levels))}))
    with patch('prepare_voice_pack.subprocess.run',side_effect=ffmpeg):measure(manifest,'ffmpeg')
    report=json.loads(manifest.with_suffix('.loudness.json').read_text())
    assert len(report['outliers'])==1 and report['outliers'][0]['sound']=='Whisper_2'
    assert (folder/'sample.mp3').read_bytes()==b'unchanged'
print('PASS loudness outlier reporting without audio mutation')
