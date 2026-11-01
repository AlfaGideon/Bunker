import random
import unittest
from types import SimpleNamespace

from match_game import Match, GameError


class MatchTest(unittest.TestCase):
    def setUp(self):
        members = [SimpleNamespace(id=str(i), name=f'Player {i}', skin='male') for i in range(6)]
        self.game = Match(members, now=100, rng=random.Random(3))

    def test_station_actions_are_authoritative(self):
        g = self.game
        before = g.snapshot('1', 100)['stations']
        g.command('0', 'food', now=101)
        after = g.snapshot('1', 101)['stations']
        self.assertEqual(after['meals'], before['meals'] - 1)
        self.assertEqual(after['stamina']['0'], 70)
        with self.assertRaisesRegex(GameError, 'already_ate'):
            g.command('0', 'food', now=102)
        g.command('0', 'rest', now=102)
        self.assertEqual(g.stamina['0'], 90)
        with self.assertRaisesRegex(GameError, 'already_rested'):
            g.command('0', 'rest', now=103)
        g.command('1', 'radio_tune', 'bunkers', 104)
        self.assertTrue(g.tick(113))
        radio = g.snapshot('0', 113)['stations']['radio']
        self.assertEqual(radio, g.snapshot('1', 113)['stations']['radio'])
        self.assertEqual(len(radio['received']), 1)
        self.assertEqual(g.deadline, 160)
        g.command('1', 'radio_power', False, 114)
        self.assertIsNone(g.radio_next)
        with self.assertRaisesRegex(GameError, 'invalid_radio'):
            g.command('1', 'radio_tune', {'unexpected': 'value'}, 115)
        with self.assertRaisesRegex(GameError, 'not_active'):
            g.command('stranger', 'food', now=115)

    def test_beacon_validation_and_single_effect(self):
        g = self.game
        for p in g.players:
            p['cards'][0]['value'] = 'Повар'
        with self.assertRaisesRegex(GameError, 'radio_specialist_required'):
            g.command('0', 'radio_tune', 'beacon', 101)
        g.players[1]['cards'][0]['value'] = 'Связист'
        g.command('0', 'radio_tune', 'beacon', 102)
        before = dict(g.stock)
        g.command('0', 'radio_scan', now=103)
        self.assertEqual(g.stock['food'], before['food'] + 4)
        self.assertEqual(g.stock['filters'], before['filters'] + 3)
        with self.assertRaisesRegex(GameError, 'radio_already_scanned'):
            g.command('1', 'radio_scan', now=104)
        self.assertEqual(g.radio['message_id'], 1)

    def test_room_permissions_shared_resources_and_doctor_gate(self):
        g = self.game
        g.players[0]['cards'][0]['value'] = 'Врач'
        g.players[1]['cards'][0]['value'] = 'Повар'
        g.players[2]['cards'][0]['value'] = 'Логист'
        with self.assertRaisesRegex(GameError, 'medical_first_round'):
            g.command('0', 'gate', now=101)
        with self.assertRaisesRegex(GameError, 'wrong_profession'):
            g.command('2', 'kitchen', now=101)
        initial = g.meals
        g.command('1', 'kitchen', now=101)
        self.assertEqual(g.snapshot('0', 101)['stations']['meals'], initial + g.capacity + 2)
        with self.assertRaisesRegex(GameError, 'station_used'):
            g.command('1', 'kitchen', now=102)
        with self.assertRaisesRegex(GameError, 'warehouse_closed'):
            g.command('2', 'supply', now=102)
        for pid in ('0', '1', '2', '3'):
            g.command(pid, 'warehouse_gate', now=103)
        self.assertTrue(g.warehouse_open)
        g.command('2', 'supply', now=104)
        with self.assertRaisesRegex(GameError, 'supply_taken'):
            g.command('2', 'supply', now=105)
        g.round = 2
        g.command('0', 'gate', now=106)
        g.command('0', 'medical', now=107)
        view = g.snapshot('1', 107)['stations']
        self.assertTrue(view['medical_open'])
        self.assertEqual(view['medicines'], 1)
        self.assertEqual(view['stamina']['0'], 75)
        self.assertTrue(view['warehouse_open'])

    def test_round_resource_charges_preserve_hidden_health(self):
        g = self.game
        before = dict(g.stock)
        g._charge_round()
        self.assertLess(g.stock['food'], before['food'])
        self.assertLess(g.stock['water'], before['water'])
        self.assertEqual(g.stamina['0'], 48)
        other = g.snapshot('1', 100)['players'][0]
        self.assertNotIn('cost', next(c for c in other['cards'] if c['id'] == 'health'))

    def test_private_cards_and_biology(self):
        own = self.game.snapshot('0', 100)['players'][0]
        other = self.game.snapshot('1', 100)['players'][0]
        self.assertEqual(sum(c['revealed'] for c in own['cards']), 1)
        for own_card, public_card in zip(own['cards'], other['cards']):
            self.assertIn('value', own_card)
            if not own_card['revealed']:
                self.assertNotIn('value', public_card)
                self.assertNotIn('cost', public_card)
        biology = next(c for c in other['cards'] if c['id'] == 'biology')
        self.assertEqual('sex' in other, biology['revealed'])
        self.assertEqual('age' in other, biology['revealed'])

    def test_turn_permissions_and_timer(self):
        g = self.game
        card = next(c for c in g.players[0]['cards'] if not c['revealed'])
        with self.assertRaisesRegex(GameError, 'not_your_reveal'):
            g.command('1', 'reveal', card['id'], 120)
        g.command('0', 'reveal', card['id'], 120)
        self.assertEqual(g.deadline, 160)
        self.assertEqual(g.snapshot('1', 120)['players'][0]['cards'][g.players[0]['cards'].index(card)]['value'], card['value'])
        with self.assertRaisesRegex(GameError, 'not_your_reveal'):
            g.command('0', 'reveal', card['id'], 121)
        with self.assertRaisesRegex(GameError, 'not_your_turn'):
            g.command('1', 'pass', now=121)
        g.command('0', 'pass', now=125)
        self.assertEqual(g.speaker, '1')
        self.assertEqual(g.deadline, 185)
        self.assertTrue(g.tick(185))
        self.assertEqual(g.speaker, '2')

    def test_full_game_timeouts_and_self_vote_runoff(self):
        g = self.game
        # Every absent vote is a self vote, including the runoff.
        g.tick(100 + 6 * 60)
        self.assertEqual(g.phase, 'discussion')
        g.tick(100 + 6 * 60 + 60)
        self.assertEqual(g.phase, 'vote')
        g.tick(100 + 6 * 60 + 60 + 20)
        self.assertTrue(g.second_ballot)
        self.assertEqual(g.last_result['status'], 'runoff')
        g.tick(100 + 6 * 60 + 60 + 40)
        self.assertEqual(g.phase, 'result')
        self.assertEqual(len(g.active), 5)
        self.assertTrue(g.last_result['random'])
        self.assertTrue(all(k == v for k, v in g.last_result['votes'].items()))
        g.tick(10000)
        self.assertEqual(g.phase, 'end')
        self.assertEqual(len(g.active), 3)

    def test_sizes_and_scenario_are_shared_without_disclosing_cards(self):
        for size in (6, 8, 10):
            players = [SimpleNamespace(id=str(i), name=f'P{i}', skin='female') for i in range(size)]
            game = Match(players, now=0, rng=random.Random(size))
            self.assertEqual(len(game.players), size)
            self.assertEqual(len({p['cards'][0]['value'] for p in game.players}), size)
            self.assertEqual(game.snapshot('0', 0)['scenario'], game.snapshot('1', 0)['scenario'])
            self.assertIn('weather', game.scenario)
            self.assertEqual(game.capacity, size // 2)

    def test_runoff_restricts_choices_but_allows_self_vote(self):
        game = self.game
        game.tick(520)
        for voter in ('0', '1', '2'):
            game.command(voter, 'vote', '0', 521)
        for voter in ('3', '4', '5'):
            game.command(voter, 'vote', '1', 521)
        game.tick(540)
        self.assertEqual(game.candidates, ['0', '1'])
        with self.assertRaisesRegex(GameError, 'invalid_vote'):
            game.command('4', 'vote', '3', 541)
        game.command('4', 'vote', '4', 541)
        self.assertEqual(game.votes['4'], '4')
        game.command('2', 'vote', '1', 541)
        game.command('2', 'vote', '0', 542)
        self.assertEqual(game.votes['2'], '0')

    def test_bots_reveal_pass_and_vote_on_server(self):
        members = [SimpleNamespace(id=str(i), name=f'Player {i}', skin='male') for i in range(6)]
        game = Match(members, now=100, rng=random.Random(13), bot_ids={'1', '2', '3', '4', '5'})
        game.command('0', 'pass', now=101)
        self.assertEqual(game.speaker, '1')
        before = sum(c['revealed'] for c in game.players[1]['cards'])
        self.assertTrue(game.tick(103))
        self.assertEqual(sum(c['revealed'] for c in game.players[1]['cards']), before + 1)
        self.assertEqual(game.speaker, '1')
        game.tick(106)
        self.assertEqual(game.speaker, '2')
        for _ in range(4):
            game.tick(game.deadline - game.SPEECH_SECONDS + 5)
        self.assertEqual(game.phase, 'discussion')
        game.tick(game.deadline)
        self.assertEqual(game.phase, 'vote')
        game.tick(game.deadline - game.VOTE_SECONDS + 2)
        self.assertEqual(set(game.votes), game.bot_ids)
        self.assertTrue(all(target in game.active for target in game.votes.values()))

    def test_vote_validation_and_majority(self):
        g = self.game
        g.tick(520)
        self.assertEqual(g.phase, 'vote')
        for player in g.active[:4]:
            g.command(player, 'vote', '5', 521)
        with self.assertRaisesRegex(GameError, 'invalid_vote'):
            g.command('4', 'vote', 'not-a-player', 521)
        g.tick(540)
        self.assertEqual(g.last_result['player'], '5')
        self.assertFalse(g.last_result['random'])
        with self.assertRaisesRegex(GameError, 'not_active'):
            g.command('5', 'vote', '0', 541)


if __name__ == '__main__':
    unittest.main()
