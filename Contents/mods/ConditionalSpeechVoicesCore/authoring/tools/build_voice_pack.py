"""Build a complete voice pack from JSON metadata and owned audio files."""
import argparse
import json
import math
from pathlib import Path
import re
import shutil
import tempfile

CONTRACT = json.loads(Path(__file__).with_name('voice-contract-v1.json').read_text())
IDENTIFIER = re.compile(r'^[A-Za-z][A-Za-z0-9_]*$')


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False).replace('\\/', '/')
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            raise ValueError('Non-finite metadata')
        return str(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(key) + ']=' + lua(item) for key, item in sorted(value.items())) + '}'
    raise TypeError(type(value))


def validate(config, directory):
    if config.get('schema') != 1 or not IDENTIFIER.fullmatch(config['module']):
        raise ValueError('Invalid builder schema or module')
    if not re.fullmatch(r'[A-Za-z0-9_-]+', config['modId']):
        raise ValueError('Invalid mod ID')
    bank = config['bank']
    if bank.get('contract') != 1 or not bank.get('voices'):
        raise ValueError('A complete contract-1 bank with voices is required')
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', bank.get('revision', '')):
        raise ValueError('Use a three-part numeric pack revision')
    suffixes = bank['native']['suffixes']
    if len(suffixes) != len(set(suffixes)) or not set([''] + CONTRACT['nativeEvents']).issubset(suffixes):
        raise ValueError('Native registrations must include the ambient controller and every event')
    required = set(CONTRACT['slots'])
    if 'needTiers' in bank:
        extension = CONTRACT['extensions']['needTiers']
        if bank['needTiers'] != extension['version']:
            raise ValueError('Unsupported need tier extension')
        required.update(extension['slots'])
        if any(not bank['lines'].get(line) for line in extension['slots']):
            raise ValueError('Missing need tier caption')
    voices = set()
    prefixes = set()
    for voice in bank['voices']:
        name = voice['id']
        if not re.fullmatch(r'[a-z][a-z0-9_]*', name) or name in voices:
            raise ValueError('Invalid or duplicate voice ID')
        voices.add(name)
        if not re.fullmatch(r'VoiceCSV\w+P', voice['prefix']) or voice['prefix'] in prefixes:
            raise ValueError('Invalid or duplicate native prefix')
        prefixes.add(voice['prefix'])
        if voice['base'] not in ('VoiceMale', 'VoiceFemale'):
            raise ValueError('Invalid native voice base')
        for slot in sorted(required):
            line = bank.get('aliases', {}).get(slot, slot)
            if name + '_' + line not in bank['data']['clips']:
                raise ValueError(name + ': missing slot ' + slot)
        if name + '_' + voice['preview'] not in bank['data']['clips']:
            raise ValueError(name + ': missing preview')
        for event in CONTRACT['nativeEvents']:
            pool = bank['native']['replacements'].get(event)
            if not pool:
                raise ValueError(name + ': missing native event ' + event)
            for line in pool:
                if name + '_' + line not in bank['data']['clips']:
                    raise ValueError(name + ': missing native recording ' + line)
                if ('Shout' in event or 'Whisper' in event) and not bank['lines'].get(line):
                    raise ValueError('Missing callout caption ' + line)
    expected = set()
    for key, clip in bank['data']['clips'].items():
        if not any(key.startswith(voice + '_') for voice in voices):
            raise ValueError('Recording belongs to an undeclared voice: ' + key)
        sound = clip['sound']
        if not IDENTIFIER.fullmatch(sound) or not sound.startswith('CSV_'):
            raise ValueError('Invalid sound event ' + sound)
        owner = max((voice for voice in voices if key.startswith(voice + '_')), key=len)
        if not sound.startswith('CSV_' + owner + '_'):
            raise ValueError('Recording references another speaker: ' + key)
        duration = clip['duration']
        if not isinstance(duration, (int, float)) or not math.isfinite(duration) or duration <= 0:
            raise ValueError('Invalid duration ' + key)
        expected.add(sound)
    if expected != set(config['assets']):
        raise ValueError('Assets must exactly match referenced sound events')
    files = {}
    for sound, asset in config['assets'].items():
        source = (directory / asset['source']).resolve()
        if source.suffix.lower() != '.mp3' or not source.is_file() or source.stat().st_size < 1000:
            raise ValueError('Missing or empty MP3 for ' + sound)
        volume = asset.get('volume', 1.2)
        if not isinstance(volume, (int, float)) or not math.isfinite(volume) or not 0 < volume <= 4:
            raise ValueError('Invalid volume for ' + sound)
        files[sound] = source
    return files


