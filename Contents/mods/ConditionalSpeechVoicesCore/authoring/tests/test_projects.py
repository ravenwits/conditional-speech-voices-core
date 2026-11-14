"""Run with python -B -m unittest discover -s authoring/tests -v."""
import copy
import http.client
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
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

    def supply(self, slot='Explore_1'):
        config = p.read(self.manifest)
        asset = config['assets'][p.slots(config)[slot]['sound']]
        path = p.contained(self.root, asset['source'])
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(b'test recording bytes' * 100)
        return path

    def approve(self, slot='Explore_1'):
        p.edit(self.manifest, slot, 'Buraya daha bakmadım.', 'A cautious observation.', 'approved')

    def test_bulk_review_is_scoped_and_atomic_and_keeps_files(self):
        first=self.supply();second=self.supply('Explore_2')
        checksums=[p.digest(first),p.digest(second)]
        p.review_many(self.manifest,['Explore_1'],'approved')
        config=p.read(self.manifest)
        self.assertEqual(p.status(config,'Explore_1',self.root),'approved')
        self.assertEqual(p.status(config,'Explore_2',self.root),'pending')
        before=p.digest(self.manifest)
        for selection in (['Explore_1','Explore_3'],['Unknown'],['Explore_1','Explore_1']):
            with self.assertRaises(ValueError):p.review_many(self.manifest,selection,'redo')
            self.assertEqual(p.digest(self.manifest),before)
        p.review_many(self.manifest,['Explore_1','Explore_2'],'redo')
        self.assertEqual([p.digest(first),p.digest(second)],checksums)
        self.assertEqual(p.status(p.read(self.manifest),'Explore_1',self.root),'redo')

    def test_bulk_undo_preserves_unrelated_changes_and_rejects_changed_takes(self):
        first=self.supply();self.supply('Explore_2')
        checksum=p.digest(first)
        p.review_many(self.manifest,['Explore_1'],'approved')
        p.edit(self.manifest,'Explore_2','Başka bir replik.','','redo')
        self.assertTrue(p.rows(self.manifest)['canUndoReview'])
        p.undo_review(self.manifest)
        config=p.read(self.manifest)
        self.assertEqual(p.status(config,'Explore_1',self.root),'pending')
        self.assertEqual(p.status(config,'Explore_2',self.root),'redo')
        self.assertFalse(p.rows(self.manifest)['canUndoReview'])
        self.assertEqual(p.digest(first),checksum)
        p.review_many(self.manifest,['Explore_1'],'approved')
        p.edit(self.manifest,'Explore_1','Yeni replik.','','pending')
        before=p.digest(self.manifest)
        with self.assertRaisesRegex(ValueError,'newer work'):p.undo_review(self.manifest)
        self.assertEqual(p.digest(self.manifest),before)

    def test_unicode_caption_round_trip_preserves_slot(self):
        self.supply()
        text='Göz gözü görmüyor. العربية 日本語 ਪੰਜਾਬੀ 🫥'
        p.edit(self.manifest,'Explore_1',text,'','pending')
        row=next(r for r in p.rows(self.manifest)['rows'] if r['slot']=='Explore_1')
        self.assertEqual(row['text'],text)
        self.assertIn('Explore_1',p.slots(p.read(self.manifest)))

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
        for code in ('ACE','CRH_CYRL','SAT_OLCK','BER_TFNG','PA_ARAB'):
            target=self.root/code/'project.json'
            initialize(target,'test_voice',code,trial=True)
            self.assertEqual(p.rows(target)['language'],code)

    def test_caption_and_profile_limits(self):
        from recording_limits import steam_profile, MAX_CAPTION
        self.supply()
        p.edit(self.manifest,'Explore_1','x'*MAX_CAPTION,'','pending')
        before=p.digest(self.manifest)
        with self.assertRaises(ValueError):p.edit(self.manifest,'Explore_1','x'*(MAX_CAPTION+1),'','pending')
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
        self.assertEqual(config['bank']['lines']['Explore_1'], 'Buraya daha bakmadım.')
        self.assertEqual(p.digest(path), checksum)
        self.assertEqual(p.status(config, 'Explore_1', self.root), 'approved')
        self.assertTrue(self.manifest.with_suffix('.before-update.json').is_file())
        self.assertEqual(p.refresh(self.manifest), dict(added=[], removed=[], changed=[]))

    def test_changed_reference_requires_new_review_but_keeps_take(self):
        self.supply(); self.approve(); p.refresh(self.manifest, True)
        config = p.read(self.manifest)
        config['authoring']['references']['Explore_1'] = 'Old meaning'
        p.write(self.manifest, config)
        diff = p.refresh(self.manifest, True)
        self.assertIn('Explore_1', diff['changed'])
        self.assertEqual(p.status(p.read(self.manifest), 'Explore_1', self.root), 'pending')

    def test_external_audio_change_invalidates_approval(self):
        path = self.supply(); self.approve()
        path.write_bytes(b'replaced recording')
        self.assertEqual(p.status(p.read(self.manifest), 'Explore_1', self.root), 'pending')

    def test_jobs_skip_existing_unreviewed_and_approved_takes(self):
        self.supply()
        self.assertEqual(p.jobs(self.manifest)['recordings'], 17)
        p.edit(self.manifest, 'Explore_1', 'A new line.', 'Speak gently.', 'redo')
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
        (folder/'Explore_1.wav').write_bytes(b'first')
        (folder/'sample_Explore_2.mp3').write_bytes(b'second')
        (folder/'unknown.mp3').write_bytes(b'unknown')
        self.supply('Explore_1')
        with patch('voice_project.import_audio', side_effect=lambda manifest,slot,source,ffmpeg:self.supply(slot)) as importer:
            result=p.import_folder(self.manifest,folder,'ffmpeg')
            self.assertEqual(result['imported'],['Explore_2'])
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
        self.assertIn('Buraya', config['bank']['lines']['Explore_1'])
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
        self.assertEqual(request('POST','/create',headers,dict(voice='another',name='Müjde Türkçe',language='EN'))[0],200)
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
        self.assertEqual(request('POST','/open',headers,dict(key='current'))[0],200)

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
        with self.assertRaises(ValueError):p.edit(self.manifest,'Explore_1','Test','', 'pending')
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
        self.assertEqual(p.guidance('Explore_1'),'')
        self.assertNotEqual(p.guidance('Thirst_1'),p.guidance('NeedThirst_3'))
        self.assertIn('quiet',p.guidance('Whisper_Thirst_1'))
        self.assertIn('Shaken after killing',p.guidance('AfterHumanShaken_1'))
        self.assertIn('quiet',p.guidance('Whisper_AfterHumanShaken_1'))
        self.assertIn('Shaken after killing',p.guidance('Whisper_AfterHumanShaken_1'))
        config=p.read(self.manifest)
        config['authoring']['directions']['Explore_2']='Old generated note'
        config['authoring']['referenceDirections']['Explore_2']='Old generated note'
        p.write(self.manifest,config)
        self.assertEqual(p.recording_note(config,'Explore_2'),'')
        p.edit(self.manifest,'Explore_1','My words.','Quietly, with a pause.','pending')
        p.refresh(self.manifest,True)
        row=next(row for row in p.rows(self.manifest)['rows'] if row['slot']=='Explore_1')
        self.assertEqual(row['direction'],'Quietly, with a pause.')
        self.assertEqual(p.recording_note(p.read(self.manifest),'Explore_2'),'')

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
        before.setdefault('authoring',{})['reviews']={'Explore_1':{'status':'approved','fingerprint':'existing'}}
        p.write(self.manifest,before)
        p.sync_core(self.manifest)
        after=p.read(self.manifest)
        after['authoring'].pop('coreInputs')
        self.assertEqual(after,before)

    def test_automatic_core_sync_preserves_trial_and_caption(self):
        config=p.read(self.manifest)
        config.setdefault('authoring',{})['coreInputs']='previous-core'
        p.set_caption(config['bank'],'Explore_1','My own words.')
        p.write(self.manifest,config)
        p.sync_core(self.manifest)
        changed=p.read(self.manifest)
        self.assertEqual(changed['bank']['lines']['Explore_1'],'My own words.')
        self.assertEqual(len(p.slots(changed)),18)
        self.assertTrue(self.manifest.with_suffix('.before-update.json').exists())
        before=p.digest(self.manifest)
        p.sync_core(self.manifest)
        self.assertEqual(p.digest(self.manifest),before)

    @unittest.skipUnless(os.environ.get('VOICE_TEST_FFMPEG'), 'Set VOICE_TEST_FFMPEG for real media tests')
    def test_audio_edits_use_original_preserve_duration_and_reject_clipping(self):
        from array import array
        import math
        from audio_processing import process
        ffmpeg=os.environ['VOICE_TEST_FFMPEG']
        fixture=self.root/'tone.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=1',str(fixture)],check=True)
        p.import_audio(self.manifest,'Explore_1',fixture,ffmpeg)
        def take():
            config=p.read(self.manifest)
            return p.contained(self.root,config['assets'][p.slots(config)['Explore_1']['sound']]['source'])
        def measurements():
            raw=subprocess.run([ffmpeg,'-v','error','-i',str(take()),'-f','f32le','-ar','44100','-ac','1','pipe:1'],capture_output=True,check=True).stdout
            samples=array('f');samples.frombytes(raw)
            middle=samples[4410:-4410]
            rms=math.sqrt(sum(v*v for v in middle)/len(middle))
            frequency=sum(1 for a,b in zip(middle,middle[1:]) if a<=0<b)/(len(middle)/44100)
            return rms,len(samples)/44100,frequency
        original_hash=p.digest(take());rms,duration,freq=measurements()
        self.approve()
        process(self.manifest,'Explore_1',ffmpeg,3,0)
        self.assertAlmostEqual(20*math.log10(measurements()[0]/rms),3,delta=.3)
        self.assertEqual(p.status(p.read(self.manifest),'Explore_1',self.root),'pending')
        process(self.manifest,'Explore_1',ffmpeg,6,0)
        self.assertAlmostEqual(20*math.log10(measurements()[0]/rms),6,delta=.3) # not cumulative +9
        process(self.manifest,'Explore_1',ffmpeg,0,3)
        _,edited_duration,edited_freq=measurements()
        self.assertAlmostEqual(edited_duration,duration,delta=.03)
        self.assertAlmostEqual(edited_freq/freq,2**(3/12),delta=.03)
        for speed in (.25,2):
            process(self.manifest,'Explore_1',ffmpeg,speed=speed)
            _,changed_duration,changed_freq=measurements()
            self.assertAlmostEqual(changed_duration,duration/speed,delta=.1)
            self.assertAlmostEqual(changed_freq/freq,1,delta=.03)
            self.assertEqual(p.rows(self.manifest)['rows'][0]['audioEdit']['speed'],speed)
        process(self.manifest,'Explore_1',ffmpeg,trim_start=.1,trim_end=.2)
        self.assertAlmostEqual(measurements()[1],duration-.3,delta=.04)
        self.assertEqual(p.rows(self.manifest)['rows'][0]['audioEdit']['trimStart'],.1)
        self.assertEqual(p.rows(self.manifest)['rows'][0]['audioEdit']['trimEnd'],.2)
        from audio_processing import original_duration
        original_seconds=original_duration(self.manifest,'Explore_1',ffmpeg)
        self.assertAlmostEqual(original_seconds,duration,delta=.04)
        before=p.digest(self.manifest)
        with self.assertRaisesRegex(ValueError,'within the original'): process(self.manifest,'Explore_1',ffmpeg,trim_start=original_seconds)
        with self.assertRaises(ValueError): process(self.manifest,'Explore_1',ffmpeg,trim_start=19,trim_end=19)
        self.assertEqual(p.digest(self.manifest),before)
        before=p.digest(self.manifest)
        for speed in (True,float('nan'),0.24,2.01):
            with self.assertRaises(ValueError):process(self.manifest,'Explore_1',ffmpeg,speed=speed)
            self.assertEqual(p.digest(self.manifest),before)
        process(self.manifest,'Explore_1',ffmpeg,restore=True)
        self.assertEqual(p.digest(take()),original_hash)
        loud=self.root/'loud.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=1','-af','volume=4',str(loud)],check=True)
        p.import_audio(self.manifest,'Explore_1',loud,ffmpeg)
        self.assertFalse(p.rows(self.manifest)['rows'][0]['audioEdit'])
        before=p.digest(self.manifest);audio_before=p.digest(take())
        with self.assertRaisesRegex(ValueError,'headroom'):process(self.manifest,'Explore_1',ffmpeg,12,0)
        self.assertEqual(p.digest(self.manifest),before);self.assertEqual(p.digest(take()),audio_before)

    @unittest.skipUnless(os.environ.get('VOICE_TEST_FFMPEG'), 'Set VOICE_TEST_FFMPEG for real media tests')
    def test_slowing_beyond_duration_limit_leaves_active_audio_unchanged(self):
        from audio_processing import process
        ffmpeg=os.environ['VOICE_TEST_FFMPEG'];fixture=self.root/'long.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=6',str(fixture)],check=True)
        p.import_audio(self.manifest,'Explore_1',fixture,ffmpeg)
        config=p.read(self.manifest);take=p.contained(self.root,config['assets'][p.slots(config)['Explore_1']['sound']]['source'])
        before=p.digest(self.manifest);audio_before=p.digest(take)
        with self.assertRaisesRegex(ValueError,'at most 20 seconds'):process(self.manifest,'Explore_1',ffmpeg,speed=.25)
        self.assertEqual(p.digest(self.manifest),before);self.assertEqual(p.digest(take),audio_before)

    @unittest.skipUnless(os.environ.get('VOICE_TEST_FFMPEG'), 'Set VOICE_TEST_FFMPEG for real media tests')
    def test_real_import_measure_cache_and_full_package(self):
        ffmpeg = os.environ['VOICE_TEST_FFMPEG']
        fixture = self.root/'test-tone.wav'
        subprocess.run([ffmpeg,'-v','error','-f','lavfi','-i','sine=frequency=440:duration=0.3',str(fixture)], check=True)
        browser_take = self.root/'microphone'
        subprocess.run([ffmpeg, '-v', 'error', '-i', str(fixture), '-c:a', 'libopus',
                        '-f', 'webm', str(browser_take)], check=True)
        p.import_audio(self.manifest, 'Explore_1', browser_take, ffmpeg)
        take = self.root/'audio/sample_Explore_1.mp3'
        self.assertTrue(take.is_file())
        measure(self.manifest,ffmpeg,allow_missing=True)
        partial=p.read(self.manifest.with_suffix('.loudness.json'))
        self.assertEqual(len(partial['recordings']),1);self.assertEqual(len(partial['missing']),17)
        self.assertEqual(len(partial['unmeasurable']),1)
        self.assertNotIn('Infinity',self.manifest.read_text(encoding='utf-8'))
        bad = self.root/'invalid.wav'; bad.write_bytes(b'not audio')
        checksum = p.digest(take)
        with self.assertRaises(subprocess.CalledProcessError): p.import_audio(self.manifest,'Explore_1',bad,ffmpeg)
        self.assertEqual(p.digest(take),checksum)
        worker = self.root/'record.py'
        worker.write_text('import shutil,sys\nshutil.copyfile(sys.argv[1],sys.argv[-1])\n')
        first = p.run_jobs(self.manifest,[sys.executable,str(worker),str(take)],ffmpeg,1000,.01,1)
        second = p.run_jobs(self.manifest,[sys.executable,str(worker),str(take)],ffmpeg,1000,.01,1)
        self.assertEqual(first['remaining'],16)
        self.assertEqual(second['remaining'],15)
        p.refresh(self.manifest,True)
        config = p.read(self.manifest)
        for asset in config['assets'].values(): asset['source']='audio/sample_Explore_1.mp3'
        for slot in p.slots(config):
            config['authoring']['reviews'][slot] = dict(status='approved', fingerprint=p.fingerprint(config,slot,self.root))
        p.write(self.manifest,config)
        result = p.workshop_project(self.manifest,self.root/'real-built',ffmpeg,TOOLS.parents[1])
        output = Path(result['output'])
        self.assertTrue((Path(result['mod']) / '42/mod.info').is_file())
        self.assertIn('visibility=private', (output / 'workshop.txt').read_text(encoding='utf-8'))
        self.assertNotIn('\nid=', (output / 'workshop.txt').read_text(encoding='utf-8'))
        self.assertEqual((output / 'preview.png').read_bytes()[:8], b'\x89PNG\r\n\x1a\n')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            p.workshop_project(self.manifest,output,ffmpeg,TOOLS.parents[1])
        self.assertGreater(result['recordings'],1000)
        with patch('prepare_voice_pack.subprocess.run') as process:
            measure(self.manifest,ffmpeg)
            process.assert_not_called()
        self.assertEqual(p.digest(take),checksum)


if __name__ == '__main__': unittest.main()
