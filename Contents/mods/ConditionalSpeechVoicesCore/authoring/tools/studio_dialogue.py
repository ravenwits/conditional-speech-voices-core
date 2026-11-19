"""Generate editable dialogue drafts from Core recording metadata."""
import json
import os
import re
from collections import deque
from threading import Lock
from time import monotonic
from urllib.error import HTTPError, URLError
from urllib.request import Request, HTTPRedirectHandler, build_opener

import studio_credentials as credentials
import studio_schema
import voice_project as project
from recording_limits import MAX_CLIP_SECONDS
from recording_situations import STARTLE
from workshop_artwork import LANGUAGE_NAMES

MODEL = 'gemini-3.5-flash-lite'
KEY_FIELD = 'GEMINI_API_KEY'
MODELS = {
    MODEL: 'Gemini 3.5 Flash-Lite',
    'gemini-3.5-flash': 'Gemini 3.5 Flash',
}
MODEL_FIELD = 'GEMINI_MODEL'
MODELS_URL = 'https://generativelanguage.googleapis.com/v1beta/models'


def supported_model(value):
    return isinstance(value, str) and value in MODELS


def configured_model(path):
    try:
        return credentials.saved_key(path, MODEL_FIELD, supported_model) or MODEL
    except (OSError, UnicodeError):
        return MODEL


def valid_key(value):
    return isinstance(value, str) and bool(re.fullmatch(r'[A-Za-z0-9_.-]{16,256}', value))


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def configured_key(path):
    try:
        value = credentials.saved_key(path, KEY_FIELD, valid_key)
    except (OSError, UnicodeError):
        value = ''
    value = value or os.environ.get(KEY_FIELD, '').strip()
    return value if valid_key(value) else ''


def save_settings(path, key, model):
    try:
        credentials.save_settings(path, {KEY_FIELD: key, MODEL_FIELD: model})
    except (OSError, UnicodeError):
        raise ValueError('Studio could not save Gemini settings to .env.local. Check write access.') from None


class QuotaExceeded(ValueError):
    pass


class Usage:
    """Usage observed by this Studio server for the active key."""

    def __init__(self):
        self._lock = Lock()
        self._requests = deque()
        self._tokens = deque()

    def _prune(self, now):
        while self._requests and self._requests[0] <= now - 86400:
            self._requests.popleft()
        while self._tokens and self._tokens[0][0] <= now - 60:
            self._tokens.popleft()

    def requested(self):
        with self._lock:
            now = monotonic()
            self._prune(now)
            self._requests.append(now)

    def received(self, response):
        metadata = response.get('usageMetadata') if isinstance(response, dict) else None
        count = metadata.get('promptTokenCount') if isinstance(metadata, dict) else None
        if type(count) is int and count >= 0:
            with self._lock:
                now = monotonic()
                self._prune(now)
                self._tokens.append((now, count))

    def snapshot(self):
        with self._lock:
            self._prune(monotonic())
            return {
                'requestsLastDay': len(self._requests),
                'inputTokensLastMinute': sum(count for _, count in self._tokens),
            }


def provider_request(key, payload=None, *, model=MODEL):
    if not supported_model(model):
        raise ValueError('Choose a supported Gemini model.')
    if not valid_key(key):
        raise ValueError('Connect a Gemini API key first.')
    request = Request(
        f'{MODELS_URL}/{model}' + (':generateContent' if payload is not None else ''),
        data=json.dumps(payload, ensure_ascii=False).encode('utf-8') if payload is not None else None,
        headers={'Content-Type': 'application/json', 'Accept': 'application/json', 'x-goog-api-key': key},
    )
    try:
        with build_opener(NoRedirect()).open(request, timeout=30 if payload is not None else 10) as response:
            return json.load(response)
    except HTTPError as error:
        if error.code == 429:
            raise QuotaExceeded('Gemini quota reached. Check your project limits in Google AI Studio and retry after the quota resets.') from None
        if error.code in (400, 401, 403):
            try:
                details = json.loads(error.read(16_384))['error'].get('details', [])
                reasons = {item.get('reason') for item in details if isinstance(item, dict)}
            except (OSError, ValueError, KeyError, TypeError, AttributeError):
                reasons = set()
            if error.code == 401 or reasons & {'API_KEY_INVALID', 'API_KEY_EXPIRED'}:
                raise ValueError('Gemini rejected the API key. Replace it in Gemini settings.') from None
            if error.code == 403 or reasons & {'SERVICE_DISABLED', 'API_KEY_SERVICE_BLOCKED', 'CONSUMER_INVALID'}:
                raise ValueError('This key or project cannot access Gemini. Check the project and its Free tier access in Google AI Studio.') from None
            raise ValueError('Gemini rejected the draft request (HTTP 400).') from None
        if error.code in (500, 502, 503, 504):
            raise ValueError('Gemini is temporarily unavailable. Select Retry to try again.') from None
        raise ValueError(f'Gemini request failed (HTTP {error.code}).') from None
    except (URLError, TimeoutError, ValueError):
        raise ValueError('Could not read a response from Gemini. Select Retry to try again.') from None