def build(config_path, output):
    config = json.loads(config_path.read_text(encoding='utf-8'))
    files = validate(config, config_path.parent)
    if output.exists():
        raise ValueError('Output already exists. Build to a fresh versioned directory.')
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='voice-build-', dir=output.parent))
    try:
        bank = config['bank']
        media = temporary / '42/media'
        shared = media / 'lua/shared' / config['module']
        shared.mkdir(parents=True)
        audio = media / 'sound/CSV'
        audio.mkdir(parents=True)
        scripts = media / 'scripts'
        scripts.mkdir()
        names = {'data':'Data','extras':'Extras','whispers':'Whispers','expressions':'Expressions',
                 'profanity':'Profanity','peaklimits':'PeakLimits','lines':'Lines','native':'Native',
                 'aliases':'Aliases','voices':'Voices'}
        manifest = []
        for key, value in bank.items():
            if key in names:
                filename = names[key]
                if key == 'data':
                    header = {k:v for k,v in value.items() if k != 'clips'}
                    header['clips'] = {}
                    content = 'local D=' + lua(header) + '\n'
                    for clip, metadata in sorted(value['clips'].items()):
                        # Keep sound first for existing packaging checks.
                        body = 'sound=' + lua(metadata['sound']) + ','
                        body += ','.join(k + '=' + lua(v) for k,v in metadata.items() if k != 'sound')
                        content += 'D.clips[' + lua(clip) + ']={' + body + '}\n'
                    content += 'return D\n'
                else:
                    content = 'return ' + lua(value) + '\n'
                (shared / (filename + '.lua')).write_text(content, encoding='utf-8')
                manifest.append('[' + lua(key) + ']=require(' + lua(config['module'] + '/' + filename) + ')')
            else:
                manifest.append('[' + lua(key) + ']=' + lua(value))
        (shared / 'Manifest.lua').write_text('return {' + ','.join(manifest) + '}\n', encoding='utf-8')
        provider = media / 'lua/shared/CSV_Packs'
        provider.mkdir()
        (provider / (config['modId'] + '.lua')).write_text(
            "local bank=require(" + lua(config['module'] + '/Manifest') + ")\n"
            "return {schema=1,contract=bank.contract,bank=bank,voices=bank.voices}\n", encoding='utf-8')
        definitions = ['module Base {']
        for sound, source in sorted(files.items()):
            filename = sound.removeprefix('CSV_') + '.mp3'
            shutil.copy2(source, audio / filename)
            for suffix, spatial in (('', 'true'), ('_Self', 'false')):
                definitions.append('sound ' + sound + suffix + '\n{\ncategory = Voice,\nis3D = ' + spatial +
                    ',\nloop = false,\nclip\n{\nfile = media/sound/CSV/' + filename +
                    ',\ndistanceMin = 1,\ndistanceMax = 25,\nvolume = ' + str(config['assets'][sound].get('volume', 1.2)) + ',\n}\n}')
        definitions.append('}')
        (scripts / (config['module'] + '_Sounds.txt')).write_text('\n'.join(definitions) + '\n')
        for name in ('name', 'author', 'description'):
            if '\n' in config[name] or '\r' in config[name]:
                raise ValueError('Metadata must be a single line: ' + name)
        info = '\n'.join([f'name={config["name"]}', f'id={config["modId"]}',
            'require=Conditional-Speech-Voices-Core', 'author=' + config['author'],
            'modversion=' + bank['revision'], 'versionMin=42.20', 'poster=poster.png',
            'description=' + config['description']]) + '\n'
        for location in (temporary, temporary / '42'):
            (location / 'mod.info').write_text(info, encoding='utf-8')
            if config.get('poster'):
                shutil.copy2(config_path.parent / config['poster'], location / 'poster.png')
        temporary.rename(output)
    except BaseException:
        assert temporary.resolve().parent == output.parent.resolve() and temporary.name.startswith('voice-build-')
        shutil.rmtree(temporary)
        raise
    return len(files)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    print('Built', build(args.manifest.resolve(), args.output.resolve()), 'audio files')
