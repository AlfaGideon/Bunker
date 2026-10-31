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
            # One additional characteristic is public at the start.
            self.rng.choice(cards[1:])['revealed'] = True
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
        return changed

    def command(self, player_id, action, value=None, now=None):
        now = time.monotonic() if now is None else now
        self.tick(now)
        if player_id not in self.active:
            raise GameError('not_active')
        if action == 'reveal':
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
                'my_vote': self.votes.get(viewer), 'result': copy.deepcopy(self.last_result)}