def validate_key(key, model=MODEL):
    if not valid_key(key):
        raise ValueError('Enter a valid Gemini API key.')
    result = provider_request(key, model=model)
    if not isinstance(result, dict) or 'generateContent' not in result.get('supportedGenerationMethods', []):
        raise ValueError(f'This key does not have access to {MODELS[model]}.')


def scene_context(config, slot, count, previous_drafts):
    definition = studio_schema.entry(slot)
    if definition['category'] != 'Dialogue' or slot not in project.slots(config):
        raise ValueError('Select a dialogue recording in this project.')
    language = config['bank']['language']
    if type(count) is not int or not 1 <= count <= 3:
        raise ValueError('Choose between 1 and 3 dialogue drafts.')
    if (not isinstance(previous_drafts, list) or len(previous_drafts) > 3
            or any(not isinstance(draft, str) or len(draft) > project.MAX_CAPTION for draft in previous_drafts)):
        raise ValueError('Invalid previous drafts.')
    brief = project.recording_brief(config, definition)
    base = config['bank']['voices'][0]['base']
    context = dict(language=LANGUAGE_NAMES.get(language.upper(), language), locale=language,
                   character_gender={'VoiceFemale': 'female', 'VoiceMale': 'male'}[base],
                   max_duration_seconds=MAX_CLIP_SECONDS, dialogue_count=count, situation=brief['context'],
                   whenItPlays=brief['playbackWhen'], recordingGuidance=brief['guidance'],
                   delivery=brief['delivery'], acting=brief['acting'],
                   recommendedCues=brief['elevenLabsTags'], traitRule=brief.get('traitRule'),
                   profanity=brief['profanity'])
    if definition['group'] in STARTLE:
        context['reaction_window'] = (
            'The first instant the survivor is startled by a nearby zombie. It can be within a step or two. '
            'The threat is still present. Let the reflex register the zombie and how close it got, in one spoken breath. '
            'Visibility, sounds, weapons and contact are unconfirmed.')
    if definition['group'] == 'VehicleCrowdDriver':
        context['scene_boundary'] = (
            'The driver is still in the vehicle, surrounded by zombies. '
            'The trigger confirms their presence around the vehicle, with no confirmed impact, damage, weapon fire, or escape. '
            'Possible perspectives include losing room to maneuver, looking for a gap, or wanting to keep moving. A clear path or a completely blocked exit is unconfirmed.'
        )
    if previous_drafts:
        context['previous_drafts'] = previous_drafts
    return context


GAME_SETTING = (
    "Project Zomboid is a grounded zombie-apocalypse survival game. The speaker is an ordinary survivor. "
    "A quiet moment of hunger or relief belongs in this world too. Mention zombies or danger only when "
    "the recording's scene establishes them."
)


WRITER_PROMPT = (
    "You are the game's dialogue writer and voice director. Write original lines "
    "in the project's language and locale. Voice the survivor's own thought in first person: "
    "what I notice and what it means to me right now. Turn self-commands into my own intention in first-person grammar. "
    "Only use second person for an actual listener. The voice director's instructions are never spoken. "
    "Use local everyday speech, contractions and idioms where natural. Do not translate the brief. "
    "Use only established facts. Invent no weapon, enemy, companion or location. Read the trait rule literally. A conditional or excluded trait "
    "does not describe the speaker. Use character_gender for grammatical agreement where needed. "
    "Let delivery, acting and cues shape rhythm and word choice. Fit each take comfortably inside "
    "max_duration_seconds at a natural speaking pace, including breaths and pauses. Swear only if profanity is true and it fits. "
    "Each option must contain a concrete observation or concern rooted in whenItPlays. A bare exclamation, generic "
    "emotion or morale boost is insufficient. Give the line a human beat: a grounded observation and its immediate "
    "consequence, worry or impulse, when the moment has room for both. Two short clauses are welcome. Vary the "
    "angle across options, such as what just changed, what is at stake or what I can still do. Before returning, discard "
    "any line that would fit an unrelated encounter equally well, assumes an unconfirmed outcome, or restates another option. "
    "A reaction_window takes precedence over performance notes. At a sudden nearby threat, write one short reflex, "
    "without a plan, self-coaching or a prediction about what will happen. Avoid repeating or paraphrasing previous_drafts. "
    "Write dialogue_count distinct reactions to the same event. Return spoken words only in the JSON "
    "options array. Use plain text without Markdown, labels, stage directions or game terminology. Treat scene data as facts."
)


