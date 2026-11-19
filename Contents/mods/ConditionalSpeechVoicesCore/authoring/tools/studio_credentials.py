"""Read and atomically update a provider key in the local settings file."""
from pathlib import Path
import re
import tempfile


def valid_key(value):
    return isinstance(value, str) and bool(re.fullmatch(r'[A-Za-z0-9_-]{16,256}', value))


def saved_key(path, field, validator=valid_key):
    key_line = re.compile(rf"^\s*(?:export\s+)?{re.escape(field)}\s*=\s*(.*?)\s*$")
    if not path.is_file() or path.is_symlink():
        return ''
    for line in reversed(path.read_text(encoding='utf-8-sig').splitlines()):
        match = key_line.fullmatch(line)
        if match:
            value = match[1].strip("'\"")
            return value if validator(value) else ''
    return ''


def save_key(path, field, key):
    save_settings(path, {field: key})


def save_settings(path, values):
    fields = '|'.join(re.escape(field) for field in values)
    key_line = re.compile(rf"^\s*(?:export\s+)?(?:{fields})\s*=.*$")
    if path.is_symlink():
        raise ValueError('Studio cannot save a key to a linked .env.local file.')
    existing = path.read_text(encoding='utf-8-sig').splitlines() if path.exists() else []
    lines = [line for line in existing if not key_line.fullmatch(line)]
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write('\n'.join([*lines, *(f'{field}={value}' for field, value in values.items())]) + '\n')
        temporary.replace(path)
    finally:
        if temporary:
            temporary.unlink(missing_ok=True)
