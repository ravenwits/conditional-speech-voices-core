"""Inspect MP3s offline. Optional local transcripts add language and direction checks."""
import argparse
import array
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import math
from pathlib import Path
import re
import subprocess


def words(text):
    return ' '.join(re.findall(r'\w+', text.casefold()))


def language_flags(take, transcript):
    flags = []
    expected = words(take.get('text', ''))
    spoken = words(transcript.get('text', ''))
    language = transcript.get('language', '').lower().split('-')[0]
    if len(expected.split()) >= 4 and take.get('language') and language and language != take['language']:
        flags.append('review_language')
    for tag in re.findall(r'\[([^\[\]]+)\]', take.get('direction', '')):
        phrase = words(tag)
        if phrase and ' ' + phrase + ' ' in ' ' + spoken + ' ' and phrase not in expected:
            flags.append('review_spoken_direction')
            break
    return flags


def inspect(path, ffmpeg, take, transcript):
    result = subprocess.run([ffmpeg, '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '1',
                             '-ar', '16000', 'pipe:1'], capture_output=True, timeout=30)
    samples = array.array('f', result.stdout) if result.returncode == 0 else array.array('f')
    flags = []
    if not samples or any(not math.isfinite(x) for x in samples):
        return {'file': path.name, 'flags': ['decode_failed']}
    peak = max(map(abs, samples))
    if peak >= 1:
        flags.append('decoded_peak_over_full_scale')
    blocks = [samples[i:i + 320] for i in range(0, len(samples), 320)]
    levels = [math.sqrt(sum(x*x for x in block) / len(block)) for block in blocks]
    audible = [i for i, rms in enumerate(levels) if rms > .0056]  # -45 dBFS in 20 ms windows
    if not audible:
        flags.append('silent_or_very_quiet')
    else:
        if audible[0] >= 28 or len(levels) - 1 - audible[-1] >= 28:
            flags.append('long_edge_silence')
        if any(b - a >= 45 for a, b in zip(audible, audible[1:])):
            flags.append('long_internal_silence')
        if levels[0] > .035 or levels[-1] > .035:
            flags.append('review_abrupt_edge')
    if transcript:
        flags.extend(language_flags(take, transcript))
    return {'file': path.name, 'durationMs': round(len(samples) / 16), 'samplePeak': round(peak, 4),
            'transcriptChecked': bool(transcript), 'flags': flags}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directories', nargs='+', type=Path)
    parser.add_argument('--ffmpeg', required=True)
    parser.add_argument('--catalog', type=Path)
    parser.add_argument('--languages', type=Path, help='JSON mapping voice IDs to language codes')
    parser.add_argument('--transcripts', type=Path, help='JSON keyed by filename stem, with text and language fields')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    languages = json.loads(args.languages.read_text(encoding='utf-8')) if args.languages else {}
    takes = {}
    if args.catalog:
        for take in json.loads(args.catalog.read_text(encoding='utf-8')):
            key = take['voice'] + '_' + take['id']
            takes[key] = dict(take, language=take.get('language') or languages.get(take['voice']))
    transcripts = json.loads(args.transcripts.read_text(encoding='utf-8')) if args.transcripts else {}
    files = sorted({path for directory in args.directories for path in directory.glob('*.mp3')})
    if not files:
        raise SystemExit('No MP3 files found')
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(lambda path: inspect(path, args.ffmpeg, takes.get(path.stem, {}),
                                                  transcripts.get(path.stem)), files))
    summary = {'files': len(rows), 'transcriptChecks': sum(row.get('transcriptChecked', False) for row in rows),
               'flags': dict(Counter(flag for row in rows for flag in row['flags']))}
    args.output.write_text(json.dumps({'summary': summary, 'recordings': rows}, indent=2), encoding='utf-8')
    print(json.dumps(summary))
    if summary['flags'].get('decode_failed'):
        raise SystemExit(1)
