"""Check that the selected take has its own playable direction."""
from collections import defaultdict
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import recording_guidance
import studio_schema


class Performance(unittest.TestCase):
    def test_different_acting_choices_have_distinct_notes_within_a_delivery(self):
        observed = defaultdict(dict)
        for slot, definition in studio_schema.load()['slots'].items():
            if definition['category'] != 'Dialogue':
                continue
            notes = observed[definition['group'], definition['delivery']]
            acting = definition['acting']
            note, _ = recording_guidance.performance(slot, 'EN')
            self.assertEqual(notes.setdefault(note, acting), acting, slot)

    def test_controlled_direction_follows_the_scene_and_the_delivery(self):
        scenes = {'MortalFear': 'next move', 'HumanDanger': 'attack',
                  'KeepHidden': 'listen', 'ShelterThreat': 'way out'}
        for scene, cue in scenes.items():
            with self.subTest(scene=scene):
                normal, tags = recording_guidance.performance(f'Alt_{scene}Controlled_1', 'EN')
                whisper, quiet_tags = recording_guidance.performance(f'Alt_Whisper_{scene}Controlled_1', 'EN')
                ordinary, _ = recording_guidance.performance(f'{scene}_1', 'EN')
                self.assertIn(cue, normal)
                self.assertNotEqual(normal, ordinary)
                self.assertIn(normal, whisper)
                self.assertIn('whisper', whisper)
                self.assertEqual(quiet_tags, ['[whispers, ' + tags[0][1:]])

    def test_optional_acting_and_physical_delivery_can_change_separately(self):
        angry, angry_tags = recording_guidance.performance('Expr_angry_GunJammed_1', 'EN')
        scared, scared_tags = recording_guidance.performance('Expr_frightened_GunJammed_1', 'EN')
        self.assertIn('jam', angry)
        self.assertIn('jam', scared)
        self.assertIn('anger', angry_tags[0])
        self.assertIn('fear', scared_tags[0])
        self.assertIn('cry out', recording_guidance.performance('Fire_2', 'EN')[0].lower())
        self.assertNotEqual(recording_guidance.performance('Fire_1', 'EN'),
                            recording_guidance.performance('Fire_2', 'EN'))

    def test_shared_mortal_fear_respects_the_fallback_role(self):
        normal, tags = recording_guidance.performance('Alt_MortalFear_1', 'TR')
        controlled, controlled_tags = recording_guidance.performance('Alt_MortalFearControlled_1', 'TR')
        self.assertIn('as a fallback', normal)
        self.assertIn('tight with fear', tags[0])
        self.assertNotIn('wavering', tags[0])
        self.assertIn('steady breath', controlled)
        self.assertIn('steady and decisive', controlled_tags[0])

    def test_physical_variants_keep_distinct_enunciation_and_breath(self):
        from studio_elevenlabs import prompt
        breathless = 'Expr_breathless_Endurance_1'
        slurred = 'Expr_slurred_Endurance_1'
        line = 'Nefesimi toparlamam lazım.'
        config = {'bank': {'language': 'TR', 'lines': {breathless: line, slurred: line}}}
        breathless_note, _ = recording_guidance.performance(breathless, 'TR')
        slurred_note, _ = recording_guidance.performance(slurred, 'TR')
        breathless_script = prompt(config, breathless)['text']
        slurred_script = prompt(config, slurred)['text']
        self.assertIn('Keep consonants crisp', breathless_note)
        self.assertIn('jaw loose', slurred_note)
        self.assertTrue(breathless_script.startswith('[audibly panting, words in short bursts]'))
        self.assertTrue(slurred_script.startswith('[drunk, loose jaw, drawn-out vowels and blurred words]'))
        self.assertNotIn('panting', slurred_script)
        self.assertTrue(breathless_script.endswith(line) and slurred_script.endswith(line))
        _, drunk_tags = recording_guidance.performance('Expr_slurred_Drunk_1', 'TR')
        self.assertIn('then over-enunciating', drunk_tags[0])
        self.assertIn('hiccup', recording_guidance.performance('Drunk_3', 'TR')[1][0])
        self.assertIn('goofy chuckle', recording_guidance.performance('Expr_slurred_ReliefBoredom_1', 'TR')[1][0])
        self.assertNotIn('chuckle', recording_guidance.performance('Expr_slurred_Endurance_1', 'TR')[1][0])
