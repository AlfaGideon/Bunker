using System;
using System.Collections.Generic;
using System.Linq;

namespace Bunker.UnityPort
{
    [Serializable] public sealed class ContentData
    {
        public string[] professions, ages, skills, baggage, facts, qualities;
        public HealthOption[] health;
    }
    [Serializable] public sealed class HealthOption { public string label; public Stock cost; }
    [Serializable] public sealed class ScenarioList { public Scenario[] items; }

    // Offline rules; no server connection. The UI and 3D scene are separate.
    // Time is supplied by the caller for deterministic tests.
    public sealed class LocalMatch
    {
        public const string HumanId = "local_0";
        private readonly Random random;
        private readonly List<Player> players = new List<Player>();
        private readonly List<string> active = new List<string>();
        private readonly Dictionary<string, string> votes = new Dictionary<string, string>();
        private readonly List<string> candidates = new List<string>();
        private readonly Scenario scenario;
        private readonly LocalStations stations;
        public string LastError { get; private set; }
        private int speakerIndex;
        private bool revealedThisTurn, secondBallot, botRevealed, botsVoted;
        private int revision = 1;
        private readonly int capacity;
        private int round = 1;
        private string phase = "reveal";
        private float remaining = 60;
        private VoteResult result;

        public LocalMatch(ContentData data, Scenario[] scenarios, int count, string name, int seed, RadioContent radioData = null)
        {
            if (data == null || data.professions == null || data.professions.Length < count ||
                data.ages == null || data.ages.Length == 0 || data.skills == null || data.skills.Length == 0 ||
                data.baggage == null || data.baggage.Length == 0 || data.health == null || data.health.Length == 0 ||
                data.facts == null || data.facts.Length == 0 || data.qualities == null || data.qualities.Length == 0 ||
                scenarios == null || scenarios.Length == 0 || (count != 6 && count != 8 && count != 10))
                throw new ArgumentException("Неполные игровые данные");
            random = new Random(seed);
            capacity = count / 2;
            scenario = scenarios[random.Next(scenarios.Length)];
            var professions = data.professions.OrderBy(_ => random.Next()).Take(count).ToArray();
            var healthCosts = new Dictionary<string, Stock>();
            for (int i = 0; i < count; i++)
            {
                string id = "local_" + i;
                bool male = random.Next(2) == 0;
                string age = Pick(data.ages);
                var health = data.health[random.Next(data.health.Length)];
                healthCosts[id] = health.cost ?? new Stock();
                var cards = new[] {
                    NewCard("profession", "Профессия", professions[i], true),
                    NewCard("biology", "Биология", (male ? "Мужчина, " : "Женщина, ") + age),
                    NewCard("skill", "Увлечение", Pick(data.skills)),
                    NewCard("baggage", "Багаж", Pick(data.baggage)),
                    NewCard("health", "Здоровье", health.label),
                    NewCard("fact", "Дополнительный факт", Pick(data.facts)),
                    NewCard("quality", "Характер", Pick(data.qualities))
                };
                players.Add(new Player { id = id, name = i == 0 ? name : "Бот " + i,
                    bot = i != 0, appearance = male ? "male" : "female", seat = i, cards = cards });
                active.Add(id);
            }
            stations = new LocalStations(players, healthCosts, capacity, radioData);
        }
        private string Pick(string[] pool) => pool[random.Next(pool.Length)];
        private static Card NewCard(string id, string label, string value, bool revealed = false) =>
            new Card { id = id, label = label, value = value, revealed = revealed };
        private string Speaker => phase == "reveal" && speakerIndex < active.Count ? active[speakerIndex] : null;
        private void NextSpeaker()
        {
            speakerIndex++; revealedThisTurn = false; botRevealed = false;
            if (speakerIndex >= active.Count) { phase = "discussion"; remaining = 60; }
            else remaining = 60;
        }
        private void BeginVote(string[] leaders = null)
        {
            phase = "vote"; remaining = 20; votes.Clear(); candidates.Clear();
            if (leaders != null) candidates.AddRange(leaders);
            secondBallot = leaders != null && leaders.Length > 0;
            botsVoted = false;
        }
        private void FinishVote()
        {
            var totals = new Dictionary<string, int>();
            foreach (string voter in active)
            {
                string target = votes.TryGetValue(voter, out var chosen) ? chosen : voter;
                if (!active.Contains(target) || (candidates.Count > 0 && target != voter && !candidates.Contains(target))) target = voter;
                totals[target] = totals.TryGetValue(target, out int total) ? total + 1 : 1;
            }
            int max = totals.Values.Max();
            var leaders = totals.Where(v => v.Value == max).Select(v => v.Key).OrderBy(x => x).ToArray();
            if (leaders.Length > 1 && !secondBallot)
            {
                result = new VoteResult { status = "runoff", leaders = leaders };
                BeginVote(leaders);
                return;
            }
            string eliminated = leaders[random.Next(leaders.Length)];
            result = new VoteResult { status = "eliminated", player = eliminated, random = leaders.Length > 1 };
            active.Remove(eliminated);
            stations.OnElimination(active);
            phase = active.Count <= capacity ? "end" : "result";
            remaining = phase == "end" ? 0 : 10;
        }
        public bool Command(string action, string value = null)
        {
            if (!active.Contains(HumanId)) return false;
            if (action == "reveal" && phase == "reveal" && Speaker == HumanId && !revealedThisTurn)
            {
                Card card = players[0].cards.FirstOrDefault(c => c.id == value && !c.revealed);
                if (card == null) return false;
                card.revealed = true; revealedThisTurn = true;
            }
            else if (action == "pass" && phase == "reveal" && Speaker == HumanId) NextSpeaker();
            else if (action == "vote" && phase == "vote" && active.Contains(value) &&
                     (candidates.Count == 0 || value == HumanId || candidates.Contains(value))) votes[HumanId] = value;
            else return false;
            revision++;
            return true;
        }
        public bool StationCommand(string actor, string action, string value = null)
        {
            if (!active.Contains(HumanId) || phase == "end") { LastError = "Действие сейчас недоступно"; return false; }
            if (!stations.Command(actor, action, value, round, active, out string error)) { LastError = error; return false; }
            LastError = null;
            revision++;
            return true;
        }

