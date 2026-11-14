"""Render Studio's Workshop covers using the bundled wordmark and flags."""
from pathlib import Path
import re
import shutil
import subprocess
from zipfile import ZipFile

ARTWORK = Path(__file__).with_name('artwork')
# Languages with several national flags use a representative locale.
LANGUAGE_COUNTRIES = {
    'EN': 'us', 'ES': 'es', 'ES_CL': 'cl', 'ES_MX': 'mx', 'PTBR': 'br',
    'JP': 'jp', 'JA': 'jp', 'CN': 'cn', 'ZH': 'cn', 'CH': 'tw', 'UA': 'ua', 'UK': 'ua',
    'AR': 'sa', 'BG': 'bg', 'BS': 'ba', 'CA': 'es-aut-ct', 'CS': 'cz',
    'DA': 'dk', 'EL': 'gr', 'ET': 'ee', 'FA': 'ir', 'HE': 'il', 'HI': 'in',
    'HR': 'hr', 'HY': 'am', 'KA': 'ge', 'KK': 'kz', 'KO': 'kr', 'KY': 'kg',
    'MS': 'my', 'MY': 'mm', 'NB': 'no', 'NN': 'no', 'NE': 'np', 'PA': 'in',
    'SK': 'sk', 'SL': 'si', 'SQ': 'al', 'SR': 'rs', 'SV': 'se', 'SW': 'tz',
    'TL': 'ph', 'UR': 'pk', 'VI': 'vn', 'BE': 'by', 'BN': 'bd',
    'AF': 'za', 'AM': 'et', 'AZ': 'az', 'EU': 'es', 'GL': 'es',
    'IS': 'is', 'KM': 'kh', 'LO': 'la', 'MN': 'mn', 'PS': 'af', 'SI': 'lk',
    'TA': 'in', 'TE': 'in', 'GU': 'in', 'MR': 'in', 'KN': 'in', 'ML': 'in',
    'FIL': 'ph', 'YUE': 'hk', 'CY': 'gb-wls', 'GD': 'gb-sct', 'GA': 'ie',
}
SAME_CODE = frozenset('AZ DE EE FI FR ID IS IT LA LT LU LV MT NL NO PL PT RO RU TH TR'.split())


def flag_code(language):
    return LANGUAGE_COUNTRIES.get(language, language.lower() if language in SAME_CODE else 'neutral')


def render(workshop, mod, language, ffmpeg):
    if not re.fullmatch(r'[A-Z_]{2,8}', language):
        raise ValueError('Invalid voice language for the cover')
    with ZipFile(ARTWORK / 'flags.zip') as flags:
        name = flag_code(language) + '.png'
        flag = flags.read(name) if name in flags.namelist() else (ARTWORK / 'neutral.png').read_bytes()
    for template, filename, flag_width, flag_height, margin in [
        ('square', 'preview.png', 92, 62, 44),
        ('wide', 'preview-16x9.png', 156, 104, 108),
    ]:
        filters = (
            f'[1:v]scale={flag_width}:{flag_height}:force_original_aspect_ratio=decrease[flag];'
            f'[0:v][flag]overlay=main_w-overlay_w-{margin}:{margin}:format=rgb'
        )
        if template == 'square':
            filters += ',scale=256:256:flags=lanczos'
        subprocess.run([
            ffmpeg, '-nostdin', '-v', 'error', '-i', str(ARTWORK / f'{template}.png'),
            '-f', 'image2pipe', '-c:v', 'png', '-i', 'pipe:0',
            '-filter_complex_threads', '1', '-filter_complex', filters,
            '-frames:v', '1', '-threads', '1', str(workshop / filename),
        ], input=flag, capture_output=True, check=True, timeout=30)
    for folder in (mod, mod / '42'):
        for name in ('poster.png', 'icon.png'):
            shutil.copy2(workshop / 'preview.png', folder / name)
        info = folder / 'mod.info'
        info.write_text(info.read_text(encoding='utf-8') + 'icon=icon.png\n', encoding='utf-8')
