"""A loopback-only editor for one local voice project."""
from functools import lru_cache
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import secrets
import shutil
import socket
import re
import tempfile
import subprocess
from urllib.parse import parse_qs, urlparse
import webbrowser
import studio_schema
import studio_elevenlabs as elevenlabs
from workshop_artwork import available_flag_languages, cover_image

import voice_project as project


def make_server(manifest, ffmpeg, core, port=0):
    manifest = manifest.resolve()
    studio_schema.verify_current()
    project.sync_core(manifest)
    projects_root = manifest.parent / 'projects'
    initial_manifest = manifest
    workspace_root = manifest.parent.parent if manifest.parent.name == 'my_voice' else None
    active_project = 'current'
    token = secrets.token_urlsafe(32)
    checkout = next((folder for folder in Path(__file__).resolve().parents
                     if (folder / 'studio' / 'package.json').is_file()), None)
    # A distributed copy uses its local projects root.
    env_root = (checkout or workspace_root) if workspace_root else manifest.parent
    speech = elevenlabs.StudioSpeech(env_root / '.env.local')

    @lru_cache(maxsize=16)
    def preview(template, language):
        return cover_image(template, language, ffmpeg)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args): pass

        def respond(self, content, kind='application/json', status=200):
            data = content if isinstance(content, bytes) else (
                json.dumps(content, ensure_ascii=False).encode() if kind == 'application/json' else content.encode())
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'; connect-src 'self'; media-src 'self' blob:; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'")
            try:
                self.end_headers()
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError):
                # A tab reload can close the connection while a response is in flight.
                self.close_connection = True

        def local_request(self):
            host = f'127.0.0.1:{self.server.server_port}'
            if self.headers.get('Host') != host: return False
            origin = self.headers.get('Origin')
            if origin and origin != 'http://' + host: return False
            return True

        def authorized(self):
            return self.local_request() and self.headers.get('X-Voice-Token') == token

        def do_GET(self):
            url = urlparse(self.path)
            if url.path == '/' and self.local_request():
                html = (Path(__file__).parent/'studio/index.html').read_text(encoding='utf-8')
                self.respond(html.replace('__VOICE_SESSION__', token), 'text/html; charset=utf-8')
                return
            if url.path.startswith('/studio/flag/') and self.local_request():
                from workshop_artwork import flag_image
                try:
                    self.respond(flag_image(url.path.rsplit('/', 1)[-1]), 'image/png')
                except (ValueError, OSError):
                    self.respond({'error': 'Flag not found'}, status=404)
                return
            cover = re.fullmatch(r'/studio/cover/(square|wide)/([A-Z_]{2,16})', url.path)
            if cover and self.local_request():
                try:
                    self.respond(preview(*cover.groups()), 'image/png')
                except (ValueError, OSError, subprocess.SubprocessError):
                    self.respond({'error': 'Cover preview unavailable'}, status=503)
                return
            if url.path.startswith('/studio/assets/') and self.local_request():
                try:
                    path = project.contained(Path(__file__).parent/'studio/assets', url.path[len('/studio/assets/'):])
                    kinds={'.js':'text/javascript', '.css':'text/css', '.woff2':'font/woff2'}
                    if path.suffix not in kinds: raise ValueError('Not an interface asset')
                    self.respond(path.read_bytes(), kinds[path.suffix])
                except (ValueError,OSError): self.respond({'error':'Not found'},status=404)
                return
            # The custom header forces a cross-origin preflight, which we do not allow.
            # An already open local tab can recover after this process restarts.
            if url.path == '/session' and self.local_request() and self.headers.get('X-Voice-Request') == 'local-editor':
                self.respond({'token': token})
                return
            if not self.authorized():
                self.respond({'error': 'Unauthorized local request'}, status=403)
                return
            try:
                if url.path == '/project':
                    voice = project.read(manifest).get('authoring', {}).get('elevenLabsVoice', '')
                    state = project.rows(manifest)
                    language = elevenlabs.language_code(state['language'])
                    self.respond(dict(state, projectKey=active_project, languageFlags=available_flag_languages(),
                                      elevenLabs={'configured': bool(speech.key), 'voice': voice,
                                                  'languageCode': language.upper() if language else ''}))
                elif url.path == '/elevenlabs/credits':
                    self.respond(elevenlabs.credits(speech.key))
                elif url.path == '/elevenlabs/history':
                    self.respond(speech.history(manifest))
                elif url.path == '/elevenlabs/library':
                    query = parse_qs(url.query)
                    language = elevenlabs.language_code(project.read(manifest)['bank']['language'])
                    self.respond(elevenlabs.library_voices(
                        speech.key, language, query.get('next', [''])[0][:12], query.get('search', [''])[0][:100]))
                elif url.path == '/elevenlabs/voices':
                    query = parse_qs(url.query)
                    self.respond(elevenlabs.voices(speech.key, query.get('next', [''])[0][:2048], query.get('search', [''])[0][:100]))
                elif url.path in ('/elevenlabs/preview', '/audio/elevenlabs'):
                    identifier = parse_qs(url.query).get('id', [''])[0]
                    if url.path == '/elevenlabs/preview':
                        self.respond(speech.status(manifest, active_project, identifier))
                    else:
                        future = speech.candidate(manifest, active_project, identifier)['future']
                        if not future.done():
                            raise ValueError('Audio is still generating.')
                        self.respond(future.result()[0], 'audio/mpeg')
                elif url.path == '/recording-list':
                    studio_schema.verify_current()
                    current = project.rows(manifest)
                    if current['schemaError']:
                        raise ValueError(current['schemaError'])
                    recordings = [
                        {**{key: row[key] for key in ('slot', 'text', 'state')},
                         'filename': row['slot'] + '.mp3'}
                        for row in current['rows']
                    ]
                    self.respond(dict(projectKey=active_project, voice=current['voice'],
                                      language=current['language'], recordings=recordings))
                elif url.path == '/schema': self.respond(studio_schema.load())
                elif url.path == '/projects':
                    def choice(key, path):
                        config = project.read(path)
                        return dict(key=key, name=config['name'], language=config.get('bank', {}).get('language'))
                    choices = [choice('current', initial_manifest)]
                    if projects_root.is_dir():
                        for folder in sorted(projects_root.iterdir()):
                            path=project.contained(projects_root,folder.name+'/project.json')
                            if path.is_file(): choices.append(choice(folder.name, path))
                    if workspace_root:
                        for path in sorted(workspace_root.glob('*/project.json')):
                            key = path.parent.name
                            if path == initial_manifest or not re.fullmatch(r'[a-z][a-z0-9_]{0,47}', key):
                                continue
                            try:
                                saved = project.contained(workspace_root, key + '/project.json')
                                choices.append(choice('saved:' + key, saved))
                            except (ValueError, OSError, KeyError):
                                continue
                    self.respond(choices)
                elif url.path == '/duration':
                    from audio_processing import original_duration
                    self.respond({'duration':original_duration(manifest,parse_qs(url.query)['slot'][0],ffmpeg)})
                elif url.path == '/audio':
                    slot = parse_qs(url.query)['slot'][0]
                    config = project.read(manifest)
                    clip = project.slots(config)[slot]
                    path = project.contained(manifest.parent, config['assets'][clip['sound']]['source'])
                    self.respond(path.read_bytes(), 'audio/mpeg')
                else: self.respond({'error': 'Not found'}, status=404)
            except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
                self.respond({'error': str(error)}, status=400)

        def do_POST(self):
            nonlocal manifest, active_project
            if not self.authorized():
                self.respond({'error': 'Unauthorized local request'}, status=403)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                upload = self.path == '/import'
                limit = project.MAX_AUDIO if upload else (512*1024 if self.path=="/review" else 65536)
                if not 0 < length <= limit: raise ValueError('Request is empty or too large')
                # Opening selects a destination. It never saves edits to the source project.
                if self.path != '/open' and self.headers.get('X-Revision') != project.digest(manifest):
                    self.respond({'error': 'Project changed. Reload before saving.'}, status=409)
                    return
                body = self.rfile.read(length)
                if upload:
                    with tempfile.TemporaryDirectory() as folder:
                        source = Path(folder) / 'recording'
                        source.write_bytes(body)
                        project.import_audio(manifest, self.headers.get('X-Slot'), source, ffmpeg, keep_previous=True)
                    result = {'message': 'Imported. Listen before approving.'}
                else:
                    data = json.loads(body)
                    fields={'/elevenlabs/connect':{'key', 'project'}, '/elevenlabs/settings':{'voice', 'project', 'owner', 'name'},
                            '/elevenlabs/describe':{'slot', 'project'}, '/elevenlabs/generate':{'slot', 'project'},
                            '/elevenlabs/accept':{'slot', 'project', 'id'}, '/profanity':{'slot','enabled'}, '/save':{'slot','text','direction','state'}, '/metadata':{'name','author','description','packVersion','steamProfile'},
                            '/update':{'apply'}, '/jobs':{'rate'}, '/measure':set(), '/package':{'rightsConfirmed'},
                            '/create':{'voice','name','language','female','trial'}, '/open':{'key'}, '/open-pack':{'folder'}, '/browse-pack-folders':{'folder','native'}, '/remove-project':{'key'},
                            '/undo-review':set(), '/review':{'slots','state'}, '/process':{'slot','gainDb','semitones','restore','speed','trimStart','trimEnd'}}
                    if self.path not in fields:
                        self.respond({'error': 'Unknown Studio action. Check that the server and interface use the same version.'}, status=404)
                        return
                    if not isinstance(data,dict) or set(data)-fields[self.path]:
                        raise ValueError('Unknown fields or action. Core rules are read-only.')
                    if self.path.startswith('/elevenlabs/') and data.get('project') != active_project:
                        self.respond({'error': 'The active project changed. Reopen the project before continuing.'}, status=409)
                        return
                    if self.path == '/elevenlabs/connect':
                        result = speech.connect(data['key'])
                    elif self.path == '/elevenlabs/settings':
                        voice = data['voice']
                        if voice != '' and (not speech.key or not elevenlabs.voice_identifier(voice)):
                            raise ValueError('Connect ElevenLabs and choose a voice first.')
                        config = project.read(manifest)
                        if 'owner' in data:
                            voice = elevenlabs.add_library_voice(speech.key, data['owner'], voice, data.get('name'))
                        authoring = config.setdefault('authoring', {})
                        if voice:
                            authoring['elevenLabsVoice'] = voice
                        else:
                            authoring.pop('elevenLabsVoice', None)
                        project.write(manifest, config)
                        result = {'message': 'ElevenLabs settings saved.', 'voice': voice}
                    elif self.path == '/elevenlabs/describe':
                        voice, payload = speech.describe(manifest, data['slot'])
                        estimate, samples = speech.estimate(manifest, voice, payload)
                        result = {'voice': voice, 'characterCount': len(payload['text']), 'prompt': payload['text'],
                                  'estimatedCredits': estimate, 'estimateSamples': samples}
                    elif self.path == '/elevenlabs/generate':
                        result = speech.generate(manifest, data['slot'], active_project)
                    elif self.path == '/elevenlabs/accept':
                        result = speech.accept(manifest, active_project, data['slot'], data['id'], ffmpeg)
                    elif self.path == '/save':
                        row = project.edit(manifest, data['slot'], data['text'], data['direction'], data['state'])
                        result = {'message': 'Saved to project file.', 'row': row}
                    elif self.path == '/profanity': result={'row':project.mark_profanity(manifest,data['slot'],data['enabled'])}
                    elif self.path == '/undo-review': result=project.undo_review(manifest)
                    elif self.path == '/review': result=project.review_many(manifest,data['slots'],data['state'])
                    elif self.path == '/metadata':
                        config = project.read(manifest)
                        version = data.get('packVersion', config['bank']['revision'])
                        if not isinstance(version, str) or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
                            raise ValueError('Use a three-part version such as 1.0.0')
                        config['bank']['revision'] = version
                        from recording_limits import steam_profile
                        config['steamProfile']=steam_profile(data.get('steamProfile',config.get('steamProfile','')))
                        for key in ('name', 'author', 'description'):
                            value = data[key]
                            if not isinstance(value, str) or not value.strip() or len(value) > 1000 or '\n' in value or '\r' in value:
                                raise ValueError('Metadata must be a nonempty single line')
                            config[key] = value.strip()
                        config['bank']['voices'][0]['name'] = config['name']
                        project.write(manifest, config)
                        result = {'message': 'Project details saved.'}
                    elif self.path == '/update': result = project.refresh(manifest, bool(data.get('apply')))
                    elif self.path == '/jobs': result = project.jobs(manifest, float(data.get('rate', 0)))
                    elif self.path == '/process':
                        from audio_processing import process
                        if 'restore' in data and not isinstance(data['restore'],bool): raise ValueError('Invalid restore setting')
                        result=process(manifest,data['slot'],ffmpeg,data.get('gainDb',0),data.get('semitones',0),data.get('restore',False),data.get('speed',1),data.get('trimStart',0),data.get('trimEnd',0))
                    elif self.path == '/create':
                        from prepare_voice_pack import initialize
                        voice=data['voice']
                        if not isinstance(voice,str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,47}',voice) or voice=='current':
                            raise ValueError('Use a new lowercase voice ID with letters, numbers or underscores.')
                        for key in ('female','trial'):
                            if key in data and not isinstance(data[key],bool): raise ValueError('Invalid project choice')
                        name=data.get('name',voice.title())
                        if not isinstance(name,str) or not name.strip() or len(name)>80 or any(ord(c)<32 for c in name): raise ValueError('Enter a voice name of 1 to 80 characters.')
                        target=project.contained(projects_root,voice+'/project.json')
                        prefix_key = voice.replace('_', '')
                        if prefix_key in {'bob', 'kate', 'alp', 'mujde'}:
                            raise ValueError('This voice ID conflicts with an official pack. Choose a different ID.')
                        known_projects = [initial_manifest]
                        known_projects.extend(
                            project.contained(projects_root, path.relative_to(projects_root))
                            for path in projects_root.glob('*/project.json')
                        )
                        for known in known_projects:
                            for entry in project.read(known)['bank']['voices']:
                                existing_id = entry['id']
                                native_prefix = entry.get('prefix', '').lower()
                                if existing_id == voice or native_prefix == f'voicecsv{prefix_key}p':
                                    raise ValueError(f'Voice ID conflicts with {existing_id}. Choose a different ID.')
                        initialize(target,voice,data['language'],data.get('female',False),data.get('trial',False))
                        created=project.read(target)
                        created['bank']['voices'][0]['name']=name.strip()
                        created['name']=name.strip()
                        project.write(target,created)
                        manifest=target; active_project=voice
                        result={'message':'Project created. Import your recordings to begin.'}
                    elif self.path == '/remove-project':
                        key = data['key']
                        if not isinstance(key, str) or key == 'current' or not re.fullmatch(r'[a-z][a-z0-9_]{0,47}', key):
                            raise ValueError('The startup project is protected.')
                        folder = project.contained(projects_root, key)
                        if not (folder / 'project.json').is_file():
                            raise ValueError('Project not found.')
                        raw_folder = projects_root / key
                        if raw_folder.is_symlink() or bool(getattr(raw_folder.lstat(), 'st_file_attributes', 0) & 0x400) or folder.parent != projects_root.resolve():
                            raise ValueError('Cannot delete a linked project directory.')
                        shutil.rmtree(folder)
                        if active_project == key:
                            manifest = initial_manifest
                            active_project = 'current'
                        result = {'message': 'Project permanently deleted.'}
                    elif self.path == '/browse-pack-folders':
                        from open_voice_pack import browse_folders, choose_windows_folder
                        folder = data.get('folder')
                        if folder is not None and not isinstance(folder, str):
                            raise ValueError('Invalid folder path.')
                        if data.get('native') is True:
                            try:
                                result = {'selected': choose_windows_folder()}
                            except (ValueError, OSError):
                                result = {'selected': None, 'unavailable': True}
                        else:
                            result = browse_folders(folder, initial_manifest.parent)
                    elif self.path == '/open-pack':
                        from open_voice_pack import import_voice, open_pack, resolve_folder
                        value = data.get('folder')
                        if value is not None and not isinstance(value, str):
                            raise ValueError('Invalid folder path.')
                        value = value.strip() if value else None
                        result = {'opened': False}
                        if value:
                            known = {'current': initial_manifest}
                            for path in sorted(projects_root.glob('*/project.json')):
                                known[path.parent.name] = project.contained(projects_root, path.relative_to(projects_root))
                            if workspace_root:
                                for path in sorted(workspace_root.glob('*/project.json')):
                                    if path != initial_manifest and re.fullmatch(r'[a-z][a-z0-9_]{0,47}', path.parent.name):
                                        known['saved:' + path.parent.name] = project.contained(workspace_root, path.relative_to(workspace_root))
                            mod_id, fields, audio, language, voices = open_pack(resolve_folder(value), known, projects_root)
                            for voice, key in voices.items():
                                if key is None:
                                    key, known_key = import_voice(mod_id, fields, audio, language, voice, projects_root)
                                    known[key] = known_key
                                    voices[voice] = key
                            key = active_project if active_project in voices.values() else next(iter(voices.values()))
                            target = known[key]
                            project.sync_core(target)
                            studio_schema.validate(project.read(target))
                            manifest, active_project = target, key
                            result = {'opened': True, 'message': 'Voice pack opened.'}
                    elif self.path == '/open':
                        key=data['key']
                        if key=='current': target=initial_manifest
                        elif workspace_root and isinstance(key, str) and re.fullmatch(r'saved:[a-z][a-z0-9_]{0,47}', key):
                            target=project.contained(workspace_root,key[6:]+'/project.json')
                        elif isinstance(key,str) and re.fullmatch(r'[a-z][a-z0-9_]{0,47}',key):
                            target=project.contained(projects_root,key+'/project.json')
                        else: raise ValueError('Unknown project')
                        project.sync_core(target)
                        studio_schema.validate(project.read(target))
                        manifest=target; active_project=key
                        result={'message':'Project opened.'}
                    elif self.path == '/measure':
                        from prepare_voice_pack import measure
                        measure(manifest, ffmpeg, allow_missing=True)
                        report = project.read(manifest.with_suffix('.loudness.json'))
                        result = dict(message=f"Measured {len(report['recordings'])} recordings without changing the audio. {len(report['missing'])} slots still missing.", outliers=report['outliers'])
                    elif self.path == '/package':
                        if data.get('rightsConfirmed') is not True: raise ValueError('Confirm you have permission to distribute these recordings.')
                        config = project.read(manifest)
                        name = config['modId'] + '-' + config['bank']['revision']
                        output = project.contained(manifest.parent, 'dist/' + name)
                        result = project.workshop_project(manifest, output, ffmpeg, core)
                    else: raise ValueError('Unknown action')
                self.respond(dict(result=result, revision=project.digest(manifest)))
            except Exception as error:
                # Do not expose subprocess output, which can contain private service data.
                import subprocess
                message = 'Audio tool failed. Check the recording and local tool installation.' if isinstance(error, subprocess.SubprocessError) else str(error)
                self.respond({'error': message}, status=400)

    class StudioServer(HTTPServer):
        def server_bind(self):
            if hasattr(socket, 'SO_EXCLUSIVEADDRUSE'):
                self.allow_reuse_address = False
                self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            super().server_bind()

    server = StudioServer(('127.0.0.1', port), Handler)
    server.timeout = 1
    return server, f'http://127.0.0.1:{server.server_port}/'


def serve(manifest, ffmpeg, core, port=0, open_browser=True):
    project.voice_id(project.read(manifest))
    server, url = make_server(manifest, ffmpeg, core, port)
    print(url, flush=True)
    print('Local editor. Ctrl+C stops it. ElevenLabs is optional.', flush=True)
    if open_browser: webbrowser.open(url)
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()
