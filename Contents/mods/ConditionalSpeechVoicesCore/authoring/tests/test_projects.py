"""Run with python -B -m unittest discover -s authoring/tests -v."""
import copy
import http.client
import json
import os
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))
import voice_project as p
from prepare_voice_pack import initialize, measure
from voice_workbench import make_server
from build_voice_pack import validate, build
import studio_schema


class Projects(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = self.root / 'trial.json'
        initialize(self.manifest, 'sample', 'TR', trial=True)

    def supply(self, slot='Explore_2'):
        config = p.read(self.manifest)
        asset = config['assets'][p.slots(config)[slot]['sound']]
        path = p.contained(self.root, asset['source'])
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(b'test recording bytes' * 100)
        return path

    def approve(self, slot='Explore_2'):
        p.edit(self.manifest, slot, 'Buraya daha bakmadÄ±m.', 'A cautious observation.', 'approved')

    def test_presentation_separates_delivery_from_acting(self):
        normal=studio_schema.entry('Angry_1')
        whisper=studio_schema.entry('Whisper_Angry_1')
        breathless=studio_schema.entry('Expr_breathless_Thirst_1')
        self.assertEqual((normal['delivery'],normal['acting']),('normal','unspecified'))
        self.assertEqual((whisper['category'],whisper['delivery']),('Dialogue','whisper'))
        self.assertEqual((breathless['delivery'],breathless['acting']),('normal','breathless'))

    def test_studio_distinguishes_alternates_from_optional_originals(self):
        manifest = self.root / 'full.json'
        initialize(manifest, 'sample', 'TR')
        rows = {row['slot']: row for row in p.rows(manifest)['rows']}
        for slot in ('WindowLocked_1', 'Alt_WindowLocked_1'):
            self.assertTrue(rows[slot]['optional'])
            self.assertEqual(rows[slot]['source'], 'WindowLocked_1')
        self.assertFalse(rows['WindowLocked_1']['alternate'])
        self.assertTrue(rows['Alt_WindowLocked_1']['alternate'])
        self.assertFalse(rows['Expr_breathless_PainGeneric_1']['alternate'])

    def test_core_acting_tags_reach_studio_without_changing_delivery(self):
        for slot, acting in {'EngineRecovered_3':'relieved', 'PanicEscape_2':'breathless',
                             'ThreatTense_1':'uneasy', 'GunJammed_1':'tense'}.items():
            self.assertEqual(studio_schema.entry(slot)['acting'], acting)
            self.assertTrue(p.guidance(slot).isascii())
            self.assertTrue(p.guidance(slot).strip())
        self.assertEqual(studio_schema.entry('Expr_angry_GunJammed_1')['acting'], 'angry')

    def test_trait_only_activities_have_independent_optional_recordings(self):
        slots = studio_schema.load()['slots']
        required = {slot for pool in studio_schema.load()['coverage']['pools'].values() for slot in pool}
        for group, trait in {'CropHarvested': 'Gardener', 'FishCaught': 'Angler', 'TraitGlasswork': 'Artisan',
                             'TraitForgeWork': 'Blacksmith Knowledge', 'TraitMasonry': 'Mason',
                             'TraitWhittling': 'Whittler'}.items():
            slot = group + '_1'
            take = slots[slot]
            self.assertTrue(take['optional'])
            self.assertFalse(take.get('alternate'))
            self.assertEqual(take['source'], slot)
            self.assertNotIn(slot, required)
            self.assertEqual(take['traitRule']['kind'], 'required')
            self.assertEqual(take['traitRule']['traits'], [trait])
            self.assertIn('In multiplayer, the server confirms', p.playback_when(take))

    def test_controlled_threat_takes_are_optional_and_filterable(self):
        full = self.root / 'trait-takes.json'
        initialize(full, 'sample', 'TR', trial=False)
        targets = {'MortalFear', 'HumanDanger', 'KeepHidden', 'ShelterThreat'}
        coverage = {slot for pool in studio_schema.load()['coverage']['pools'].values() for slot in pool}
        variants = [row for row in p.rows(full)['rows'] if row['traitControlled']]
        self.assertEqual({row['context'] for row in variants}, targets)
        self.assertEqual(len(variants), 10)
        for row in variants:
            self.assertEqual(row['acting'], 'controlled')
            self.assertEqual(row['traits'], ['Brave', 'Desensitized'])
            self.assertTrue(row['optional'])
            self.assertNotIn(row['slot'], coverage)
        self.assertEqual(next(row['text'] for row in variants if row['slot'] == 'Alt_MortalFearControlled_1'),
                         'Sakin ol. Bir çıkış bul.')

    def test_playback_rules_distinguish_requirements_preferences_and_other_routes(self):
        full = self.root / 'playback.json'
        initialize(full, 'sample', 'TR', trial=False)
        rows = {row['slot']: row for row in p.rows(full)['rows']}
        for row in rows.values():
            self.assertTrue(row['playbackWhen'].strip(), row['slot'])
            if row['traits']:
                self.assertEqual(row['traitRule']['traits'], row['traits'])
                self.assertTrue(row['traitRule']['description'].strip(), row['slot'])
        for slot, kind in {
            'Alt_MortalFearControlled_1': 'required',
            'Alt_Whisper_MortalFearControlled_1': 'required',
            'MortalFear_1': 'conditional',
            'StartleBrave_1': 'required',
            'StartleNormal_1': 'excluded',
            'Expr_frightened_GunJammed_1': 'excluded',
            'Expr_frightened_OutOfAmmo_1': 'excluded',
            'StartleCowardly_1': 'conditional',
            'TraitStudy_1': 'conditional',
            'ExhaustedCoping_1': 'conditional',
            'ReloadSteady_1': 'preferred',
            'PanicGrounding_2': 'preferred',
            'Whisper_ThreatTense_2': 'preferred',
        }.items():
            self.assertEqual(rows[slot]['traitRule']['kind'], kind, slot)
        self.assertEqual(set(rows['ExhaustedCoping_1']['traits']), {'Short of Breath', 'Out of Shape', 'Unfit'})
        self.assertIn('any survivor', rows['ExhaustedCoping_1']['traitRule']['description'])
        self.assertIn('without Brave', rows['Expr_frightened_GunJammed_1']['traitRule']['description'])
        self.assertIn('Any survivor', rows['GunJammed_1']['traitRule']['description'])
        for slot in ('MortalFear_1', 'Whisper_MortalFear_1'):
            description = rows[slot]['traitRule']['description']
            self.assertIn('controlled take first, then a short threat warning', description)
            self.assertIn('if neither is available', description)
        # A controlled read alone never imposes a survivor trait.
        self.assertEqual(rows['Alt_WindowLocked_1']['acting'], 'controlled')
        self.assertNotIn('traitRule', rows['Alt_WindowLocked_1'])

    def test_single_alternative_pack_passes_actual_core_registry(self):
        self.manifest=self.root/'full.json'
        initialize(self.manifest,'sample','EN',trial=False)
        config=p.read(self.manifest)
        schema = studio_schema.load()
        policy = schema['coverage']
        chosen = {pool[0] for pool in policy['pools'].values()}
        chosen.update(pool[0] for event, pool in config['bank']['native']['replacements'].items()
                      if event not in policy['optionalNativeEvents'])
        self.assertTrue({'Cough', 'WhisperHey', 'WhisperMegaphonePsst'} <= policy['optionalNativeEvents'].keys())
        optional_delivery = {
            slot for slot, row in schema['slots'].items()
            if row['profile'] == 'ill' or row['delivery'] == 'whisper'
        }
        self.assertTrue({'Expr_congested_AnimalTracks_1', 'Whisper_MortalFear_1'} <= optional_delivery)
        self.assertTrue(all(schema['slots'][slot]['optional'] for slot in optional_delivery))
        self.assertTrue(optional_delivery.isdisjoint(chosen))
        alcohol = {
            slot for slot, row in schema['slots'].items()
            if row['profile'] == 'drunk' or row['group'] in ('Drunk', 'ReliefSobriety', 'NativeDrunkHic')
        }
        self.assertTrue({'Drunk_1', 'ReliefSobriety_1', 'NativeDrunkHic_1', 'Expr_slurred_Endurance_1'} <= alcohol)
        self.assertTrue(all(schema['slots'][slot]['optional'] for slot in alcohol))
        self.assertTrue(alcohol.isdisjoint(chosen))
        self.assertLess(len(chosen),len(p.slots(config)))
        for slot in chosen:
            clip=p.slots(config)[slot];clip['duration']=1000
            path=p.contained(self.root,config['assets'][clip['sound']]['source'])
            path.parent.mkdir(exist_ok=True);path.write_bytes(b'fixture bytes'*100)
        p.write(self.manifest,config)
        for slot in chosen:
            p.edit(self.manifest,slot,config['bank']['lines'][slot],'','approved')
        self.assertEqual(p.rows(self.manifest)['buildCoverage']['missing'],[])
        before=self.manifest.read_bytes()
        # Registry/build test only; no generated voices or claim of audio playback.
        with patch('prepare_voice_pack.measure'):
            result=p.package(self.manifest,self.root/'pack','unused',TOOLS.parents[1])
        self.assertEqual(result['recordings'],len(chosen))
        self.assertEqual(self.manifest.read_bytes(),before)
        lost=next(slot for slot in chosen if slot.startswith('AmmoCount_'))
        p.edit(self.manifest,lost,config['bank']['lines'][lost],'','redo')
        with self.assertRaisesRegex(ValueError,'situations or native'):
            p.package(self.manifest,self.root/'bad','unused',TOOLS.parents[1])

    def test_missing_native_mapping_is_a_gap_in_readiness_and_the_finished_pack(self):
        manifest = self.root / 'full.json'
        initialize(manifest, 'sample', 'EN')
        config = p.read(manifest)
        bank = config['bank']
        bank['coverage'] = 'situations-v1'
        native = bank['native']['replacements']
        event = next(event for event in native if event not in studio_schema.load()['coverage']['optionalNativeEvents'])
        del native[event]
        coverage = p.coverage(config, self.root, set(p.slots(config)))
        self.assertEqual(coverage['missing'], ['Native / ' + event])
        with self.assertRaisesRegex(ValueError, 'Native / ' + event):
            validate(config, self.root)

    def test_bulk_review_is_scoped_and_atomic_and_keeps_files(self):
        first=self.supply();second=self.supply('ExploreMore_1')
        checksums=[p.digest(first),p.digest(second)]
        p.review_many(self.manifest,['Explore_2'],'approved')
        config=p.read(self.manifest)
        self.assertEqual(p.status(config,'Explore_2',self.root),'approved')
        self.assertEqual(p.status(config,'ExploreMore_1',self.root),'pending')
        before=p.digest(self.manifest)
        for selection in (['Explore_2','ExploreMore_2'],['Unknown'],['Explore_2','Explore_2']):
            with self.assertRaises(ValueError):p.review_many(self.manifest,selection,'redo')
            self.assertEqual(p.digest(self.manifest),before)
        p.review_many(self.manifest,['Explore_2','ExploreMore_1'],'redo')
        self.assertEqual([p.digest(first),p.digest(second)],checksums)
        self.assertEqual(p.status(p.read(self.manifest),'Explore_2',self.root),'redo')

    def test_bulk_undo_preserves_unrelated_changes_and_rejects_changed_takes(self):
        first=self.supply();self.supply('ExploreMore_1')
        checksum=p.digest(first)
        p.review_many(self.manifest,['Explore_2'],'approved')
        p.edit(self.manifest,'ExploreMore_1','BaÅŸka bir replik.','','redo')
        self.assertTrue(p.rows(self.manifest)['canUndoReview'])
        p.undo_review(self.manifest)
        config=p.read(self.manifest)
        self.assertEqual(p.status(config,'Explore_2',self.root),'pending')
        self.assertEqual(p.status(config,'ExploreMore_1',self.root),'redo')
        self.assertFalse(p.rows(self.manifest)['canUndoReview'])
        self.assertEqual(p.digest(first),checksum)
        p.review_many(self.manifest,['Explore_2'],'approved')
        p.edit(self.manifest,'Explore_2','Yeni replik.','','pending')
        before=p.digest(self.manifest)
        with self.assertRaisesRegex(ValueError,'newer work'):p.undo_review(self.manifest)
        self.assertEqual(p.digest(self.manifest),before)

    def test_unicode_caption_round_trip_preserves_slot(self):
        self.supply()
        text='GÃ¶z gÃ¶zÃ¼ gÃ¶rmÃ¼yor. Ø§Ù„Ø¹Ø±Ø¨ÙŠØ© æ—¥æœ¬èªž à¨ªà©°à¨œà¨¾à¨¬à©€ ðŸ«¥'
        p.edit(self.manifest,'Explore_2',text,'','pending')
        row=next(r for r in p.rows(self.manifest)['rows'] if r['slot']=='Explore_2')
        self.assertEqual(row['text'],text)
        self.assertIn('Explore_2',p.slots(p.read(self.manifest)))

    def test_launcher_keeps_existing_project_and_checks_prerequisites(self):
        from launch_studio import workspace,prerequisites
        path,fresh=workspace(self.root/'launcher')
        self.assertTrue(fresh)
        before=p.digest(path)
        self.assertEqual(workspace(self.root/'launcher'),(path,False))
        self.assertEqual(p.digest(path),before)
        with patch('launch_studio.shutil.which',return_value=None):
            with self.assertRaisesRegex(ValueError,'FFmpeg is required'):prerequisites()
        with patch('launch_studio.subprocess.run') as run:
            run.return_value.returncode=0
            self.assertEqual(prerequisites('chosen.exe'),'chosen.exe')
            self.assertEqual(run.call_args.args[0],['chosen.exe','-version'])

    def test_additional_language_scripts_initialize(self):
        for code in ('ACE','CRH_CYRL','SAT_OLCK','BER_TFNG','PA_ARAB','HU','MK'):
            target=self.root/code/'project.json'
            initialize(target,'test_voice',code,trial=True)
            self.assertEqual(p.rows(target)['language'],code)

    def test_caption_and_profile_limits(self):
        from recording_limits import steam_profile, MAX_CAPTION
        self.supply()
        p.edit(self.manifest,'Explore_2','x'*MAX_CAPTION,'','pending')
        before=p.digest(self.manifest)
        with self.assertRaises(ValueError):p.edit(self.manifest,'Explore_2','x'*(MAX_CAPTION+1),'','pending')
        self.assertEqual(p.digest(self.manifest),before)
        for value in ('','https://steamcommunity.com/id/ravenwits','https://steamcommunity.com/profiles/76561198000000000/'):
            self.assertEqual(steam_profile(value),value)
        for value in ('https://steamcommunity.com.evil.test/id/a','https://user@steamcommunity.com/id/a','javascript:alert(1)','https://steamcommunity.com/id/a?x=1'):
            with self.assertRaises(ValueError):steam_profile(value)

    def test_trial_promotion_preserves_caption_recording_and_review(self):
        path = self.supply()
        self.approve()
        before = p.read(self.manifest)
        self.assertEqual(len(p.slots(before)), 18)
        checksum = p.digest(path)
        preview = p.refresh(self.manifest)
        self.assertGreater(len(preview['added']), 1000)
        self.assertEqual(p.read(self.manifest), before)
        p.refresh(self.manifest, True)
        config = p.read(self.manifest)
        self.assertFalse(config.get('trial'))
        self.assertEqual(config['bank']['lines']['Explore_2'], 'Buraya daha bakmadÄ±m.')
        self.assertEqual(p.digest(path), checksum)
        self.assertEqual(p.status(config, 'Explore_2', self.root), 'approved')
        self.assertTrue(self.manifest.with_suffix('.before-update.json').is_file())
        self.assertEqual(p.refresh(self.manifest), dict(added=[], removed=[], changed=[]))

    def test_changed_reference_requires_new_review_but_keeps_take(self):
        self.supply(); self.approve(); p.refresh(self.manifest, True)
        config = p.read(self.manifest)
        config['authoring']['references']['Explore_2'] = 'Old meaning'
        p.write(self.manifest, config)
        diff = p.refresh(self.manifest, True)
        self.assertIn('Explore_2', diff['changed'])
        self.assertEqual(p.status(p.read(self.manifest), 'Explore_2', self.root), 'pending')

    def test_external_audio_change_invalidates_approval(self):
        path = self.supply(); self.approve()
        path.write_bytes(b'replaced recording')
        self.assertEqual(p.status(p.read(self.manifest), 'Explore_2', self.root), 'pending')

    def test_jobs_skip_existing_unreviewed_and_approved_takes(self):
        self.supply()
        self.assertEqual(p.jobs(self.manifest)['recordings'], 17)
        p.edit(self.manifest, 'Explore_2', 'A new line.', 'Speak gently.', 'redo')
        queue = p.jobs(self.manifest, .1)
        self.assertEqual(queue['recordings'], 18)
        self.assertGreater(queue['estimatedUnits'], 0)
        self.approve()
        self.assertEqual(p.jobs(self.manifest)['recordings'], 17)

    def test_no_approval_without_recording_and_no_path_escape(self):
        with self.assertRaises(ValueError): self.approve()
        for path in ('../secret.mp3', str(self.root.parent/'secret.mp3')):
            with self.assertRaises(ValueError): p.contained(self.root, path)

    def test_spoken_breathless_lines_are_not_nonverbal_breaths(self):
        self.assertEqual(p.category('NativeBreath_1'),'Breath')
        self.assertEqual(studio_schema.entry('NativeCall_1')['group'],'NativeCall')
        self.assertIn('ShoutHey',studio_schema.entry('NativeCall_1')['nativeEvents'])
        self.assertEqual(p.category('ReloadBreathless_1'),'Dialogue')
        self.assertEqual(p.category('Expr_breathless_Thirst_1'),'Dialogue')
        self.assertIn('Speak between short breaths',p.guidance('Expr_breathless_Thirst_1'))
        self.assertEqual(p.category('NativeCough_1'),'Nonverbal')

    def test_batch_import_matches_slots_and_resumes_without_overwriting(self):
        folder = self.root/'takes'; folder.mkdir()
        (folder/'Explore_2.wav').write_bytes(b'first')
        (folder/'sample_ExploreMore_1.mp3').write_bytes(b'second')
        (folder/'unknown.mp3').write_bytes(b'unknown')
        self.supply('Explore_2')
        with patch('voice_project.import_audio', side_effect=lambda manifest,slot,source,ffmpeg:self.supply(slot)) as importer:
            result=p.import_folder(self.manifest,folder,'ffmpeg')
            self.assertEqual(result['imported'],['ExploreMore_1'])
            self.assertEqual(result['ignored'],['unknown.mp3'])
            self.assertEqual(p.import_folder(self.manifest,folder,'ffmpeg')['imported'],[])
            self.assertEqual(importer.call_count,1)

    def test_second_worker_cannot_reserve_the_same_budget(self):
        self.manifest.with_suffix('.worker.lock').write_text('already running')
        with patch('voice_project.subprocess.run') as worker:
            with self.assertRaisesRegex(ValueError,'worker owns'):
                p.run_jobs(self.manifest,['record'],'ffmpeg',1000,.1)
            worker.assert_not_called()
        self.assertFalse(self.manifest.with_suffix('.work.json').exists())

    def test_language_template_and_reuse_have_no_voice_identity_leak(self):
        config = p.read(self.manifest)
        self.assertEqual(config['bank']['lines']['Explore_2'], 'Burada işe yarar bir şey olabilir.')
        target = self.root / 'another.json'
        initialize(target, 'another', 'TR', True, True, self.manifest)
        other = p.read(target)
        self.assertTrue(all(k.startswith('another_') for k in other['bank']['data']['clips']))
        self.assertEqual(other['bank']['voices'][0]['base'], 'VoiceFemale')
        with self.assertRaises(ValueError): initialize(self.root/'bad.json', 'wrong', 'EN', texts=self.manifest)

    def test_interrupted_worker_reserves_budget_and_never_retries_automatically(self):
        job = p.jobs(self.manifest, .1)['jobs'][0]
        budget = job['estimatedUnits']
        with patch('voice_project.subprocess.run', side_effect=RuntimeError('private worker output')) as worker:
            with self.assertRaisesRegex(ValueError, 'reservation remains'):
                p.run_jobs(self.manifest, ['record'], 'ffmpeg', budget, .1, 1)
            self.assertEqual(worker.call_count, 1)
            with self.assertRaisesRegex(ValueError, 'unresolved'):
                p.run_jobs(self.manifest, ['record'], 'ffmpeg', budget, .1, 1)
            self.assertEqual(worker.call_count, 1)
        ledger = p.read(self.manifest.with_suffix('.work.json'))
        self.assertEqual(ledger['reservedUnits'], budget)
        p.resolve_job(self.manifest, job['id'])
        with patch('voice_project.subprocess.run') as worker:
            self.assertEqual(p.run_jobs(self.manifest, ['record'], 'ffmpeg', budget, .1)['completed'], 0)
            worker.assert_not_called()

    def test_worker_resume_skips_imported_jobs(self):
        def imported(manifest, slot, output, ffmpeg): self.supply(slot)
        with patch('voice_project.subprocess.run'), patch('voice_project.import_audio', side_effect=imported):
            first = p.run_jobs(self.manifest, ['record'], 'ffmpeg', 10000, .1, 2)
            second = p.run_jobs(self.manifest, ['record'], 'ffmpeg', 10000, .1, 2)
        self.assertEqual(first['completed'], 2)
        self.assertEqual(second['remaining'], 14)
        entries = p.read(self.manifest.with_suffix('.work.json'))['entries']
        self.assertEqual(len({e['id'] for e in entries}), 4)

    def test_slow_elevenlabs_read_does_not_block_local_studio(self):
        from concurrent.futures import ThreadPoolExecutor
        started, release = threading.Event(), threading.Event()

        def slow_credits(_key):
            started.set()
            if not release.wait(5):
                raise ValueError('Timed out waiting to release the fixture')
            return {'used': 2, 'limit': 100, 'remaining': 98}

        server, _ = make_server(self.manifest, 'ffmpeg', TOOLS.parents[1])
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()

        def get(path, headers):
            conn = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=3)
            try:
                conn.request('GET', path, headers=headers)
                response = conn.getresponse()
                return response.status, json.loads(response.read())
            finally:
                conn.close()

        try:
            _, session = get('/session', {'X-Voice-Request': 'local-editor'})
            auth = {'X-Voice-Token': session['token']}
            with patch('studio_elevenlabs.credits', side_effect=slow_credits), ThreadPoolExecutor() as pool:
                balance = pool.submit(get, '/elevenlabs/credits', auth)
                try:
                    self.assertTrue(started.wait(2))
                    status, project = get('/project', auth)
                    self.assertEqual(status, 200)
                    self.assertEqual(project['voice'], 'sample')
                finally:
                    release.set()
                self.assertEqual(balance.result()[1]['remaining'], 98)
        finally:
            server.shutdown()
            server.server_close()
            worker.join()

    def test_generate_and_retry_send_game_setting_and_selected_recording_brief(self):
        # Inspect the actual provider payload after a request through the Studio route.
        for language, slot, model in [('TR', 'StartleBrave_1', 'gemini-3.5-flash-lite'),
                                      ('EN', 'Thirst_1', 'gemini-3.5-flash')]:
            with self.subTest(language=language):
                manifest = self.root / language / 'project.json'
                manifest.parent.mkdir()
                initialize(manifest, 'sample', language)
                with patch('studio_dialogue.configured_key', return_value='fixture'):
                    server, _ = make_server(manifest, 'ffmpeg', TOOLS.parents[1])
                worker = threading.Thread(target=server.serve_forever, daemon=True)
                worker.start()
                conn = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=10)
                try:
                    conn.request('GET', '/session', headers={'X-Voice-Request': 'local-editor'})
                    token = json.loads(conn.getresponse().read())['token']
                    conn.request('GET', '/project', headers={'X-Voice-Token': token})
                    state = json.loads(conn.getresponse().read())
                    row = next(r for r in state['rows'] if r['slot'] == slot)
                    headers = {'X-Voice-Token': token, 'X-Revision': state['revision']}
                    self.assertEqual(state['dialogueModel'], 'gemini-3.5-flash-lite')
                    self.assertIn(model, state['dialogueModels'])
                    if model != state['dialogueModel']:
                        with patch('studio_dialogue.validate_key') as validate:
                            conn.request('POST', '/dialogue/connect', body=json.dumps({'model': model}), headers=headers)
                            response = conn.getresponse()
                            self.assertEqual(json.loads(response.read())['result']['model'], model)
                            validate.assert_called_once_with('fixture', model)
                        from studio_dialogue import configured_model
                        self.assertEqual(configured_model(manifest.parent / '.env.local'), model)
                    body = {'slot': slot, 'project': state['projectKey'], 'dialogue_count': 1}
                    for draft in ('First fixture line.', 'Second fixture line.'):
                        answer = {'content': {'parts': [{'text': json.dumps({'options': [draft]})}]}, 'finishReason': 'STOP'}
                        with patch('studio_dialogue.provider_request', return_value={'candidates': [answer]}) as send:
                            conn.request('POST', '/dialogue/suggest', body=json.dumps(body), headers=headers)
                            response = conn.getresponse()
                            result = json.loads(response.read())
                            self.assertEqual(response.status, 200, result)
                            self.assertEqual(result['result']['options'], [draft])
                            _, payload = send.call_args.args
                            self.assertEqual(send.call_args.kwargs['model'], model)
                        instruction = payload['systemInstruction']['parts'][0]['text']
                        self.assertIn('Project Zomboid', instruction)
                        self.assertIn('zombie-apocalypse survival game', instruction)
                        scene = json.loads(payload['contents'][0]['parts'][0]['text'])
                        self.assertEqual(scene['locale'], language)
                        for prompt_field, row_field in [('situation', 'context'), ('whenItPlays', 'playbackWhen'),
                                                        ('traitRule', 'traitRule'), ('recordingGuidance', 'guidance'),
                                                        ('recommendedCues', 'elevenLabsTags'), ('profanity', 'profanity'),
                                                        ('delivery', 'delivery'), ('acting', 'acting')]:
                            self.assertEqual(scene[prompt_field], row.get(row_field))
                        self.assertEqual('reaction_window' in scene, slot == 'StartleBrave_1')
                        self.assertEqual(scene.get('previous_drafts'), body.get('previous_drafts'))
                        body['previous_drafts'] = [draft]
                finally:
                    conn.close()
                    server.shutdown()
                    server.server_close()
                    worker.join()

    def test_gemini_connect_returns_provider_errors_as_json(self):
        from studio_dialogue import QuotaExceeded
        server, _ = make_server(self.manifest, 'ffmpeg', TOOLS.parents[1])
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=5)
        try:
            connection.request('GET', '/session', headers={'X-Voice-Request': 'local-editor'})
            token = json.loads(connection.getresponse().read())['token']
            for error, status in ((ValueError('Invalid API key'), 400), (QuotaExceeded('Quota reached'), 429)):
                with patch('studio_dialogue.validate_key', side_effect=error):
                    connection.request('POST', '/dialogue/connect', body=json.dumps({'key': 'fixture'}),
                                       headers={'X-Voice-Token': token, 'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    self.assertEqual(response.status, status)
                    self.assertEqual(json.loads(response.read()), {'error': str(error)})
        finally:
            connection.close()
            server.shutdown()
            server.server_close()
            worker.join()

    def test_elevenlabs_retries_reads_but_never_retries_paid_generation(self):
        import studio_elevenlabs as e
        offline = e.ProviderUnavailable('timeout')
        with patch('studio_elevenlabs.read_provider_response',
                   side_effect=[offline, {'character_count': 7, 'character_limit': 100}]) as read:
            self.assertEqual(e.credits('test-key')['remaining'], 93)
            self.assertEqual(read.call_count, 2)
        with patch('studio_elevenlabs.read_provider_response', side_effect=offline) as read:
            with self.assertRaises(e.ProviderUnavailable):
                e.provider_request('test-key', '/v1/text-to-speech/test-voice', {'text': 'Test'})
            read.assert_called_once()

    def test_elevenlabs_preview_is_local_until_accepted(self):
        old = self.supply()
        before = old.read_bytes()
        audio_file = self.root / 'preview.mp3'
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=330:duration=0.2',
                        str(audio_file)], check=True)
        env_file = self.manifest.parent / '.env.local'
        env_file.write_text('KEEP_THIS=value\n', encoding='utf-8')
        secret = 'test-elevenlabs-key-123'
        mock_voice = 'own-generated-voice'
        provider_calls = []
        caption = 'Buraya bir bakalım.'
        script = '[low voice] Buraya bir [speaks with a dry rasp] bakalım. [exhales]'

        def provider(key, path, payload=None):
            self.assertEqual(key, secret)
            provider_calls.append(path)
            if path.startswith('/v2/voices?'):
                return {'voices': [{'voice_id': mock_voice, 'category': 'generated', 'name': 'My voice',
                                    'labels': {'language': 'tr-TR'},
                                    'verified_languages': [{'language': 'en'}]}]}
            if path == '/v1/models':
                return [{'model_id': 'eleven_v4', 'model_rates': {'character_cost_multiplier': 1.5}}]
            if path.startswith('/v1/shared-voices?'):
                self.assertIn('language=tr', path)
                return {'voices': [
                    {'voice_id': 'public-tr', 'public_owner_id': 'owner-id', 'name': 'Turkish voice', 'language': 'tr'},
                    {'voice_id': 'primary-en', 'public_owner_id': 'owner-id', 'name': 'English voice', 'language': 'en',
                     'verified_languages': [{'language': 'tr'}]},
                ], 'has_more': True}
            if path == '/v1/voices/add/owner-id/public-tr':
                self.assertEqual(payload, {'new_name': 'Turkish voice'})
                return {'voice_id': mock_voice}
            if path == '/v1/user/subscription':
                return {'character_count': 120, 'character_limit': 500}
            self.assertIn('/v1/text-to-speech/' + mock_voice, path)
            self.assertEqual(payload['model_id'], 'eleven_v4')
            if payload['text'] == '[inhales] Hah… [exhales softly] Hah…':
                return audio_file.read_bytes(), 30, 'native-voice-test-id'
            self.assertEqual(payload['language_code'], 'tr')
            self.assertEqual(payload['text'], script)
            return audio_file.read_bytes(), 17, 'provider-test-id'

        server, _ = make_server(self.manifest, 'ffmpeg', TOOLS.parents[1])
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)

        def call(path, data=None, auth=True, raw=False):
            headers = {'X-Voice-Request': 'local-editor'}
            if auth:
                headers['X-Voice-Token'] = token
            if data is not None:
                headers['X-Revision'] = p.digest(self.manifest)
            connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=8)
            try:
                connection.request('GET' if data is None else 'POST', path,
                                   None if data is None else json.dumps(data), headers)
                response = connection.getresponse()
                body = response.read()
                self.assertNotIn(secret.encode(), body)
                return response.status, body if raw else json.loads(body)
            finally:
                connection.close()

        token = call('/session', auth=False)[1]['token']
        project_key = {'project': 'current'}
        slot = {**project_key, 'slot': 'Explore_2'}
        with patch('studio_elevenlabs.provider_request', side_effect=provider):
            self.assertEqual(call('/elevenlabs/credits', auth=False)[0], 403)
            status, response = call('/elevenlabs/connect', {**project_key, 'key': secret})
            self.assertEqual(status, 200)
            self.assertEqual(response['result']['voices'][0]['id'], mock_voice)
            self.assertEqual(response['result']['voices'][0]['languages'], ['EN', 'TR'])
            from studio_elevenlabs import StudioSpeech
            self.assertEqual(StudioSpeech(env_file).key, secret)
            self.assertIn('KEEP_THIS=value', env_file.read_text())
            self.assertEqual(call('/.env.local')[0], 404)
            self.assertEqual(call('/elevenlabs/credits')[1]['remaining'], 380)
            status, library = call('/elevenlabs/library')
            self.assertEqual(status, 200)
            self.assertEqual([voice['id'] for voice in library['voices']], ['public-tr'])
            self.assertEqual(library['next'], '1')
            self.assertEqual(call('/elevenlabs/settings', {**project_key, 'voice': 'public-tr',
                                                          'owner': 'owner-id', 'name': 'Turkish voice'})[1]['result']['voice'], mock_voice)
            self.assertEqual(call('/elevenlabs/generate', {**slot, 'project': 'other'})[0], 409)
            self.assertEqual(call('/elevenlabs/generate', {**slot, 'tags': ['laughs']})[0], 400)
            self.assertFalse(any(path.startswith('/v1/text-to-speech/') for path in provider_calls))
            status, description = call('/elevenlabs/describe', slot)
            self.assertEqual(status, 200)
            description = description['result']
            self.assertEqual(description['estimatedCredits'], (3 * description['characterCount'] + 1) // 2)
            edit = {'slot': slot['slot'], 'direction': '', 'state': 'approved'}
            for invalid in ('[broken', '[[whispers]] test', '[ ] test', '［whispers］ test'):
                self.assertEqual(call('/save', {**edit, 'text': invalid})[0], 400)
            status, result = call('/save', {**edit, 'text': script})
            self.assertEqual(status, 200, result)
            self.assertEqual(result['result']['row']['text'], caption)
            self.assertEqual(result['result']['row']['speechScript'], script)
            self.assertEqual(call('/elevenlabs/describe', slot)[1]['result']['prompt'], script)
            identifier = call('/elevenlabs/generate', slot)[1]['result']['id']
            for _ in range(30):
                if call('/elevenlabs/preview?id=' + identifier)[1].get('ready'):
                    break
                time.sleep(0.02)
            self.assertEqual(call('/audio/elevenlabs?id=' + identifier, raw=True)[1], audio_file.read_bytes())
            self.assertEqual(old.read_bytes(), before)
            self.assertEqual(call('/elevenlabs/accept', {**slot, 'id': identifier, 'slot': 'ExploreMore_1'})[0], 400)
            self.assertEqual(call('/elevenlabs/accept', {**slot, 'id': identifier})[0], 200)
            self.assertEqual(call('/elevenlabs/accept', {**slot, 'id': identifier})[0], 400)
            self.assertEqual(p.status(p.read(self.manifest), 'Explore_2', self.root), 'pending')
            self.assertEqual(p.read(self.manifest)['bank']['lines']['Explore_2'], caption)
            backup, = (self.root / 'elevenlabs-backups' / 'Explore_2').glob('*.mp3')
            self.assertEqual(backup.read_bytes(), before)
            _, history = call('/elevenlabs/history')
            self.assertEqual(history[0]['requestId'], 'provider-test-id')
            self.assertEqual(history[0]['cost'], 17)
            self.assertEqual(history[0]['status'], 'generated')
            self.assertEqual(StudioSpeech(env_file).history(self.manifest), history)
            other = self.root / 'elevenlabs-backups' / 'ExploreMore_1' / ('a' * 32 + '.mp3')
            other.parent.mkdir(parents=True)
            other.write_bytes(before)
            p.review_many(self.manifest, ['Explore_2'], 'approved')
            self.assertFalse(backup.exists())
            self.assertTrue(other.is_file())
            active = old.read_bytes()
            p.import_audio(self.manifest, 'Explore_2', audio_file, 'ffmpeg', keep_previous=True)
            backup, = (self.root / 'elevenlabs-backups' / 'Explore_2').glob('*.mp3')
            self.assertEqual(backup.read_bytes(), active)
            self.approve()
            self.assertFalse(backup.exists())
            self.assertNotEqual(old.read_bytes(), before)
            self.assertNotIn(secret.encode(), self.manifest.read_bytes())
            self.assertEqual(sum('/v1/text-to-speech/' in path for path in provider_calls), 1)
            native = {**project_key, 'slot': 'NativeBreath_1'}
            status, description = call('/elevenlabs/describe', native)
            self.assertEqual(status, 200, description)
            self.assertEqual(description['result']['prompt'], '[takes two short recovery breaths] Hah… hah…')
            for invalid in ('', '[]', '[inhales]', '[inhales] ...', '[inhales] <break/> Ah!', ['[inhales]']):
                self.assertEqual(call('/elevenlabs/generate', {**native, 'nativeScript': invalid})[0], 400)
            self.assertEqual(call('/elevenlabs/generate', {**slot, 'nativeScript': '[inhales]'})[0], 400)
            status, generated = call('/elevenlabs/generate', {**native, 'nativeScript': ' [inhales] Hah… [exhales softly] Hah… '})
            self.assertEqual(status, 200, generated)
            identifier = generated['result']['id']
            for _ in range(30):
                status, result = call('/elevenlabs/preview?id=' + identifier)
                self.assertEqual(status, 200, result)
                if result.get('ready'):
                    break
                time.sleep(0.02)
            self.assertEqual(result, {'ready': True, 'cost': 30})
            self.assertEqual(call('/audio/elevenlabs?id=' + identifier, raw=True)[1], audio_file.read_bytes())
            self.assertEqual(call('/elevenlabs/history')[1][0]['requestId'], 'native-voice-test-id')
            self.assertEqual(call('/elevenlabs/accept', {**native, 'id': identifier})[0], 200)
            self.assertEqual(p.status(p.read(self.manifest), 'NativeBreath_1', self.root), 'pending')
            self.assertEqual(call('/elevenlabs/describe', native)[1]['result']['prompt'],
                             '[takes two short recovery breaths] Hah… hah…')

    def test_elevenlabs_prompt_obeys_core_delivery_and_type(self):
        from studio_elevenlabs import prompt
        config = {'bank': {'language': 'TR', 'lines': {
            'Whisper_CriticalFading_2': 'Nefes alamıyorum.',
            'InjuryAcute_1': 'Ah!',
            'Pain_1': 'Canım acıyor.',
            'KillCount_1': 'Otuz bir oldu.',
            'NativeBreath_1': 'Breathing',
        }}}
        self.assertEqual(prompt(config, 'Whisper_CriticalFading_2')['text'], '[whispers, very weak and fading] Nefes alamıyorum.')
        self.assertEqual(prompt(config, 'InjuryAcute_1')['text'], '[in sudden pain] Ah!')
        self.assertIn('dry with a faint smile', prompt(config, 'KillCount_1')['text'])
        self.assertEqual(prompt(config, 'Pain_1')['text'], '[restrained pain, breath catches once] Canım acıyor.')
        self.assertIn('strain', p.core_guidance('Pain_1', 'TR'))
        import recording_guidance
        _, whisper = recording_guidance.performance('Whisper_StartleCowardly_2', 'TR')
        self.assertEqual(whisper, ['[whispers, breath catches, frightened and unsteady]'])
        _, relief = recording_guidance.performance('Expr_congested_ReliefAnger_1', 'TR')
        self.assertEqual(relief, ['[speaks as if their nose is pinched shut, with an audible mouth breath, starts tight, anger eases]'])
        _, cold = recording_guidance.performance('Expr_congested_HasACold_1', 'TR')
        self.assertEqual(cold, ['[sniffs]', '[speaks as if their nose is pinched shut]'])
        self.assertIn('otuz bir', p.core_guidance('KillCount_1', 'TR'))
        self.assertIn('after a failed attempt', p.core_guidance('EngineRecovered_1', 'EN'))
        self.assertEqual(studio_schema.entry('Whisper_CarAlarm_1')['delivery'], 'whisper')
        for slot, definition in studio_schema.load()['slots'].items():
            if definition['category'] != 'Dialogue':
                payload = prompt(config, slot)
                self.assertRegex(payload['text'], r'^\[[^\[\]]+\] .+')
                self.assertTrue(any(char.isalpha() for char in p.strip_audio_tags(payload['text'])))
                self.assertEqual(payload['model_id'], 'eleven_v4')
                self.assertNotIn('language_code', payload)
        config['authoring'] = {'elevenLabsScripts': {'InjuryAcute_1': 'Ah! [sharp breath]'}}
        self.assertEqual(prompt(config, 'InjuryAcute_1')['text'], 'Ah! [sharp breath]')
        config['authoring']['elevenLabsScripts']['InjuryAcute_1'] = 'Ah! [in sudden pain]'
        self.assertEqual(prompt(config, 'InjuryAcute_1')['text'], 'Ah! [in sudden pain]')
        config['authoring']['elevenLabsScripts'].clear()
        self.assertEqual(prompt(config, 'InjuryAcute_1')['text'], '[in sudden pain] Ah!')
        config['bank']['lines']['InjuryAcute_1'] = 'Ah! [in sudden pain]'
        self.assertEqual(p.recording_text(config, 'InjuryAcute_1'), ('Ah!', 'Ah! [in sudden pain]'))
        self.assertEqual(prompt(config, 'InjuryAcute_1')['text'], 'Ah! [in sudden pain]')
        config['bank']['lines']['InjuryAcute_1'] = '［laughs］ Ah!'
        with self.assertRaisesRegex(ValueError, 'audio tags'):
            prompt(config, 'InjuryAcute_1')

    def test_studio_and_elevenlabs_use_the_same_core_direction(self):
        from studio_elevenlabs import prompt
        config = p.read(self.manifest)
        config['authoring']['recordingGuidance'] = {'Explore_2': 'Invented direction from a legacy project.'}
        p.write(self.manifest, config)
        rows = {row['slot']: row for row in p.rows(self.manifest)['rows']}
        slot = 'Explore_2'
        jobs = {job['slot']: job for job in p.jobs(self.manifest)['jobs']}
        self.assertEqual(rows[slot]['guidance'], jobs[slot]['direction'])
        self.assertNotEqual(rows[slot]['direction'], rows[slot]['guidance'])
        for row in rows.values():
            with self.subTest(slot=row['slot']):
                self.assertTrue(row['guidance'])
                self.assertLessEqual(len(row['elevenLabsTags']), 1)
                if row['category'] == 'Dialogue' and row['text']:
                    self.assertEqual(prompt(config, row['slot'])['text'], ' '.join([*row['elevenLabsTags'], row['text']]))
                elif row['category'] != 'Dialogue':
                    self.assertEqual(row['elevenLabsTags'], [])

    def test_editor_does_not_retry_response_after_client_disconnect(self):
        server, _ = make_server(self.manifest, 'ffmpeg', TOOLS.parents[1])
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)

        connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=5)
        try:
            connection.request('GET', '/session', headers={'X-Voice-Request': 'local-editor'})
            token = json.loads(connection.getresponse().read())['token']
        finally:
            connection.close()
        headers = {'X-Voice-Token': token}
        with patch.object(server.RequestHandlerClass, 'end_headers', side_effect=BrokenPipeError) as send:
            connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=5)
            try:
                connection.request('GET', '/schema', headers=headers)
                with self.assertRaises(http.client.RemoteDisconnected):
                    connection.getresponse()
            finally:
                connection.close()
            send.assert_called_once()

        connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=5)
        try:
            connection.request('GET', '/project', headers=headers)
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(len(json.loads(response.read())['rows']), 18)
        finally:
            connection.close()

    def test_editor_rejects_cross_origin_missing_token_and_stale_writes(self):
        server, url = make_server(self.manifest, 'ffmpeg', TOOLS.parents[1])
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        self.addCleanup(server.server_close); self.addCleanup(server.shutdown)
        def request(method, path, headers, data=None):
            connection = http.client.HTTPConnection('127.0.0.1', server.server_port)
            connection.request(method, path, json.dumps(data) if data else None, headers)
            response = connection.getresponse(); result = response.status, response.read(); connection.close()
            return result
        self.assertEqual(request('GET', '/project', {})[0], 403)
        self.assertNotIn('#', url)
        self.assertEqual(request('GET', '/session', {})[0], 403)
        self.assertEqual(request('GET', '/session', {'X-Voice-Request':'local-editor','Origin':'https://untrusted.example'})[0], 403)
        self.assertEqual(request('GET', '/session', {'X-Voice-Request':'local-editor','Host':'evil.example'})[0], 403)
        code, session = request('GET', '/session', {'X-Voice-Request':'local-editor'})
        self.assertEqual(code, 200)
        token = json.loads(session)['token']
        code, html = request('GET', '/', {})
        self.assertEqual(code, 200); self.assertIn(token.encode(), html)
        self.assertNotIn(b'__VOICE_SESSION__', html)
        self.assertEqual(request('GET', '/project', {'X-Voice-Token':'old-session'})[0], 403)
        headers = {'X-Voice-Token': token, 'Origin': 'https://untrusted.example'}
        self.assertEqual(request('GET', '/project', headers)[0], 403)
        headers.pop('Origin')
        code, body = request('GET', '/project', headers)
        self.assertEqual(code, 200); self.assertEqual(len(json.loads(body)['rows']), 18)
        self.assertEqual(request('POST', '/update', headers, {'apply':True})[0], 409)
        headers['X-Revision'] = p.digest(self.manifest)
        self.assertEqual(request('POST', '/metadata', headers, dict(name='Test voice',author='Me',description='My own recordings.'))[0], 200)
        self.assertEqual(p.read(self.manifest)['name'], 'Test voice')
        self.assertEqual(p.read(self.manifest)['bank']['voices'][0]['name'], 'Test voice')
        headers['X-Revision']=p.digest(self.manifest)
        for invalid in ['1.0', 'v1.0.0', '1.0.0-beta']:
            self.assertEqual(request('POST','/metadata',headers,dict(name='Test',author='Me',description='Test',packVersion=invalid))[0],400)
        for invalid in ['https://example.com/id/me', 'https://steamcommunity.com.evil.test/id/me', 'https://steamcommunity.com/app/1']:
            self.assertEqual(request('POST','/metadata',headers,dict(name='Test',author='Me',description='Test',steamProfile=invalid))[0],400)
        for data in [{}, {'rightsConfirmed':False}, {'rightsConfirmed':'true'}]:
            code, body = request('POST','/package',headers,data)
            self.assertEqual(code,400)
            if data: self.assertIn(b'permission to distribute',body)
        self.assertEqual(request('POST','/metadata',headers,dict(name='Test',author='Me',description='Test',rules={}))[0],400)
        self.assertEqual(request('GET','/studio/assets/../../voice-template-v1.json',{})[0],404)
        self.assertEqual(request('GET','/schema',headers)[0],200)
        code, body = request('GET','/recording-list',headers)
        recording_list = json.loads(body)
        self.assertEqual(code, 200)
        self.assertEqual(len(recording_list['recordings']), 18)
        self.assertNotIn('revision', recording_list)
        self.assertTrue(all(row['filename'] == row['slot'] + '.mp3' for row in recording_list['recordings']))
        self.assertEqual(request('POST','/create',headers,dict(voice='../escape',language='EN'))[0],400)
        self.assertEqual(request('POST','/create',headers,dict(voice='another',name='MÃ¼jde TÃ¼rkÃ§e',language='EN'))[0],200)
        code,body=request('GET','/project',headers)
        full=json.loads(body)
        self.assertFalse(full['trial']);self.assertEqual(len(full['rows']),len(studio_schema.load()['slots']))
        self.assertEqual(full['coverage']['missing'],len(full['rows']))
        headers['X-Revision']=full['revision']
        for voice in ('sample', 'another', 'an_other', 'bob', 'a_lp'):
            status, body = request('POST', '/create', headers, dict(voice=voice, language='EN'))
            self.assertEqual(status, 400)
            self.assertIn(b'conflicts with', body)
        self.assertEqual(json.loads(request('GET', '/project', headers)[1])['revision'], full['revision'])
        self.assertEqual(request('POST', '/remove-project', headers, {'key': 'current'})[0], 400)
        self.assertEqual(request('POST', '/remove-project', headers, {'key': 'another'})[0], 200)
        self.assertEqual(json.loads(request('GET', '/project', headers)[1])['projectKey'], 'current')
        self.assertFalse((self.root / 'projects/another').exists())
        self.assertFalse((self.root / 'archived-projects').exists())
        headers['X-Revision'] = p.digest(self.manifest)
        self.assertEqual(request('POST', '/remove-project', headers, {'key': '../escape'})[0], 400)
        self.assertIn('TT', json.loads(request('GET', '/project', headers)[1])['languageFlags'])
        self.assertEqual(request('GET', '/studio/flag/EN', {})[1][:8], b'\x89PNG\r\n\x1a\n')
        headers['X-Revision'] = p.digest(self.manifest)
        project_choices = json.loads(request('GET', '/projects', headers)[1])
        self.assertEqual(project_choices[0]['language'], p.read(self.manifest)['bank']['language'])
        headers['X-Revision'] = 'stale-project-revision'
        self.assertEqual(request('POST','/open',headers,dict(key='current'))[0],200)

    def test_core_catalogue_refreshes_after_template_replacement(self):
        path = self.root / 'voice-template-v1.json'
        path.write_text('{"extras":{"catalog":{}}}', encoding='utf-8')
        with patch.object(studio_schema, 'TOOLS', self.root):
            self.assertEqual(studio_schema.template()['extras']['catalog'], {})
            path.write_text('{"extras":{"catalog":{"WindowLocked_1":{"group":"WindowLocked"}}}}',
                            encoding='utf-8')
            self.assertIn('WindowLocked_1', studio_schema.template()['extras']['catalog'])

    def test_core_schema_covers_required_slots_and_cannot_be_changed_by_projects(self):
        studio_schema.verify_current()
        full=self.root/'full.json';initialize(full,'complete','EN')
        config=p.read(full);studio_schema.validate(config)
        self.assertEqual(set(p.slots(config)),set(studio_schema.load()['slots']))
        for mutate in [lambda b:b['data']['clips'].pop('complete_Thirst_1'),
                       lambda b:b['data']['clips'].update(unknown={'sound':'unknown'}),
                       lambda b:b['native']['replacements'].update(ShoutHey=['Thirst_1']),
                       lambda b:b['expressions'].update(bySource={}),
                       lambda b:b.update(needTiers=0)]:
            changed=copy.deepcopy(config);mutate(changed['bank'])
            with self.assertRaises(ValueError):studio_schema.validate(changed)
        p.set_caption(config['bank'],'Thirst_1','Different language, same meaning.')
        studio_schema.validate(config)
        definition=studio_schema.entry('Whisper_Thirst_1')
        self.assertEqual(definition['source'],'Thirst_1');self.assertEqual(definition['needLevels'],[1])
        self.assertEqual(studio_schema.entry('Thirst_1')['family'],'condition')

    def test_full_project_listing_does_not_rebuild_slots_for_each_row(self):
        p.refresh(self.manifest,True)
        with patch('voice_project.slots',wraps=p.slots) as mapping:
            rows=p.rows(self.manifest)
            self.assertEqual(mapping.call_count,1)
        self.assertEqual(rows['coverage']['missing'],len(rows['rows']))

    def test_schema_hash_ignores_git_line_ending_conversion(self):
        path = self.root / 'input.lua'
        path.write_bytes(b'return 1\r\n')
        windows = studio_schema.source_digest(path)
        path.write_bytes(b'return 1\n')
        self.assertEqual(windows, studio_schema.source_digest(path))
        path.write_bytes(b'return 2\n')
        self.assertNotEqual(windows, studio_schema.source_digest(path))

    def test_stale_core_catalogue_is_rejected_before_server_opens(self):
        schema=copy.deepcopy(studio_schema.load())
        schema['inputs']['42/media/lua/shared/CSV/Rules.lua']='changed'
        with patch('studio_schema.load',return_value=schema):
            with self.assertRaisesRegex(ValueError,'out of date'):
                make_server(self.manifest,'ffmpeg',TOOLS.parents[1])

    def test_old_project_can_be_inspected_for_migration_but_not_edited(self):
        p.refresh(self.manifest,True)
        config=p.read(self.manifest);config['bank']['data']['clips'].pop('sample_Thirst_1');p.write(self.manifest,config)
        view=p.rows(self.manifest)
        self.assertIn('slots differ',view['schemaError']);self.assertEqual(view['rows'],[])
        with self.assertRaises(ValueError):p.edit(self.manifest,'Explore_2','Test','', 'pending')
        p.refresh(self.manifest,True)
        self.assertIsNone(p.rows(self.manifest)['schemaError'])

    def test_metadata_never_leaks_into_package_and_existing_output_survives(self):
        p.refresh(self.manifest, True)
        config = p.read(self.manifest)
        fixture = self.root/'fixture.mp3'; fixture.write_bytes(b'fixture' * 1000)
        for clip in p.slots(config).values(): clip['duration'] = 1000
        for asset in config['assets'].values(): asset['source'] = 'fixture.mp3'
        config['steamProfile']='https://steamcommunity.com/id/ravenwits'
        config['authoring']['private_note'] = 'DO_NOT_DISTRIBUTE_THIS'
        config['credentials'] = 'DO_NOT_DISTRIBUTE_THIS'
        p.write(self.manifest, config)
        output = self.root/'package'
        build(self.manifest, output, TOOLS.parents[1])
        self.assertIn('url=https://steamcommunity.com/id/ravenwits', (output/'42/mod.info').read_text(encoding='utf-8'))
        for file in output.rglob('*'):
            if file.is_file() and file.suffix != '.mp3':
                self.assertNotIn('DO_NOT_DISTRIBUTE_THIS', file.read_text(encoding='utf-8'))
        with self.assertRaises(ValueError): build(self.manifest, output)
        config['bank']['credentials'] = 'private'
        with self.assertRaises(ValueError): validate(config, self.root)

    def test_recording_guidance_is_specific_or_empty_and_user_notes_survive_refresh(self):
        self.assertEqual(p.guidance('Explore_2'),'')
        self.assertNotEqual(p.guidance('Thirst_1'),p.guidance('NeedThirst_3'))
        self.assertIn('quiet',p.guidance('Whisper_Thirst_1'))
        self.assertIn('Shaken after killing',p.guidance('AfterHumanShaken_1'))
        self.assertIn('quiet',p.guidance('Whisper_AfterHumanShaken_1'))
        self.assertIn('Shaken after killing',p.guidance('Whisper_AfterHumanShaken_1'))
        config=p.read(self.manifest)
        config['authoring']['directions']['ExploreMore_1']='Old generated note'
        config['authoring']['referenceDirections']['ExploreMore_1']='Old generated note'
        p.write(self.manifest,config)
        self.assertEqual(p.recording_note(config,'ExploreMore_1'),'')
        p.edit(self.manifest,'Explore_2','My words.','Quietly, with a pause.','pending')
        p.refresh(self.manifest,True)
        row=next(row for row in p.rows(self.manifest)['rows'] if row['slot']=='Explore_2')
        self.assertEqual(row['direction'],'Quietly, with a pause.')
        self.assertEqual(p.recording_note(p.read(self.manifest),'ExploreMore_1'),'')

    def test_update_skips_dirty_official_checkout(self):
        import launch_studio
        root=self.root/'repo';root.mkdir();(root/'.git').mkdir()
        script=root/'launch_studio.py';script.touch()
        calls=[]
        def run(args,**kwargs):
            calls.append(args)
            output='https://github.com/ravenwits/conditional-speech-voices-core.git' if 'remote' in args else ' M edited.py'
            return subprocess.CompletedProcess(args,0,stdout=output)
        with patch.object(launch_studio,'__file__',str(script)), patch('launch_studio.shutil.which',return_value='git'), patch('launch_studio.subprocess.run',side_effect=run), patch.dict(os.environ,{'CSV_STUDIO_UPDATED':'0'}):
            launch_studio.update_checkout()
        self.assertFalse(any('fetch' in c or 'merge' in c for c in calls))

    def test_first_core_sync_keeps_valid_project_unchanged(self):
        before=p.read(self.manifest)
        before.setdefault('authoring',{})['reviews']={'Explore_2':{'status':'approved','fingerprint':'existing'}}
        p.write(self.manifest,before)
        p.sync_core(self.manifest)
        after=p.read(self.manifest)
        after['authoring'].pop('coreInputs')
        self.assertEqual(after,before)

    def test_automatic_core_sync_preserves_trial_and_caption(self):
        config=p.read(self.manifest)
        config.setdefault('authoring',{})['coreInputs']='previous-core'
        p.set_caption(config['bank'],'Explore_2','My own words.')
        p.write(self.manifest,config)
        p.sync_core(self.manifest)
        changed=p.read(self.manifest)
        self.assertEqual(changed['bank']['lines']['Explore_2'],'My own words.')
        self.assertEqual(len(p.slots(changed)),18)
        self.assertTrue(self.manifest.with_suffix('.before-update.json').exists())
        before=p.digest(self.manifest)
        p.sync_core(self.manifest)
        self.assertEqual(p.digest(self.manifest),before)

    def test_core_sync_retires_unplayable_slots_and_keeps_recordings(self):
        self.manifest = self.root / 'full.json'
        initialize(self.manifest, 'sample', 'TR')
        normal = 'EngineRecovered_1'
        retired = 'Whisper_EngineRecovered_1'
        self.supply(normal)
        p.review_many(self.manifest, [normal], 'approved')
        config = p.read(self.manifest)
        clip = copy.deepcopy(p.slots(config)[normal])
        old_sound = clip['sound']
        clip['sound'] = 'CSV_sample_' + retired
        asset = config['assets'][clip['sound']] = copy.deepcopy(config['assets'][old_sound])
        asset['source'] = 'audio/' + retired + '.mp3'
        audio = self.root / asset['source']
        audio.write_bytes(b'legacy whisper')
        config['bank']['data']['clips']['sample_' + retired] = clip
        config['bank']['lines'][retired] = 'Eski fısıltı.'
        config['bank']['voices'][0].update(preview=retired, previewLines=[retired, normal], previewLast=retired)
        config['authoring']['coreInputs'] = 'previous-core'
        p.write(self.manifest, config)

        p.sync_core(self.manifest)
        updated = p.read(self.manifest)
        studio_schema.validate(updated)
        self.assertEqual(p.status(updated, normal, self.root), 'approved')
        self.assertNotIn(retired, p.slots(updated))
        self.assertNotIn(retired, updated['bank']['lines'])
        self.assertEqual(updated['bank']['voices'][0]['previewLines'], [normal])
        self.assertTrue(self.manifest.with_suffix('.before-update.json').is_file())
        self.assertEqual(audio.read_bytes(), b'legacy whisper')

        schema = studio_schema.load()
        self.assertEqual(schema['retiredSlots'][retired], 'requires_vehicle_seat')
        self.assertIn('Whisper_CarAlarm_1', schema['slots'])
        for pool in p.coverage(updated, self.root)['pools'].values():
            self.assertTrue(pool)
            self.assertTrue(set(pool).issubset(schema['slots']))

    @unittest.skipUnless(os.environ.get('VOICE_TEST_FFMPEG'), 'Set VOICE_TEST_FFMPEG for real media tests')
    def test_audio_edits_use_original_preserve_duration_and_reject_clipping(self):
        from array import array
        import math
        from audio_processing import process
        ffmpeg=os.environ['VOICE_TEST_FFMPEG']
        fixture=self.root/'tone.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=1',str(fixture)],check=True)
        p.import_audio(self.manifest,'Explore_2',fixture,ffmpeg)
        def take():
            config=p.read(self.manifest)
            return p.contained(self.root,config['assets'][p.slots(config)['Explore_2']['sound']]['source'])
        def audio_edit():
            return next(row for row in p.rows(self.manifest)['rows'] if row['slot'] == 'Explore_2')['audioEdit']
        def measurements():
            raw=subprocess.run([ffmpeg,'-v','error','-i',str(take()),'-f','f32le','-ar','44100','-ac','1','pipe:1'],capture_output=True,check=True).stdout
            samples=array('f');samples.frombytes(raw)
            middle=samples[4410:-4410]
            rms=math.sqrt(sum(v*v for v in middle)/len(middle))
            frequency=sum(1 for a,b in zip(middle,middle[1:]) if a<=0<b)/(len(middle)/44100)
            return rms,len(samples)/44100,frequency
        original_hash=p.digest(take());rms,duration,freq=measurements()
        self.approve()
        saved_manifest = self.manifest.read_bytes()
        before_files = set((self.root / 'audio').iterdir())
        with patch('voice_project.write', side_effect=OSError('disk full')):
            with self.assertRaisesRegex(OSError, 'disk full'):
                process(self.manifest, 'Explore_2', ffmpeg, gain_db=3)
        self.assertEqual(set((self.root / 'audio').iterdir()), before_files)
        self.assertEqual(self.manifest.read_bytes(), saved_manifest)
        self.assertEqual(p.digest(take()), original_hash)
        process(self.manifest,'Explore_2',ffmpeg,3,0)
        self.assertAlmostEqual(20*math.log10(measurements()[0]/rms),3,delta=.3)
        self.assertEqual(p.status(p.read(self.manifest),'Explore_2',self.root),'pending')
        process(self.manifest,'Explore_2',ffmpeg,6,0)
        self.assertAlmostEqual(20*math.log10(measurements()[0]/rms),6,delta=.3) # not cumulative +9
        process(self.manifest,'Explore_2',ffmpeg,0,3)
        _,edited_duration,edited_freq=measurements()
        self.assertAlmostEqual(edited_duration,duration,delta=.03)
        self.assertAlmostEqual(edited_freq/freq,2**(3/12),delta=.03)
        for speed in (.25,2):
            process(self.manifest,'Explore_2',ffmpeg,speed=speed)
            _,changed_duration,changed_freq=measurements()
            self.assertAlmostEqual(changed_duration,duration/speed,delta=.1)
            self.assertAlmostEqual(changed_freq/freq,1,delta=.03)
            self.assertEqual(audio_edit()['speed'], speed)
        process(self.manifest,'Explore_2',ffmpeg,trim_start=.1,trim_end=.2)
        self.assertAlmostEqual(measurements()[1],duration-.3,delta=.04)
        self.assertEqual(audio_edit()['trimStart'],.1)
        self.assertEqual(audio_edit()['trimEnd'],.2)
        from audio_processing import original_duration
        original_seconds=original_duration(self.manifest,'Explore_2',ffmpeg)
        self.assertAlmostEqual(original_seconds,duration,delta=.04)
        before=p.digest(self.manifest)
        with self.assertRaisesRegex(ValueError,'within the original'): process(self.manifest,'Explore_2',ffmpeg,trim_start=original_seconds)
        with self.assertRaises(ValueError): process(self.manifest,'Explore_2',ffmpeg,trim_start=19,trim_end=19)
        self.assertEqual(p.digest(self.manifest),before)
        before=p.digest(self.manifest)
        for speed in (True,float('nan'),0.24,2.01):
            with self.assertRaises(ValueError):process(self.manifest,'Explore_2',ffmpeg,speed=speed)
            self.assertEqual(p.digest(self.manifest),before)
        process(self.manifest,'Explore_2',ffmpeg,restore=True)
        self.assertEqual(p.digest(take()),original_hash)
        loud=self.root/'loud.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=1','-af','volume=4',str(loud)],check=True)
        p.import_audio(self.manifest,'Explore_2',loud,ffmpeg)
        self.assertFalse(audio_edit())
        before=p.digest(self.manifest);audio_before=p.digest(take())
        with self.assertRaisesRegex(ValueError,'headroom'):process(self.manifest,'Explore_2',ffmpeg,12,0)
        self.assertEqual(p.digest(self.manifest),before);self.assertEqual(p.digest(take()),audio_before)

    @unittest.skipUnless(os.environ.get('VOICE_TEST_FFMPEG'), 'Set VOICE_TEST_FFMPEG for real media tests')
    def test_slowing_beyond_duration_limit_leaves_active_audio_unchanged(self):
        from audio_processing import process
        ffmpeg=os.environ['VOICE_TEST_FFMPEG'];fixture=self.root/'long.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=6',str(fixture)],check=True)
        p.import_audio(self.manifest,'Explore_2',fixture,ffmpeg)
        config=p.read(self.manifest);take=p.contained(self.root,config['assets'][p.slots(config)['Explore_2']['sound']]['source'])
        before=p.digest(self.manifest);audio_before=p.digest(take)
        with self.assertRaisesRegex(ValueError,'at most 20 seconds'):process(self.manifest,'Explore_2',ffmpeg,speed=.25)
        self.assertEqual(p.digest(self.manifest),before);self.assertEqual(p.digest(take),audio_before)

    @unittest.skipUnless(os.environ.get('VOICE_TEST_FFMPEG'), 'Set VOICE_TEST_FFMPEG for real media tests')
    def test_real_import_measure_cache_and_full_package(self):
        ffmpeg = os.environ['VOICE_TEST_FFMPEG']
        fixture = self.root/'test-tone.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=0.3',str(fixture)], check=True)
        browser_take = self.root/'microphone'
        subprocess.run([ffmpeg, '-v', 'error', '-i', str(fixture), '-c:a', 'libopus',
                        '-f', 'webm', str(browser_take)], check=True)
        p.import_audio(self.manifest, 'Explore_2', browser_take, ffmpeg)
        take = self.root/'audio/sample_Explore_2.mp3'
        self.assertTrue(take.is_file())
        measure(self.manifest,ffmpeg,allow_missing=True)
        partial=p.read(self.manifest.with_suffix('.loudness.json'))
        self.assertEqual(len(partial['recordings']),1);self.assertEqual(len(partial['missing']),17)
        self.assertEqual(len(partial['unmeasurable']),1)
        self.assertNotIn('Infinity',self.manifest.read_text(encoding='utf-8'))
        bad = self.root/'invalid.wav'; bad.write_bytes(b'not audio')
        checksum = p.digest(take)
        with self.assertRaises(subprocess.CalledProcessError): p.import_audio(self.manifest,'Explore_2',bad,ffmpeg)
        self.assertEqual(p.digest(take),checksum)
        worker = self.root/'record.py'
        worker.write_text('import shutil,sys\nshutil.copyfile(sys.argv[1],sys.argv[-1])\n')
        first = p.run_jobs(self.manifest,[sys.executable,str(worker),str(take)],ffmpeg,1000,.01,1)
        second = p.run_jobs(self.manifest,[sys.executable,str(worker),str(take)],ffmpeg,1000,.01,1)
        self.assertEqual(first['remaining'],16)
        self.assertEqual(second['remaining'],15)
        p.refresh(self.manifest,True)
        config = p.read(self.manifest)
        for asset in config['assets'].values(): asset['source']='audio/sample_Explore_2.mp3'
        for slot in p.slots(config):
            config['authoring']['reviews'][slot] = dict(status='approved', fingerprint=p.fingerprint(config,slot,self.root))
        p.write(self.manifest,config)
        result = p.workshop_project(self.manifest,self.root/'real-built',ffmpeg,TOOLS.parents[1])
        output = Path(result['output'])
        self.assertTrue((Path(result['mod']) / '42/mod.info').is_file())
        self.assertIn('visibility=private', (output / 'workshop.txt').read_text(encoding='utf-8'))
        self.assertNotIn('\nid=', (output / 'workshop.txt').read_text(encoding='utf-8'))
        for name, dimensions in [('preview.png', (256, 256)), ('preview-16x9.png', (1280, 720))]:
            png = (output / name).read_bytes()
            self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack('>II', png[16:24]), dimensions)
        for directory in (Path(result['mod']), Path(result['mod']) / '42'):
            self.assertIn('icon=icon.png', (directory / 'mod.info').read_text(encoding='utf-8'))
            self.assertEqual((directory / 'icon.png').read_bytes(), (output / 'preview.png').read_bytes())
        with self.assertRaisesRegex(ValueError, 'already exists'):
            p.workshop_project(self.manifest,output,ffmpeg,TOOLS.parents[1])
        self.assertGreater(result['recordings'],1000)
        # Packaging measures only selected takes in a temporary manifest.
        # Warm the editable project's independent cache before checking reuse.
        measure(self.manifest,ffmpeg)
        with patch('prepare_voice_pack.subprocess.run') as process:
            measure(self.manifest,ffmpeg)
            process.assert_not_called()
        self.assertEqual(p.digest(take),checksum)


if __name__ == '__main__': unittest.main()
