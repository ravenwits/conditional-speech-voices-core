"""Optional Eleven v4 previews. The local server owns credentials and prompt construction."""
from concurrent.futures import Future
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import secrets
from statistics import median
import tempfile
from threading import Lock, Thread
import unicodedata
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, HTTPRedirectHandler, build_opener

import recording_guidance
import studio_schema
import voice_project as project

API = 'https://api.elevenlabs.io'
MODEL = 'eleven_v4'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def provider_request(key, path, payload=None):
    if not key:
        raise ValueError('Connect an ElevenLabs API key first.')
    audio_response = path.startswith('/v1/text-to-speech/')
    body = json.dumps(payload, ensure_ascii=False).encode() if payload is not None else None
    request = Request(API + path, data=body, headers={
        'xi-api-key': key, 'Content-Type': 'application/json',
    })
    try:
        with build_opener(NoRedirect()).open(request, timeout=45 if audio_response else 6) as response:
            content = response.read(project.MAX_AUDIO + 1)
            if len(content) > project.MAX_AUDIO:
                raise ValueError('ElevenLabs returned a response larger than Studio can accept.')
            if audio_response:
                if not content or response.headers.get_content_type() not in ('audio/mpeg', 'audio/mp3'):
                    raise ValueError('ElevenLabs did not return playable MP3 audio.')
                cost = response.headers.get('character-cost', '')
                request_id = response.headers.get('request-id', '')
                cost = int(cost) if cost.isascii() and cost.isdigit() and len(cost) <= 12 else None
                return content, cost, request_id[:160] or None
            return json.loads(content)
    except HTTPError as error:
        messages = {
            401: 'ElevenLabs rejected the API key.',
            403: 'The ElevenLabs API key or plan does not allow this action.',
            404: 'This voice or model is unavailable to your ElevenLabs account.',
            422: 'ElevenLabs could not use this voice, language, or line.',
            429: 'ElevenLabs is limiting requests. Check your credits and try again.',
        }
        raise ValueError(messages.get(error.code, f'ElevenLabs request failed (HTTP {error.code}).')) from None
    except (URLError, TimeoutError, OSError, UnicodeError, json.JSONDecodeError):
        message = 'ElevenLabs could not be reached.'
        if audio_response:
            message += ' Check your usage before generating again.'
        raise ValueError(message) from None


def voice_identifier(value):
    return isinstance(value, str) and bool(re.fullmatch(r'[A-Za-z0-9_-]{1,80}', value))


def credits(key):
    subscription = provider_request(key, '/v1/user/subscription')
    used, limit = subscription.get('character_count'), subscription.get('character_limit')
    if not all(type(value) is int and value >= 0 for value in (used, limit)):
        raise ValueError('ElevenLabs did not report a credit balance.')
    return {'used': used, 'limit': limit, 'remaining': max(0, limit - used)}


KEY_FIELD = 'ELEVENLABS_API_KEY'
KEY_LINE = re.compile(r'^\s*(?:export\s+)?ELEVENLABS_API_KEY\s*=\s*(.*?)\s*$')


def valid_key(value):
    return isinstance(value, str) and bool(re.fullmatch(r'[A-Za-z0-9_-]{16,256}', value))


def saved_key(path):
    if not path.is_file() or path.is_symlink():
        return ''
    for line in reversed(path.read_text(encoding='utf-8-sig').splitlines()):
        match = KEY_LINE.fullmatch(line)
        if match:
            value = match[1].strip("'\"")
            return value if valid_key(value) else ''
    return ''


def save_key(path, key):
    if path.is_symlink():
        raise ValueError('Studio cannot save a key to a linked .env.local file.')
    existing = path.read_text(encoding='utf-8-sig').splitlines() if path.exists() else []
    lines = [line for line in existing if not KEY_LINE.fullmatch(line)]
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write('\n'.join([*lines, f'{KEY_FIELD}={key}']) + '\n')
        temporary.replace(path)
    finally:
        if temporary:
            temporary.unlink(missing_ok=True)


def language_code(value):
    if isinstance(value, str):
        base = re.split(r'[-_]', value.strip().lower(), maxsplit=1)[0]
        base = {'ptbr': 'pt', 'jp': 'ja', 'cn': 'zh', 'ch': 'zh', 'ua': 'uk'}.get(base, base)
        if re.fullmatch(r'[a-z]{2}', base):
            return base


def voice_languages(voice):
    verified = voice.get('verified_languages') or []
    provider_codes = [row.get('language') or row.get('locale') for row in verified if isinstance(row, dict)]
    labels = voice.get('labels') or {}
    if isinstance(labels, dict):
        provider_codes.append(labels.get('language'))
    verification = voice.get('voice_verification') or {}
    if isinstance(verification, dict) and verification.get('is_verified'):
        provider_codes.append(verification.get('language'))
    return sorted({code.upper() for value in provider_codes if (code := language_code(value))})


