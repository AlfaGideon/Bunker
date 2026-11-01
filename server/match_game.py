"""Authoritative, in-memory turn and ballot rules for an experimental online match.

No client receives another player's unrevealed card values.  Time is driven by
monotonic deadlines; commands and timer ticks must be serialized by the caller.
"""
import copy
import json
import random
import secrets
import time
from pathlib import Path

CONTENT_PATH = Path(__file__).resolve().parent.parent / 'data' / 'content.json'
if not CONTENT_PATH.exists():  # Docker image has a flat /app layout.
    CONTENT_PATH = Path(__file__).with_name('content.json')
SCENARIOS_PATH = CONTENT_PATH.with_name('scenarios.json')
RADIO_PATH = CONTENT_PATH.with_name('radio.json')


class GameError(Exception):
    pass


class Match:
    SPEECH_SECONDS = 60
    DISCUSSION_SECONDS = 60
    VOTE_SECONDS = 20
    RESULT_SECONDS = 10

    def __init__(self, members, *, now=None, rng=None, content=None, bot_ids=()):
        self.rng = rng or random.SystemRandom()
        self.content = content or json.loads(CONTENT_PATH.read_text(encoding='utf-8'))
        self.seed = secrets.randbelow(2**31)
        self.scenario = self.rng.choice(json.loads(SCENARIOS_PATH.read_text(encoding="utf-8")))
        self.bot_ids = set(bot_ids)
        self.players = []
        professions = self.rng.sample(self.content['professions'], len(members))
        for seat, (member, profession) in enumerate(zip(members, professions)):
            sex = self.rng.choice(['male', 'female'])
            age = self.rng.choice(self.content['ages'])
            cards = [{'id': 'profession', 'label': 'Профессия', 'value': profession, 'revealed': True},
                     {'id': 'biology', 'label': 'Биология', 'value': ('Мужчина, ' if sex == 'male' else 'Женщина, ') + age, 'revealed': False}]
            for key, label, pool in [('skill', 'Увлечение', 'skills'), ('baggage', 'Багаж', 'baggage'),
                                     ('health', 'Здоровье', 'health'), ('fact', 'Дополнительный факт', 'facts'),
                                     ('quality', 'Характер', 'qualities')]:
                chosen = self.rng.choice(self.content[pool])
                card = {'id': key, 'label': label, 'value': chosen['label'] if key == 'health' else chosen, 'revealed': False}
                if key == 'health':
                    card['cost'] = copy.deepcopy(chosen['cost'])
                cards.append(card)
            self.players.append({'id': member.id, 'name': member.name, 'appearance': member.skin,
                                 'sex': sex, 'age': int(age.split()[0]), 'cards': cards, 'bot': member.id in self.bot_ids, 'seat': seat})
        self.active = [p['id'] for p in self.players]
        self.capacity = len(self.active) // 2
        self.round = 1
        self.phase = 'reveal'
        self.speaker_index = 0
        self.revealed_this_turn = False
        self.votes = {}
        self.candidates = []
        self.second_ballot = False
        self.last_result = None
        self.meals = self.capacity
        self.stock = {'water': 100, 'food': 100, 'medicine': 32, 'filters': 24}
        self.stamina = {p['id']: 60 for p in self.players}
        self.medical_open = False
        self.medicines = 2
        self.systems_ready = False
        self.warehouse_open = False
        self.warehouse_votes = {}
        self.supply_taken = False
        self.inventory = {'repair': 1, 'tools': 0, 'weapons': 0}
        self.station_used = {}
        self.shortage = False
        self.station_event = None
        self.used_food = {}
        self.used_rest = {}
        self.radio_data = json.loads(RADIO_PATH.read_text(encoding='utf-8'))
        self.radio = {'powered': True, 'station': 'aurora', 'track_index': 0,
                      'internet_index': 0, 'signal_index': 0, 'scan_round': 0,
                      'received': [], 'message_id': 0}
        self.radio_next = None
        self.revision = 1
        self.deadline = (time.monotonic() if now is None else now) + self.SPEECH_SECONDS

    @property
    def speaker(self):
        return self.active[self.speaker_index] if self.phase == 'reveal' else None

    def _next_speaker(self, now):
        self.speaker_index += 1
        self.revealed_this_turn = False
        if self.speaker_index >= len(self.active):
            self.phase = 'discussion'
            self.deadline = now + self.DISCUSSION_SECONDS
        else:
            self.deadline = now + self.SPEECH_SECONDS

    def _start_vote(self, now, candidates=None):
        self.phase = 'vote'
        self.candidates = candidates or []
        self.second_ballot = bool(candidates)
        self.votes = {}
        self.deadline = now + self.VOTE_SECONDS

    def _finish_vote(self, now):
        counted = {voter: self.votes.get(voter, voter) for voter in self.active}
        totals = {target: list(counted.values()).count(target) for target in set(counted.values())}
        maximum = max(totals.values())
        leaders = sorted(target for target, count in totals.items() if count == maximum)
        if len(leaders) > 1 and not self.second_ballot:
            self.last_result = {'status': 'runoff', 'totals': totals, 'votes': counted, 'leaders': leaders}
            self._start_vote(now, leaders)
            return
        eliminated = self.rng.choice(leaders)
        self.last_result = {'status': 'eliminated', 'player': eliminated, 'totals': totals,
                            'votes': counted, 'random': len(leaders) > 1}
        self.active.remove(eliminated)
        if not self._has_doctor():
            self.medical_open = False
        self.phase = 'end' if len(self.active) <= self.capacity else 'result'
        self.deadline = None if self.phase == 'end' else now + self.RESULT_SECONDS

    def tick(self, now=None):
        now = time.monotonic() if now is None else now
        changed = False
        # Anchor each new deadline to the expired deadline, not the next poll.
        while self.deadline is not None and now >= self.deadline:
            at = self.deadline
            if self.phase == 'reveal':
                self._next_speaker(at)
            elif self.phase == 'discussion':
                self._start_vote(at)
            elif self.phase == 'vote':
                self._finish_vote(at)
            elif self.phase == 'result':
                self.round += 1
                self._charge_round()
                self.phase = 'reveal'
                self.speaker_index = 0
                self.revealed_this_turn = False
                self.deadline = at + self.SPEECH_SECONDS
            else:
                break
            self.revision += 1
            changed = True
        # Test bots use simple random rules, not generated speech or full AI.
        if self.phase == 'reveal' and self.speaker in self.bot_ids:
            elapsed = now - (self.deadline - self.SPEECH_SECONDS)
            if elapsed >= 2 and not self.revealed_this_turn:
                player = next(p for p in self.players if p['id'] == self.speaker)
                hidden = [card for card in player['cards'] if not card['revealed']]
                if hidden:
                    self.rng.choice(hidden)['revealed'] = True
                self.revealed_this_turn = True
                self.revision += 1
                changed = True
            if elapsed >= 5:
                self._next_speaker(now)
                self.revision += 1
                changed = True
        elif self.phase == 'vote' and now >= self.deadline - self.VOTE_SECONDS + 2:
            for bot in self.bot_ids.intersection(self.active):
                if bot not in self.votes:
                    self.votes[bot] = self.rng.choice(self.candidates or self.active)
                    self.revision += 1
                    changed = True
        if self.radio_next is not None and now >= self.radio_next and self.phase != 'end':
            broadcasts = self.radio_data['broadcasts']
            if broadcasts:
                entry = broadcasts[self.radio['message_id'] % len(broadcasts)]
                self._radio_message(entry['source'], entry['text'])
                self.radio_next = now + 20
                self.revision += 1
                changed = True
        return changed

    def _radio_message(self, source, text):
        self.radio['message_id'] += 1
        self.radio['received'].append({'id': self.radio['message_id'], 'from': source, 'text': text})
        self.radio['received'] = self.radio['received'][-24:]

    def _radio_specialist(self):
        return any(p['id'] in self.active and p['cards'][0]['value'] in ('Связист', 'Радиотехник') for p in self.players)

    def _has_doctor(self):
        return any(p['id'] in self.active and p['cards'][0]['value'] == 'Врач' for p in self.players)

    def _charge_round(self):
        costs = {'water': len(self.active) * 2, 'food': len(self.active) * 2, 'medicine': 0, 'filters': 0}
        if self.scenario.get('weather') == 'heat':
            costs['water'] += len(self.active)
        if self.scenario.get('weather') in ('radiation', 'toxic', 'volcano', 'sand'):
            costs['filters'] += 2
        for p in self.players:
            if p['id'] in self.active:
                health = next(c for c in p['cards'] if c['id'] == 'health')
                for key, amount in health.get('cost', {}).items():
                    if key in costs:
                        costs[key] += int(amount)
        self.shortage = any(costs[k] > self.stock[k] for k in costs)
        for key in costs:
            self.stock[key] = max(0, self.stock[key] - costs[key])
        for pid in self.active:
            self.stamina[pid] = max(0, self.stamina[pid] - (20 if self.shortage else 12))

    def _room_action(self, player_id, action):
        roles = {
            'gate': ('Врач',),
            'medical': ('Врач', 'Фельдшер', 'Медсестра', 'Фармацевт', 'Ветеринар', 'Инструктор первой помощи'),
            'terminal': ('Электрик', 'Инженер-механик', 'Связист', 'Программист', 'Техник вентиляции', 'Энергетик', 'Радиотехник', 'Слесарь'),
            'kitchen': ('Повар', 'Пекарь', 'Технолог пищевого производства'),
            'supply': ('Логист', 'Спасатель', 'Водитель', 'Слесарь', 'Электрик', 'Инженер-механик'),
            'gym': ('Тренер', 'Спасатель', 'Пожарный', 'Инструктор первой помощи'),
            'workshop': ('Инженер-механик', 'Сварщик', 'Слесарь', 'Плотник', 'Электрик'),
            'greenhouse': ('Агроном', 'Биолог', 'Эколог', 'Оператор теплицы', 'Зоотехник')}
        if action == 'warehouse_gate':
            if self.warehouse_open:
                raise GameError('warehouse_open')
            self.warehouse_votes[player_id] = True
            # Test bots participate in the decision; they vote only once.
            for bot in self.bot_ids.intersection(self.active):
                if bot not in self.warehouse_votes:
                    self.warehouse_votes[bot] = self.rng.choice([True, False])
            self.warehouse_open = sum(self.warehouse_votes.get(p, False) for p in self.active) > len(self.active) / 2
        else:
            player = next(p for p in self.players if p['id'] == player_id)
            if player['cards'][0]['value'] not in roles[action]:
                raise GameError('wrong_profession')
            if action == 'gate':
                if self.round < 2:
                    raise GameError('medical_first_round')
                if self.medical_open:
                    raise GameError('medical_already_open')
                self.medical_open = True
            elif action == 'supply':
                if not self.warehouse_open:
                    raise GameError('warehouse_closed')
                if self.supply_taken:
                    raise GameError('supply_taken')
                self.supply_taken = True
                self.inventory['tools'] += 2
                self.inventory['weapons'] += 2
                for k, amount in {'water': 20, 'food': 15, 'medicine': 5, 'filters': 4}.items():
                    self.stock[k] += amount
            elif action == 'terminal':
                if self.systems_ready:
                    raise GameError('systems_ready')
                self.systems_ready = True
                self.inventory['repair'] -= 1
            else:
                if action == 'medical' and not self.medical_open:
                    raise GameError('medical_closed')
                if self.station_used.get(action) == self.round:
                    raise GameError('station_used')
                if action == 'medical':
                    if self.medicines <= 0:
                        raise GameError('no_medicines')
                    self.medicines -= 1
                    self.stamina[player_id] = min(100, self.stamina[player_id] + (5 if self.shortage else 15))
                elif action == 'kitchen':
                    if self.stock['food'] < 4 or self.stock['water'] < 2:
                        raise GameError('not_enough_supplies')
                    self.stock['food'] -= 4
                    self.stock['water'] -= 2
                    self.meals += self.capacity + 2
                elif action == 'greenhouse':
                    if self.stock['water'] < 3:
                        raise GameError('not_enough_supplies')
                    self.stock['water'] -= 3
                    self.stock['food'] += 4
                elif action == 'workshop':
                    self.stock['filters'] += 2
                elif action == 'gym':
                    self.stamina[player_id] = min(100, self.stamina[player_id] + 10)
                self.station_used[action] = self.round
        self.station_event = {'id': self.revision + 1, 'player': player_id, 'action': action}

    def _station_action(self, player_id, action, value, now):
        if self.phase == 'end':
            raise GameError('match_finished')
        if action in ('gate', 'medical', 'terminal', 'kitchen', 'warehouse_gate', 'supply', 'gym', 'workshop', 'greenhouse'):
            self._room_action(player_id, action)
        elif action == 'food':
            if self.used_food.get(player_id) == self.round:
                raise GameError('already_ate')
            if self.meals <= 0:
                raise GameError('no_meals')
            self.meals -= 1
            self.used_food[player_id] = self.round
            self.stamina[player_id] = min(100, self.stamina[player_id] + 10)
            self.station_event = {'id': self.revision + 1, 'player': player_id, 'action': 'food'}
        elif action == 'rest':
            if self.used_rest.get(player_id) == self.round:
                raise GameError('already_rested')
            self.used_rest[player_id] = self.round
            self.stamina[player_id] = min(100, self.stamina[player_id] + (10 if self.shortage else 20))
            self.station_event = {'id': self.revision + 1, 'player': player_id, 'action': 'rest'}
        elif action == 'radio_power':
            if not isinstance(value, bool):
                raise GameError('invalid_radio')
            self.radio['powered'] = value
            self.radio_next = now + 9 if value and self.radio['station'] == 'bunkers' else None
        elif action == 'radio_tune':
            if not isinstance(value, str) or value not in ('aurora', 'bunkers', 'beacon', 'internet'):
                raise GameError('invalid_radio')
            if value == 'beacon' and not self._radio_specialist():
                raise GameError('radio_specialist_required')
            same = self.radio['powered'] and self.radio['station'] == value
            if same and value == 'aurora':
                self.radio['track_index'] = (self.radio['track_index'] + 1) % 4
            if same and value == 'internet':
                self.radio['internet_index'] = (self.radio['internet_index'] + 1) % 4
            self.radio['station'] = value
            self.radio['powered'] = True
            self.radio_next = now + 9 if value == 'bunkers' and not same else self.radio_next if value == 'bunkers' else None
        elif action == 'radio_scan':
            if not self._radio_specialist():
                raise GameError('radio_specialist_required')
            if not self.radio['powered'] or self.radio['station'] != 'beacon':
                raise GameError('radio_not_beacon')
            if self.radio['scan_round'] == self.round:
                raise GameError('radio_already_scanned')
            index = self.radio['signal_index']
            if index >= len(self.radio_data['signals']):
                raise GameError('radio_exhausted')
            signal = self.radio_data['signals'][index]
            self.radio['signal_index'] += 1
            self.radio['scan_round'] = self.round
            if signal.get('effect') == 'supplies':
                self.stock['filters'] += 3
                self.stock['food'] += 4
            elif signal.get('effect') == 'stamina':
                for pid in self.active:
                    self.stamina[pid] = min(100, self.stamina[pid] + 15)
            self._radio_message(signal['title'], signal['text'])
        else:
            raise GameError('unknown_game_action')

    def command(self, player_id, action, value=None, now=None):
        now = time.monotonic() if now is None else now
        self.tick(now)
        if player_id not in self.active:
            raise GameError('not_active')
        if action in ('food', 'rest', 'radio_power', 'radio_tune', 'radio_scan', 'gate', 'medical', 'terminal', 'kitchen', 'warehouse_gate', 'supply', 'gym', 'workshop', 'greenhouse'):
            self._station_action(player_id, action, value, now)
        elif action == 'reveal':
            if self.phase != 'reveal' or self.speaker != player_id or self.revealed_this_turn:
                raise GameError('not_your_reveal')
            player = next(p for p in self.players if p['id'] == player_id)
            card = next((c for c in player['cards'] if c['id'] == value), None)
            if card is None or card['revealed']:
                raise GameError('invalid_card')
            card['revealed'] = True
            self.revealed_this_turn = True
        elif action == 'pass':
            if self.phase != 'reveal' or self.speaker != player_id:
                raise GameError('not_your_turn')
            self._next_speaker(now)
        elif action == 'vote':
            if self.phase != 'vote':
                raise GameError('not_voting')
            if value not in self.active or (self.candidates and value != player_id and value not in self.candidates):
                raise GameError('invalid_vote')
            self.votes[player_id] = value
        else:
            raise GameError('unknown_game_action')
        self.revision += 1

    def snapshot(self, viewer, now=None):
        now = time.monotonic() if now is None else now
        players = copy.deepcopy(self.players)
        for player in players:
            if player['id'] != viewer:
                for card in player['cards']:
                    if not card['revealed']:
                        card.pop('value', None)
                        card.pop('cost', None)
                # Cosmetic appearance is public, biological sex/age are not.
                if not next(c for c in player['cards'] if c['id'] == 'biology')['revealed']:
                    player.pop('sex', None)
                    player.pop('age', None)
        return {'revision': self.revision, 'seed': self.seed, 'scenario': copy.deepcopy(self.scenario), 'players': players,
                'active': list(self.active), 'capacity': self.capacity, 'round': self.round,
                'phase': self.phase, 'speaker': self.speaker, 'revealed_this_turn': self.revealed_this_turn,
                'remaining': max(0, self.deadline - now) if self.deadline is not None else 0,
                'candidates': list(self.candidates), 'second_ballot': self.second_ballot,
                'my_vote': self.votes.get(viewer), 'result': copy.deepcopy(self.last_result),
                'stations': {'meals': self.meals, 'stock': copy.deepcopy(self.stock),
                             'stamina': copy.deepcopy(self.stamina), 'medical_open': self.medical_open, 'medicines': self.medicines, 'warehouse_open': self.warehouse_open, 'warehouse_votes': sum(self.warehouse_votes.get(p, False) for p in self.active), 'systems_ready': self.systems_ready, 'inventory': copy.deepcopy(self.inventory), 'shortage': self.shortage, 'event': copy.deepcopy(self.station_event), 'radio': copy.deepcopy(self.radio)}}
