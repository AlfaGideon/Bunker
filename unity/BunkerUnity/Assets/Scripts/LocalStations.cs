using System;
using System.Collections.Generic;
using System.Linq;

namespace Bunker.UnityPort
{
    [Serializable] public sealed class RadioContent
    {
        public RadioBroadcast[] broadcasts;
        public RadioSignal[] signals;
    }
    [Serializable] public sealed class RadioBroadcast { public string source, text; }
    [Serializable] public sealed class RadioSignal { public string title, text, effect; }

    // Local counterpart of the existing station rules. No network or Unity API.
    public sealed class LocalStations
    {
        private static readonly Dictionary<string, string[]> Roles = new Dictionary<string, string[]> {
            { "terminal", new[] { "Электрик", "Инженер-механик", "Связист", "Программист", "Техник вентиляции", "Энергетик", "Радиотехник", "Слесарь" } },
            { "gate", new[] { "Врач" } },
            { "medical", new[] { "Врач", "Фельдшер", "Медсестра", "Фармацевт", "Ветеринар", "Инструктор первой помощи" } },
            { "kitchen", new[] { "Повар", "Пекарь", "Технолог пищевого производства" } },
            { "supply", new[] { "Логист", "Спасатель", "Водитель", "Слесарь", "Электрик", "Инженер-механик" } },
            { "gym", new[] { "Тренер", "Спасатель", "Пожарный", "Инструктор первой помощи" } },
            { "workshop", new[] { "Инженер-механик", "Сварщик", "Слесарь", "Плотник", "Электрик" } },
            { "greenhouse", new[] { "Агроном", "Биолог", "Эколог", "Оператор теплицы", "Зоотехник" } }
        };
        private readonly List<Player> players;
        private readonly Dictionary<string, Stock> healthCosts;
        private readonly Dictionary<string, int> energies = new Dictionary<string, int>();
        private readonly Dictionary<string, int> usedFood = new Dictionary<string, int>();
        private readonly Dictionary<string, int> usedRest = new Dictionary<string, int>();
        private readonly Dictionary<string, int> usedRoom = new Dictionary<string, int>();
        private readonly HashSet<string> warehouseYes = new HashSet<string>();
        private readonly RadioContent data;
        private readonly List<RadioMessage> messages = new List<RadioMessage>();
        private readonly int capacity;
        private readonly Stock stock = new Stock { water = 100, food = 100, medicine = 32, filters = 24 };
        private int meals, medicines = 2, track, internet, signalIndex, scanRound, messageId, broadcastIndex;
        private bool medicalOpen, warehouseOpen, supplyTaken, systemsReady, shortage, powered = true;
        private string station = "aurora";
        private float nextBroadcast;