def voice_summary(voice):
    labels = voice.get('labels') or {}
    primary = language_code(voice.get('language')) or (
        language_code(labels.get('language')) if isinstance(labels, dict) else None)
    sharing = voice.get('sharing') or {}
    return {'id': voice['voice_id'], 'owned': voice.get('is_owner') is True,
            'originalId': sharing.get('original_voice_id'), 'name': voice.get('name') or voice['voice_id'],
            'category': voice.get('category') or '', 'languages': voice_languages(voice),
            'primaryLanguage': primary.upper() if primary else None}


def library_voices(key, language, page, search):
    if not language:
        raise ValueError('ElevenLabs needs a supported project language to search the Voice Library.')
    number = int(page or 0)
    if number < 0 or number > 10000:
        raise ValueError('Invalid Voice Library page.')
    params = {'language': language, 'page_size': 50, 'page': number, 'sort': 'cloned_by_count',
              'include_custom_rates': 'true'}
    if search:
        params['search'] = search
    result = provider_request(key, '/v1/shared-voices?' + urlencode(params))
    matches = [
        dict(voice_summary(voice), owner=voice['public_owner_id'])
        for voice in result.get('voices', [])
        if voice_identifier(voice.get('voice_id')) and voice_identifier(voice.get('public_owner_id'))
        and language_code(voice.get('language')) == language
    ]
    return {'voices': matches, 'next': str(number + 1) if result.get('has_more') else None}


def add_library_voice(key, owner, voice, name):
    if not voice_identifier(owner) or not voice_identifier(voice):
        raise ValueError('Select a Voice Library voice first.')
    if not isinstance(name, str) or not name.strip() or len(name) > 256 or any(ord(c) < 32 for c in name):
        raise ValueError('The selected voice name could not be saved.')
    result = provider_request(key, f'/v1/voices/add/{owner}/{voice}', {'new_name': name})
    identifier = result.get('voice_id')
    if not voice_identifier(identifier):
        raise ValueError('ElevenLabs did not return the added voice ID. Check My Voices before trying again.')
    return identifier


def voices(key, token=None, search=''):
    params = {'page_size': 50, 'include_total_count': 'false'}
    if token:
        params['next_page_token'] = token
    if search:
        params['search'] = search
    result = provider_request(key, '/v2/voices?' + urlencode(params))
    return {
        'voices': [
            voice_summary(voice)
            for voice in result.get('voices', []) if voice_identifier(voice.get('voice_id'))
        ],
        'next': result.get('next_page_token') if result.get('has_more') else None,
    }


def prompt(config, slot):
    definition = studio_schema.entry(slot)
    if definition['category'] != 'Dialogue':
        raise ValueError('Use Record audio or Import audio for this nonverbal take.')
    language = language_code(config['bank']['language'])
    if not language:
        raise ValueError('This project needs a two-letter ElevenLabs language code.')
    caption, script = project.recording_text(config, slot)
    text = unicodedata.normalize('NFC', caption).strip()
    if not text or not any(char.isalnum() for char in text):
        raise ValueError('Save a spoken line before generating.')
    if re.search(r'[\[\]<>/［］＜＞]', unicodedata.normalize('NFKC', text)):
        raise ValueError('Remove audio tags, markup, and phonetic directives from the spoken text.')
    if script is not None:
        script = unicodedata.normalize('NFC', script).strip()
        if project.strip_audio_tags(script) != text:
            raise ValueError('The caption changed. Save the spoken text again before generating.')
    else:
        _, tags = recording_guidance.performance(slot, config['bank']['language'])
        script = ' '.join([*tags, text])
    return {
        'model_id': MODEL,
        'language_code': language,
        'text': script,
    }