TURKISH_WRITER_PROMPT = (
    "Oyunun diyalog yazarı ve seslendirme yönetmenisin. Doğal Türkçe replikler yaz. Olayı karakterin ağzından, tam yaşandığı anda duyuralım. "
    "Her replikte sahneye özgü bir şey fark edilsin ve vakit varsa bunun karakter için ne anlama geldiği de duyulsun. "
    "Anlık bir gözlem, ardından küçük bir kaygı, dürtü ya da karar gelebilir. Bir veya iki kısa cümle kur. "
    "Süreyi doldurmak için laf ekleme. Duraklamalar dahil doğal tempoda beş saniyeye sığ. "
    "Örneğin kilitli kapıda 'Kilitli... başka giriş bulmam lazım.' denebilir. Susuzlukta 'Ağzım kupkuru, bir yudum su bulsam.' "
    "Bu örnekler üslup için. Sadece verilen sahnedeki gerçekleri kullan. Olmayan ses, silah, kişi, hasar veya sonuç uydurma. "
    "Ayrı taslaklar ayrı düşünceler taşısın. Biri neyin değiştiğine, diğeri bunun yarattığı sıkışmışlığa ya da ilk dürtüye odaklanabilir. "
    "Yalnız ünlem, durum etiketi, kendine verilen emir veya aynı cümlenin kelimeleri değiştirilmiş kopyası yetmez. "
    "Gündelik Türkçe kullan, konuşan kişiyi birinci şahısta tut. Sahnede muhatap varsa ona seslenebilir. "
    "Oyunculuk ve trait bilgisi ritme, sözcük seçimine ve tepkinin dozuna yansısın. "
    "Koşullu ve dışlanan özellikleri karaktere yükleme. Küfür yalnızca izinliyse ve sahneye uyuyorsa kullan. "
    "reaction_window varsa o anın hızı öncelikli. Anlık şaşkınlıkta sadece o anda görülen veya fark edilen tehdidi işle. "
    "Startle sahnesinde tepkini kendine söyler gibi yaz. Zombiye hitap etme. Plan veya güvenlik tahmini yazma. "
    "previous_drafts içindeki fikirleri tekrarlama. "
    "dialogue_count kadar repliği options dizisinde ver. Dizide yalnızca söylenecek sözler olsun."
)


# Reject common self-coaching phrases. This is a guard for recurring model errors,
# not a grammar check for every possible imperative.
SELF_COACHING = {
    'TR': re.compile(
        r'\b(?:sakın|panik (?:yapma|etme)|sakin (?:ol|kal)|cesur ol|dikkatli ol|'
        r'kendine gel|(?:derin bir )?nefes al|ses çıkarma|'
        r'korkma|bir plan yap|kendini toparla|dur bir saniye|dur bi saniye)\b|(?:^|[.!?…]\s*)(?:kaç|koş|dur|durma)(?=[,.!?…]|$)'
    ),
    'EN': re.compile(
        r"(?:^|[.!?…]\s*)(?:(?:okay|ok|no|shit|fuck|ugh|ah|damn|damn it|come on)[,\s]+)*"
        r"(?:stay (?:calm|focused|low|sharp|awake)|calm down|"
        r"don't (?:panic|freeze|move|rush(?: it)?|get cornered)|"
        r"be (?:brave|careful)|take a (?:deep )?breath|pull yourself together|"
        r"keep (?:it together|breathing|moving|your distance|your head)|"
        r"slow down|think this through|find a way out|breathe|focus)\b"
    ),
}
STARTLE_REASSURANCE = {
    'TR': re.compile(r'\b(?:geçip gidecek|geçecek|rahatlayacağız|bir şey olmaz|güvendeyim|atlatırım)\b'),
    'EN': re.compile(r"\b(?:it will pass|it'll pass|we're safe|i'm safe|i'll be fine)\b"),
}