        public LocalStations(List<Player> participants, Dictionary<string, Stock> costs, int capacity, RadioContent radio)
        {
            players = participants; healthCosts = costs; this.capacity = capacity; data = radio;
            meals = capacity;
            foreach (var player in players) energies[player.id] = 60;
        }
        private static int Used(Dictionary<string, int> map, string key) => map.TryGetValue(key, out int used) ? used : 0;
        private bool HasRole(List<string> active, params string[] roles) => players.Any(p => active.Contains(p.id) && roles.Contains(p.cards[0].value));
        private static bool Fail(out string error, string text) { error = text; return false; }
        public void OnElimination(List<string> active)
        {
            warehouseYes.RemoveWhere(id => !active.Contains(id));
            if (!HasRole(active, "Врач")) medicalOpen = false;
        }
        public void ChargeRound(List<string> active, string weather)
        {
            var cost = new Stock { water = active.Count * 2, food = active.Count * 2 };
            if (weather == "heat") cost.water += active.Count;
            if (new[] { "radiation", "toxic", "volcano", "sand" }.Contains(weather)) cost.filters += 2;
            foreach (string id in active)
            {
                if (!healthCosts.TryGetValue(id, out var extra) || extra == null) continue;
                cost.water += extra.water; cost.food += extra.food; cost.medicine += extra.medicine; cost.filters += extra.filters;
            }
            shortage = cost.water > stock.water || cost.food > stock.food || cost.medicine > stock.medicine || cost.filters > stock.filters;
            stock.water = Math.Max(0, stock.water - cost.water); stock.food = Math.Max(0, stock.food - cost.food);
            stock.medicine = Math.Max(0, stock.medicine - cost.medicine); stock.filters = Math.Max(0, stock.filters - cost.filters);
            foreach (string id in active) energies[id] = Math.Max(0, energies[id] - (shortage ? 20 : 12));
        }
        public bool Command(string actor, string action, string value, int round, List<string> active, out string error)
        {
            error = null;
            var player = players.FirstOrDefault(p => p.id == actor && active.Contains(actor));
            if (player == null) return Fail(out error, "Участник недоступен");
            string role = player.cards[0].value;
            if (Roles.TryGetValue(action ?? "", out var allowed) && !allowed.Contains(role))
                return Fail(out error, "Профессия не подходит для этой станции");
            switch (action)
            {
                case "food":
                    if (Used(usedFood, actor) == round) return Fail(out error, "Участник уже ел в этом раунде");
                    if (meals <= 0) return Fail(out error, "Порции закончились");
                    meals--; usedFood[actor] = round; energies[actor] = Math.Min(100, energies[actor] + 10); break;
                case "rest":
                    if (Used(usedRest, actor) == round) return Fail(out error, "Участник уже отдыхал в этом раунде");
                    usedRest[actor] = round; energies[actor] = Math.Min(100, energies[actor] + (shortage ? 10 : 20)); break;
                case "gate":
                    if (round < 2) return Fail(out error, "Врач открывает медблок после первого раунда");
                    if (medicalOpen) return Fail(out error, "Медблок уже открыт");
                    medicalOpen = true; break;
                case "warehouse_gate":
                    if (warehouseOpen) return Fail(out error, "Склад уже открыт");
                    if (!warehouseYes.Add(actor)) return Fail(out error, "Участник уже проголосовал");
                    warehouseOpen = warehouseYes.Count > active.Count / 2; break;
                case "supply":
                    if (!warehouseOpen) return Fail(out error, "Склад закрыт до решения большинства");
                    if (supplyTaken) return Fail(out error, "Снабжение уже получено");
                    supplyTaken = true; stock.water += 20; stock.food += 15; stock.medicine += 5; stock.filters += 4; break;
                case "terminal":
                    if (systemsReady) return Fail(out error, "Системы уже восстановлены");
                    systemsReady = true; break;
                case "medical": case "kitchen": case "gym": case "workshop": case "greenhouse":
                    if (action == "medical" && !medicalOpen) return Fail(out error, "Медблок закрыт");
                    if (Used(usedRoom, action) == round) return Fail(out error, "Станция уже использована в этом раунде");
                    if (action == "medical")
                    {
                        if (medicines == 0) return Fail(out error, "Нет меднаборов");
                        medicines--; energies[actor] = Math.Min(100, energies[actor] + (shortage ? 5 : 15));
                    }
                    else if (action == "kitchen")
                    {
                        if (stock.food < 4 || stock.water < 2) return Fail(out error, "Недостаточно запасов для готовки");
                        stock.food -= 4; stock.water -= 2; meals += capacity + 2;
                    }
                    else if (action == "greenhouse")
                    {
                        if (stock.water < 3) return Fail(out error, "Недостаточно воды");
                        stock.water -= 3; stock.food += 4;
                    }
                    else if (action == "workshop") stock.filters += 2;
                    else energies[actor] = Math.Min(100, energies[actor] + 10);
                    usedRoom[action] = round; break;
                case "radio_power":
                    if (value != "on" && value != "off") return Fail(out error, "Некорректное значение радио");
                    powered = value == "on"; nextBroadcast = powered && station == "bunkers" ? 9 : 0; break;
                case "radio_tune":
                    if (!new[] { "aurora", "bunkers", "beacon", "internet" }.Contains(value)) return Fail(out error, "Неизвестная станция");
                    if (value == "beacon" && !HasRole(active, "Связист", "Радиотехник")) return Fail(out error, "Для маяка нужен специалист по связи");
                    bool same = powered && station == value;
                    if (same && value == "aurora") track = (track + 1) % 4;
                    if (same && value == "internet") internet = (internet + 1) % 4;
                    station = value; powered = true;
                    if (value == "bunkers" && !same) nextBroadcast = 9;
                    else if (value != "bunkers") nextBroadcast = 0;
                    break;
                case "radio_scan":
                    if (!HasRole(active, "Связист", "Радиотехник")) return Fail(out error, "Для маяка нужен специалист по связи");
                    if (!powered || station != "beacon") return Fail(out error, "Сначала включите маяк");
                    if (scanRound == round) return Fail(out error, "Маяк уже прочитан в этом раунде");
                    if (data?.signals == null || signalIndex >= data.signals.Length) return Fail(out error, "Передачи маяка закончились");
                    var signal = data.signals[signalIndex++]; scanRound = round;
                    if (signal.effect == "supplies") { stock.filters += 3; stock.food += 4; }
                    if (signal.effect == "stamina") foreach (var id in active) energies[id] = Math.Min(100, energies[id] + 15);
                    AddMessage(signal.title, signal.text); break;
                default: return Fail(out error, "Действие не реализовано");
            }
            return true;
        }
        private void AddMessage(string from, string text)
        {
            messages.Add(new RadioMessage { id = ++messageId, from = from, text = text });
            if (messages.Count > 24) messages.RemoveAt(0);
        }
        public bool Tick(float delta)
        {
            if (!powered || station != "bunkers" || data?.broadcasts == null || data.broadcasts.Length == 0 || nextBroadcast <= 0) return false;
            nextBroadcast -= Math.Max(delta, 0);
            if (nextBroadcast > 0) return false;
            var broadcast = data.broadcasts[broadcastIndex++ % data.broadcasts.Length];
            AddMessage(broadcast.source, broadcast.text); nextBroadcast = 20;
            return true;
        }
        public StationState Snapshot(string viewer)
        {
            return new StationState {
                meals = meals, medicines = medicines, medical_open = medicalOpen, warehouse_open = warehouseOpen,
                warehouse_votes = warehouseYes.Count, systems_ready = systemsReady, shortage = shortage,
                local_stamina = energies.TryGetValue(viewer, out int energy) ? energy : 0,
                stock = new Stock { water = stock.water, food = stock.food, medicine = stock.medicine, filters = stock.filters },
                radio = new RadioState { powered = powered, station = station, track_index = track, internet_index = internet,
                    scan_round = scanRound, signal_index = signalIndex, message_id = messageId,
                    received = messages.Select(m => new RadioMessage { id = m.id, from = m.from, text = m.text }).ToArray() }
            };
        }
    }
}