class StudioSpeech:
    def __init__(self, env_file):
        self.env_file = env_file
        try:
            local_key = saved_key(env_file)
        except (OSError, UnicodeError):
            local_key = ''
        self.key = local_key or os.environ.get(KEY_FIELD, '').strip()
        self.preview = None
        self.model_factor = None
        self.history_lock = Lock()

    def base_estimate(self, payload):
        if self.model_factor is None:
            try:
                models = provider_request(self.key, '/v1/models')
                model = next((row for row in models if row.get('model_id') == MODEL), {})
                factor = (model.get('model_rates') or {}).get('character_cost_multiplier')
                if factor is None:
                    factor = model.get('token_cost_factor')
                if isinstance(factor, (int, float)) and 0 < factor <= 100:
                    self.model_factor = factor
            except (ValueError, TypeError, AttributeError):
                pass
        # ElevenLabs documents a base rate of one credit per character.
        return math.ceil(len(payload['text']) * (self.model_factor or 1))

    def estimate(self, manifest, voice, payload):
        samples = [
            entry['cost'] / entry['characters']
            for entry in self.history(manifest)
            if entry.get('voice') == voice and entry.get('model') == payload['model_id']
            and entry.get('language') == payload['language_code'] and entry.get('status') == 'generated'
            and isinstance(entry.get('cost'), int) and entry['cost'] > 0
            and isinstance(entry.get('characters'), int) and entry['characters'] > 0
        ][:10]
        if samples:
            return max(1, round(len(payload['text']) * median(samples))), len(samples)
        return self.base_estimate(payload), 0

    def history_path(self, manifest):
        return project.contained(manifest.parent, '.elevenlabs-requests.jsonl')

    def record_request(self, manifest, entry):
        with self.history_lock, self.history_path(manifest).open('a', encoding='utf-8') as handle:
            handle.write('\n' + json.dumps(entry, ensure_ascii=True) + '\n')
            handle.flush()
            os.fsync(handle.fileno())

    def history(self, manifest):
        path = self.history_path(manifest)
        latest = {}
        with self.history_lock:
            if not path.is_file():
                return []
            for line in path.read_text(encoding='utf-8').splitlines():
                try:
                    event = json.loads(line)
                    latest[event['id']] = event
                except (ValueError, TypeError, KeyError):
                    # A stopped process can leave a partial final line.
                    continue
        return list(reversed(latest.values()))[:50]

    def connect(self, key):
        if self.preview and not self.preview['future'].done():
            raise ValueError('Wait for the active preview before changing the API key.')
        if not valid_key(key):
            raise ValueError('Enter a valid ElevenLabs API key.')
        result = voices(key)
        try:
            save_key(self.env_file, key)
        except (OSError, UnicodeError):
            raise ValueError('Studio could not save the API key to .env.local. Check write access.') from None
        self.key = key
        self.model_factor = None
        self.preview = None
        return result

    def describe(self, manifest, slot):
        config = project.read(manifest)
        studio_schema.validate(config)
        if slot not in project.slots(config):
            raise ValueError('Unknown recording slot.')
        voice = config.get('authoring', {}).get('elevenLabsVoice', '')
        if not self.key or not voice_identifier(voice):
            raise ValueError('Choose an ElevenLabs voice in this project first.')
        payload = prompt(config, slot)
        return voice, payload

    def generate(self, manifest, slot, key):
        if not isinstance(slot, str):
            raise ValueError('Unknown recording slot.')
        if self.preview and not self.preview['future'].done():
            raise ValueError('An ElevenLabs preview is already generating.')
        voice, payload = self.describe(manifest, slot)
        config = project.read(manifest)
        future = Future()
        entry = self.preview = dict(id=secrets.token_urlsafe(24), future=future, manifest=manifest,
                                    project=key, slot=slot, voice=voice, payload=payload,
                                    recording=project.fingerprint(config, slot, manifest.parent))
        api_key = self.key
        log = {'id': entry['id'], 'slot': slot, 'voice': voice, 'model': MODEL,
               'language': payload['language_code'], 'characters': len(payload['text']),
               'estimate': self.estimate(manifest, voice, payload)[0], 'time': datetime.now(timezone.utc).isoformat()}
        try:
            self.record_request(manifest, dict(log, status='submitted'))
        except OSError:
            self.preview = None
            raise ValueError('Studio could not save the request history. Preview was not sent.') from None

        def run():
            try:
                audio, cost, request_id = provider_request(
                    api_key, f'/v1/text-to-speech/{voice}?output_format=mp3_44100_128', payload)
            except Exception as error:
                try:
                    self.record_request(manifest, dict(log, status='unconfirmed'))
                except OSError:
                    pass
                future.set_exception(error if isinstance(error, ValueError) else ValueError('ElevenLabs generation failed.'))
            else:
                try:
                    self.record_request(manifest, dict(log, status='generated', cost=cost, requestId=request_id))
                except OSError:
                    future.set_exception(ValueError('Audio was generated, but Studio could not save the result to history. Check your usage before trying again.'))
                else:
                    future.set_result((audio, cost))

        Thread(target=run, daemon=True).start()
        return {'id': entry['id']}

    def candidate(self, manifest, key, identifier):
        entry = self.preview
        if not entry or (entry['manifest'], entry['project'], entry['id']) != (manifest, key, identifier):
            raise ValueError('This preview has expired. Generate another for the current project.')
        return entry

    def status(self, manifest, key, identifier):
        future = self.candidate(manifest, key, identifier)['future']
        return {'ready': True, 'cost': future.result()[1]} if future.done() else {'ready': False}

    def accept(self, manifest, key, slot, identifier, ffmpeg):
        entry = self.candidate(manifest, key, identifier)
        if not entry['future'].done() or entry['slot'] != slot:
            raise ValueError('Select the recording this preview was generated for.')
        voice, payload = self.describe(manifest, slot)
        config = project.read(manifest)
        if (voice, payload) != (entry['voice'], entry['payload']) or (
            project.fingerprint(config, slot, manifest.parent) != entry['recording']
        ):
            raise ValueError('The recording, caption, or voice changed. Generate a fresh preview.')
        audio, _ = entry['future'].result()
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'preview.mp3'
            source.write_bytes(audio)
            project.import_audio(manifest, slot, source, ffmpeg, keep_previous=True)
        self.preview = None
        return {'message': 'Take saved. Listen before approving.'}