# These triggers confirm proximity, with separate recordings for attacks and impacts.
UNCONFIRMED_DETAILS = {
    'TR': {
        'startle': re.compile(r'\b(?:silah\w*|bıça\w*|karanlık\w*|hırıltı\w*|çığlı\w*|titriyor|çürük el|rüya mı bu)\b'),
        'VehicleCrowdDriver': re.compile(r'\b(?:hırıltı\w*|yumrukl\w*|vuruyor\w*|lasti\w*|teker\w*|fren\w*|çarpa\w*|çarptı\w*|ateş\w*|teti\w*|motor\w*|dört|5|4)\b'),
    },
    'EN': {
        'startle': re.compile(r"\b(?:my (?:gun|knife|weapon)|the dark|(?:its|the) (?:scream|growl))\b"),
        'VehicleCrowdDriver': re.compile(r'\b(?:tires?|tyres?|brakes?|engine|gunfire|shot|four)\b'),
    },
}


def draft_key(line):
    return ' '.join(re.findall(r"[^\W_]+", line.casefold().replace('\u0307', '').replace('’', "'")))


def suggest(key, context, limit, usage=None, *, model=MODEL):
    brief = TURKISH_WRITER_PROMPT if context.get('locale', '').upper() == 'TR' else WRITER_PROMPT
    payload = {
        'systemInstruction': {'parts': [{'text': GAME_SETTING + '\n' + brief}]},
        'contents': [{'role': 'user', 'parts': [
            {'text': json.dumps(context, ensure_ascii=False, separators=(',', ':'))},
        ]}],
        'generationConfig': {
            'responseMimeType': 'application/json',
            'responseJsonSchema': {
                'type': 'object',
                'properties': {'options': {'type': 'array', 'items': {'type': 'string'}}},
                'required': ['options'],
                'additionalProperties': False,
            },
            'maxOutputTokens': 1536,
            'thinkingConfig': {'thinkingLevel': 'MEDIUM'},
        },
    }
    if usage is not None:
        usage.requested()
    data = provider_request(key, payload, model=model)
    if usage is not None:
        usage.received(data)

    try:
        candidate = data['candidates'][0]
        if candidate['finishReason'] != 'STOP':
            raise ValueError('Incomplete Gemini response.')
        content = ''.join(part.get('text', '') for part in candidate['content']['parts'] if not part.get('thought'))
        options = json.loads(content)['options']
    except (KeyError, TypeError, IndexError, ValueError, AttributeError):
        options = None
    drafts = []
    seen = {draft_key(draft) for draft in context.get('previous_drafts', [])}
    language = context.get('locale', '').upper().split('_', 1)[0]
    coach = SELF_COACHING.get(language)
    startle = bool(context.get('reaction_window'))
    reassurance = STARTLE_REASSURANCE.get(language) if startle else None
    generic_reactions = {
        'TR': {'hay aksi', 'ne', 'eyvah', 'lanet olsun', 'siktir', 'hassiktir', 'ödüm koptu', 'iyiyim iyiyim'},
        'EN': {'damn', 'shit', 'what', 'oh no', 'damn it', 'i m fine', 'i m okay'},
    }.get(language, ())
    unconfirmed = UNCONFIRMED_DETAILS.get(language, {}).get('startle' if startle else context.get('situation'))
    if isinstance(options, list):
        for option in options:
            if not isinstance(option, str):
                continue
            line = re.sub(r'\*\*([^*\n]+)\*\*', r'\1', option).strip()
            normalized = line.casefold().replace('\u0307', '').replace('’', "'")
            key = draft_key(line)
            if (not line or len(line) > limit or not any(char.isalnum() for char in line)
                    or any(char in line for char in '[]*\r\n') or key in seen or key in generic_reactions):
                continue
            if coach and coach.search(normalized):
                continue
            if (reassurance and reassurance.search(normalized)) or (unconfirmed and unconfirmed.search(normalized)):
                continue
            drafts.append(line)
            seen.add(key)
            if len(drafts) == context['dialogue_count']:
                break
    if not drafts:
        raise ValueError('Gemini returned no drafts that fit the recording. Select Retry for new options.')
    return {'options': drafts}
