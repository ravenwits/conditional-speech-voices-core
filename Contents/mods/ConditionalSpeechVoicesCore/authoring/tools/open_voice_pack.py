"""Choose and import a local Workshop voice pack into Studio."""
from base64 import b64encode
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
from string import ascii_uppercase

from prepare_voice_pack import initialize
import voice_project as project

OFFICIAL = {
    'Conditional-Speech-Voices-English': ('EN', ('bob', 'kate')),
    'Conditional-Speech-Voices-Turkish': ('TR', ('alp', 'mujde')),
}


def choose_windows_folder():
    if os.name != 'nt' and not os.environ.get('WSL_DISTRO_NAME'):
        raise ValueError('The Windows folder picker is unavailable on this system.')
    # WSL passes the encoded script as a single argument to Windows PowerShell.
    script = """
Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$owner = [Windows.Forms.Form]::new()
$owner.TopMost = $true
$owner.ShowInTaskbar = $false
$dialog = [Windows.Forms.FolderBrowserDialog]::new()
$dialog.Description = 'Select a local voice pack folder'
$dialog.ShowNewFolderButton = $false
try {
    if ($dialog.ShowDialog($owner) -eq [Windows.Forms.DialogResult]::OK) {
        [Console]::WriteLine($dialog.SelectedPath)
    }
} finally {
    $dialog.Dispose()
    $owner.Dispose()
}
"""
    encoded = b64encode(script.encode('utf-16-le')).decode('ascii')
    result = subprocess.run(
        ['powershell.exe', '-NoProfile', '-STA', '-EncodedCommand', encoded],
        capture_output=True, encoding='utf-8', errors='replace',
    )
    if result.returncode:
        raise ValueError('Windows could not open the folder picker.')
    return result.stdout.strip() or None


def browse_folders(value, default):
    if value == '' and os.name == 'nt':
        drives = [Path(letter + ':\\') for letter in ascii_uppercase]
        return {'folder': '', 'parent': None, 'folders': [
            {'name': str(drive), 'path': str(drive)} for drive in drives if drive.is_dir()
        ]}
    folder = resolve_folder(value) if value is not None else default.resolve()
    children = sorted(
        (child for child in folder.iterdir() if not child.name.startswith('.') and child.is_dir()),
        key=lambda child: child.name.casefold(),
    )
    parent = str(folder.parent) if folder.parent != folder else ('' if os.name == 'nt' else None)
    return {'folder': str(folder), 'parent': parent, 'folders': [
        {'name': child.name, 'path': str(child)} for child in children
    ]}


def resolve_folder(value):
    if os.environ.get('WSL_DISTRO_NAME') and re.match(r'^[A-Za-z]:', value):
        converted = subprocess.run(['wslpath', '-u', value], capture_output=True, text=True)
        if not converted.returncode:
            value = converted.stdout.strip()
    folder = Path(value).expanduser()
    if not folder.is_absolute() or not folder.is_dir():
        raise ValueError('Choose an existing local folder.')
    return folder.resolve()


def pack_info(folder):
    # Accept a mod root, its version folder, or a Workshop item folder.
    candidates = {folder / 'mod.info', folder / '42/mod.info'}
    for mods in (folder / 'mods', folder / 'Contents/mods'):
        candidates.update(mods.glob('*/42/mod.info'))
    packs = {}
    for info in sorted(candidates):
        if not info.is_file():
            continue
        fields = dict(line.split('=', 1) for line in
                      info.read_text(encoding='utf-8-sig').splitlines() if '=' in line)
        audio = info.parent / 'media/sound/CSV'
        mod_id = fields.get('id', '').strip()
        if mod_id and audio.is_dir():
            packs[mod_id] = (fields, audio)
    if len(packs) != 1:
        raise ValueError('Choose a folder containing exactly one Conditional Speech Voices pack.')
    return next(iter(packs.items()))


def open_pack(folder, known, projects_root):
    mod_id, (fields, audio) = pack_info(folder)
    if mod_id in OFFICIAL:
        language, voices = OFFICIAL[mod_id]
    else:
        match = re.fullmatch(r'CSV-Voice-([a-z][a-z0-9_]{0,47})', mod_id)
        if not match:
            raise ValueError('This mod is not a supported Conditional Speech Voices pack.')
        voices = (match[1],)
        shared = audio.parent.parent / 'lua/shared'
        manifests = list(shared.glob('*/Manifest.lua'))
        languages = set()
        for manifest in manifests:
            languages.update(re.findall(r'\["language"\]\s*=\s*"([A-Z_]{2,8})"', manifest.read_text(encoding='utf-8')))
        if len(languages) != 1:
            raise ValueError('The pack must define a single supported language.')
        language = languages.pop()
    results = {}
    for voice in voices:
        matches = []
        for key, manifest in known.items():
            config = project.read(manifest)
            identity = {entry['id'] for entry in config['bank']['voices']}
            if (config.get('sourcePackId') == mod_id and voice in identity
                    or mod_id not in OFFICIAL and config.get('modId') == mod_id
                    or mod_id in OFFICIAL and 'local_' + voice in identity
                    and config['bank']['language'] == language):
                matches.append(key)
        results[voice] = matches[0] if matches else None
    return mod_id, fields, audio, language, results


def import_voice(mod_id, fields, audio, language, voice, projects_root):
    key = 'local_' + voice if mod_id in OFFICIAL else voice
    target = project.contained(projects_root, key)
    if target.exists():
        raise ValueError('A different project already uses this voice ID.')
    projects_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=projects_root) as temporary:
        folder = Path(temporary) / key
        manifest = folder / 'project.json'
        shared = audio.parent.parent / 'lua/shared'
        female = voice in {'kate', 'mujde'} or any(
            'VoiceFemale' in path.read_text(encoding='utf-8') for path in shared.glob('*/Voices.lua')
        ) and mod_id not in OFFICIAL
        initialize(manifest, key, language, female)
        aliases = {}
        if mod_id == 'Conditional-Speech-Voices-Turkish':
            alias_file = shared / 'CSV_TR/Aliases.lua'
            if alias_file.is_file():
                aliases = dict(re.findall(r'\["([A-Za-z0-9_]+)"\]="([A-Za-z0-9_]+)"', alias_file.read_text(encoding='utf-8')))
        config = project.read(manifest)
        config.update(sourcePackId=mod_id, name=voice.title() + ' (local pack)')
        config['bank']['voices'][0]['name'] = config['name']
        for field in ('author', 'description'):
            if fields.get(field, '').strip():
                config[field] = fields[field].strip()
        revision = fields.get('modversion', '').strip()
        if re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', revision):
            config['bank']['revision'] = revision
        (folder / 'audio').mkdir()
        # Index once instead of making multiple filesystem calls per slot,
        # especially when the pack is on a Windows drive mounted in WSL.
        with os.scandir(audio) as entries:
            recordings = {entry.name: Path(entry.path) for entry in entries
                          if entry.name.endswith('.mp3') and entry.is_file(follow_symlinks=False)}
        copied = 0
        for slot, clip in project.slots(config).items():
            recording = recordings.get(voice + '_' + slot + '.mp3')
            if recording is None and slot in aliases:
                recording = recordings.get(voice + '_' + aliases[slot] + '.mp3')
            if recording is not None:
                destination = folder / config['assets'][clip['sound']]['source']
                shutil.copyfile(recording, destination)
                copied += 1
        if not copied:
            raise ValueError('No recordings match the current Core catalogue.')
        project.write(manifest, config)
        folder.rename(target)
    return key, target / 'project.json'
