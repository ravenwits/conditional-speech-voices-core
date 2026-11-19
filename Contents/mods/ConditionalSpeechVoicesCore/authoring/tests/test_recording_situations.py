"""The in-game context must describe every shipped recording, including alternates."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import studio_schema
from recording_situations import playback_when


class RecordingSituations(unittest.TestCase):
    def context(self, slot):
        return playback_when(studio_schema.entry(slot))

    def test_covers_entire_catalogue(self):
        for slot, entry in studio_schema.load()['slots'].items():
            with self.subTest(slot=slot):
                text = playback_when(entry)
                self.assertTrue(text.endswith('.'))
                self.assertNotIn(slot, text)

    def test_human_attack_and_close_pursuit(self):
        mortal = self.context('MortalFear_1')
        self.assertIn('level 3 or 4', mortal)
        self.assertIn('gives chase', mortal)
        self.assertEqual(mortal, self.context('Alt_MortalFearControlled_1'))
        self.assertIn('below level 3', self.context('HumanDanger_1'))
        self.assertIn('exhaustion', self.context('MortalFear_3'))

    def test_context_follows_delivery_and_acting(self):
        self.assertIn('whisper safely', self.context('Alt_Whisper_MortalFearControlled_1'))
        self.assertNotIn('gives chase', self.context('Whisper_MortalFear_1'))
        self.assertNotIn('whisper safely', self.context('NativeWhisperCall_1'))
        self.assertIn('has a cold', self.context('Expr_congested_FoodEaten_2'))
        self.assertIn('moderate exertion', self.context('Alt_GunJammed_1'))
        self.assertNotIn('moderate exertion', self.context('GunJammed_1'))

    def test_vehicle_roles_and_numeric_conditions(self):
        self.assertIn('passenger', self.context('VehicleImpactPassenger_1'))
        self.assertIn('driving', self.context('VehicleImpactDriver_1'))
        self.assertIn('starts after', self.context('EngineRecovered_1'))
        self.assertIn('31 confirmed zombie kills', self.context('KillCount_1'))
        self.assertIn('1 round left', self.context('AmmoCount_1'))
        self.assertIn('2 rounds left', self.context('AmmoCount_2'))
        self.assertIn('Hunger reaches level 4 of 4', self.context('NeedHungry_4'))

    def test_filtered_and_fallback_sources(self):
        self.assertIn('sawing logs', self.context('SawLogsDone_1'))
        self.assertIn('barricaded window', self.context('DoorBlocked_3'))
        self.assertIn('still feels pain', self.context('InjuryAftermath_3'))
        self.assertIn('close enough', self.context('Expr_frightened_PanicEscape_2'))