        // Returns true only on state changes; the caller can update its display clock separately.
        public bool Tick(float delta)
        {
            if (phase == "end" || delta <= 0) return false;
            bool changed = stations.Tick(delta);
            if (changed) revision++;
            remaining -= delta;
            while (remaining <= 0 && phase != "end")
            {
                float overdue = -remaining;
                if (phase == "reveal") NextSpeaker();
                else if (phase == "discussion") BeginVote();
                else if (phase == "vote") FinishVote();
                else if (phase == "result") { round++; stations.ChargeRound(active, scenario.weather); phase = "reveal"; speakerIndex = 0; remaining = 60; revealedThisTurn = false; botRevealed = false; }
                else break;
                if (phase != "end") remaining -= overdue;
                revision++; changed = true;
            }
            if (phase == "reveal" && Speaker != HumanId)
            {
                var bot = players.First(p => p.id == Speaker);
                if (remaining <= 58 && !botRevealed)
                {
                    var hidden = bot.cards.Where(c => !c.revealed).ToArray();
                    if (hidden.Length > 0) hidden[random.Next(hidden.Length)].revealed = true;
                    botRevealed = true; revealedThisTurn = true; revision++; changed = true;
                }
                if (remaining <= 55) { NextSpeaker(); revision++; changed = true; }
            }
            if (phase == "vote" && remaining <= 18 && !botsVoted)
            {
                var options = candidates.Count == 0 ? active : candidates;
                foreach (var bot in active.Where(p => p != HumanId)) votes[bot] = options[random.Next(options.Count)];
                botsVoted = true; revision++; changed = true;
            }
            return changed;
        }
        public MatchState Snapshot()
        {
            var visible = players.Select(p => new Player {
                id = p.id, name = p.name, appearance = p.appearance, bot = p.bot, seat = p.seat,
                cards = p.cards.Select(c => NewCard(c.id, c.label, p.id == HumanId || c.revealed ? c.value : null, c.revealed)).ToArray()
            }).ToArray();
            return new MatchState { revision = revision, scenario = scenario, players = visible, active = active.ToArray(),
                capacity = capacity, round = round, phase = phase, speaker = Speaker, remaining = Math.Max(0, remaining),
                revealed_this_turn = revealedThisTurn, candidates = candidates.ToArray(), second_ballot = secondBallot,
                my_vote = votes.TryGetValue(HumanId, out var target) ? target : null, result = result,
                stations = stations.Snapshot(HumanId) };
        }
    }
}
