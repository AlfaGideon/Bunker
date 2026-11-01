using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Bunker.UnityPort;

static void Check(bool condition, string message)
{
    if (!condition) throw new Exception(message);
    Console.WriteLine("PASS " + message);
}
var localJsonOptions = new JsonSerializerOptions { IncludeFields = true };
var dataPath = Path.Combine("unity", "BunkerUnity", "Assets", "Resources");
var content = JsonSerializer.Deserialize<ContentData>(File.ReadAllText(Path.Combine(dataPath, "content.json")), localJsonOptions);
var scenarios = JsonSerializer.Deserialize<Scenario[]>(File.ReadAllText(Path.Combine(dataPath, "scenarios.json")), localJsonOptions);
var local = new LocalMatch(content, scenarios, 6, "Host", 123);
var localState = local.Snapshot();
Check(localState.players.Length == 6 && localState.players.All(p => p.cards.Count(c => c.revealed) == 1), "local 6-player setup and only public profession");
Check(localState.players[1].cards.Where(c => !c.revealed).All(c => c.value == null), "local opponents hidden");
local.Tick(12);
var ownCard = local.Snapshot().players[0].cards.First(c => !c.revealed);
Check(local.Command("reveal", ownCard.id) && local.Snapshot().remaining == 48, "local reveal preserves speech timer");
Check(!local.Command("reveal", ownCard.id), "local repeat reveal rejected");
Check(local.Command("pass"), "local speaker can pass");
for (int i = 0; i < 5; i++) local.Tick(5.1f);
Check(local.Snapshot().phase == "discussion" && Math.Abs(local.Snapshot().remaining - 60) < .1f, "local bots reveal and discussion starts at 60 seconds");
local.Tick(60);
Check(local.Snapshot().phase == "vote" && local.Snapshot().remaining == 20, "local ballot starts at 20 seconds");
Check(local.Command("vote", "local_1"), "local vote accepted");
local.Tick(3); local.Tick(17);
Check(local.Snapshot().phase == "result" || local.Snapshot().phase == "vote" || local.Snapshot().phase == "end", "local ballot resolves or enters runoff");
foreach (int size in new[] { 6, 8, 10 })
{
    var complete = new LocalMatch(content, scenarios, size, "Host", size);
    var initial = complete.Snapshot();
    Check(initial.players.Length == size && initial.players.Select(p => p.cards[0].value).Distinct().Count() == size,
        $"local {size} players have distinct professions");
    for (int tick = 0; tick < 6000 && complete.Snapshot().phase != "end"; tick++)
    {
        var view = complete.Snapshot();
        if (view.phase == "reveal" && view.speaker == LocalMatch.HumanId) complete.Command("pass");
        complete.Tick(1);
    }
    var final = complete.Snapshot();
    Check(final.phase == "end" && final.active.Length == size / 2, $"local {size} player game finishes at capacity");
}
var radioData = JsonSerializer.Deserialize<RadioContent>(File.ReadAllText(Path.Combine(dataPath, "radio.json")), localJsonOptions);
var fixedContent = new ContentData {
    professions = new[] { "Врач", "Повар", "Логист", "Связист", "Тренер", "Электрик" },
    ages = new[] { "30 лет" }, skills = new[] { "Ремонт" }, baggage = new[] { "Аптечка" },
    health = new[] { new HealthOption { label = "Диабет", cost = new Stock { medicine = 2, food = 1 } } },
    facts = new[] { "Факт" }, qualities = new[] { "Характер" }
};
var offline = new LocalMatch(fixedContent, new[] { new Scenario { title = "Жара", weather = "heat" } }, 6, "Игрок", 12, radioData);
var offlinePlayers = offline.Snapshot().players;
string WithRole(string role) => offlinePlayers.First(p => p.cards[0].value == role).id;
string cook = WithRole("Повар"), doctor = WithRole("Врач"), logistics = WithRole("Логист"), signalOperator = WithRole("Связист");
Check(!offline.StationCommand(doctor, "gate") && !offline.Snapshot().stations.medical_open, "offline medical locked in round one");
Check(!offline.StationCommand(doctor, "kitchen"), "offline profession validation");
Check(offline.StationCommand(cook, "kitchen") && offline.Snapshot().stations.meals == 8, "offline kitchen produces shared meals");
Check(!offline.StationCommand(cook, "kitchen"), "offline station cooldown");
Check(offline.StationCommand(LocalMatch.HumanId, "food") && offline.Snapshot().stations.local_stamina == 70, "offline food and stamina");
Check(!offline.StationCommand(LocalMatch.HumanId, "food"), "offline meal cooldown");
Check(offline.StationCommand(LocalMatch.HumanId, "rest") && offline.Snapshot().stations.local_stamina == 90, "offline rest and stamina");
foreach (var player in offlinePlayers.Take(4)) Check(offline.StationCommand(player.id, "warehouse_gate"), "offline warehouse vote");
Check(offline.Snapshot().stations.warehouse_open, "offline majority opens warehouse");
Check(offline.StationCommand(logistics, "supply") && !offline.StationCommand(logistics, "supply"), "offline supply granted once");
Check(offline.StationCommand(signalOperator, "radio_tune", "bunkers"), "offline radio tune");
offline.Tick(9);
Check(offline.Snapshot().stations.radio.received.Length == 1, "offline radio broadcast generated");
Check(offline.StationCommand(signalOperator, "radio_tune", "beacon"), "offline beacon tuned");
var beforeScan = offline.Snapshot().stations.stock;
Check(offline.StationCommand(signalOperator, "radio_scan") && offline.Snapshot().stations.stock.filters == beforeScan.filters + 3, "offline beacon applies reward");
Check(!offline.StationCommand(signalOperator, "radio_scan"), "offline beacon once per round");
var costs = offlinePlayers.ToDictionary(p => p.id, p => new Stock { medicine = 2, food = 1 });
var stationTest = new LocalStations(offlinePlayers.ToList(), costs, 3, radioData);
var activeIds = offlinePlayers.Select(p => p.id).ToList();
stationTest.ChargeRound(activeIds, "heat");
var charged = stationTest.Snapshot(LocalMatch.HumanId);
Check(charged.stock.water == 82 && charged.stock.food == 82 && charged.stock.medicine == 20 && charged.local_stamina == 48, "offline round consumption includes weather and hidden health");
Check(stationTest.Command(doctor, "gate", null, 2, activeIds, out _) && stationTest.Snapshot(LocalMatch.HumanId).medical_open, "offline doctor opens medical from round two");
activeIds.Remove(doctor); stationTest.OnElimination(activeIds);
Check(!stationTest.Snapshot(LocalMatch.HumanId).medical_open, "offline medical closes after doctor eliminated");
var output = new FakeRadioOutput();
var playback = new RadioPlayback(output);
var radioSnapshot = new RadioState { powered = true, station = "aurora", track_index = 0, message_id = 1,
    received = new[] { new RadioMessage { id = 1, from = "Старый", text = "История" } } };
playback.Sync(radioSnapshot);
Check(output.music.SequenceEqual(new[] { 0 }) && output.spoken.Count == 0, "radio starts music but does not replay history");
playback.Sync(radioSnapshot);
Check(output.music.Count == 1, "repeated snapshots do not restart music");
radioSnapshot.track_index = 2; playback.Sync(radioSnapshot);
Check(output.music.Last() == 2, "radio track change");
radioSnapshot.station = "bunkers"; radioSnapshot.message_id = 3;
radioSnapshot.received = new[] { new RadioMessage { id = 3, from = "Третий", text = "Три" }, new RadioMessage { id = 2, from = "Второй", text = "Два" } };
playback.Sync(radioSnapshot); playback.Sync(radioSnapshot);
Check(output.music.Last() == -1 && output.spoken.SequenceEqual(new[] { "Второй. Два", "Третий. Три" }), "new broadcasts ordered and spoken once");
playback.Pause(); radioSnapshot.message_id = 4; radioSnapshot.received = new[] { new RadioMessage { id = 4, text = "Пауза" } }; playback.Sync(radioSnapshot);
playback.Resume(); playback.Sync(radioSnapshot);
Check(output.spoken.Count == 2, "background messages are not replayed");
radioSnapshot.station = "beacon"; radioSnapshot.message_id = 5; radioSnapshot.received = new[] { new RadioMessage { id = 5, text = "Маяк" } }; playback.Sync(radioSnapshot);
Check(output.spoken.Last() == "Маяк", "beacon message narrated");
radioSnapshot.powered = false; radioSnapshot.message_id = 6; radioSnapshot.received = new[] { new RadioMessage { id = 6, text = "Выключено" } }; playback.Sync(radioSnapshot);
Check(output.spoken.Count == 3 && output.music.Last() == -1, "radio off silences playback");
playback.Reset(); radioSnapshot.powered = true; radioSnapshot.station = "aurora"; radioSnapshot.track_index = 1; playback.Sync(radioSnapshot);
Check(output.music.Last() == 1 && output.spoken.Count == 3, "new match resets history and starts music");
var root = Environment.GetEnvironmentVariable("BUNKER_TEST_URL") ?? "http://127.0.0.1:8080";
Check(LobbyTransport.TryNormalize("wss://example.org/ws", false, out var normalized) && normalized == "https://example.org", "wss normalized to HTTPS");
Check(!LobbyTransport.TryNormalize("http://example.org", false, out _), "device rejects HTTP");
Check(LobbyTransport.TryNormalize(root, true, out _), "editor local URL accepted");
Check(!LobbyTransport.TryNormalize("https://user:password@example.org/ws", false, out _), "credentials rejected");
Check(!LobbyTransport.TryNormalize("https://example.org/other", false, out _), "unexpected paths rejected");

var json = new JsonSerializerOptions { IncludeFields = true };
using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
var tokens = new List<string>();
async Task<string> Post(string action, object payload, string token = null)
{
    using var request = new HttpRequestMessage(HttpMethod.Post, root + "/transport/" + action);
    request.Content = new StringContent(JsonSerializer.Serialize(payload, payload.GetType(), json), Encoding.UTF8, "application/json");
    if (token != null) request.Headers.Add("X-Lobby-Session", token);
    using var response = await client.SendAsync(request);
    var body = await response.Content.ReadAsStringAsync();
    if (!response.IsSuccessStatusCode) throw new Exception($"{action}: {response.StatusCode} {body}");
    return body;
}
async Task<string> Open()
{
    var data = JsonSerializer.Deserialize<SessionResponse>(await Post("open", new { }), json);
    if (data == null || string.IsNullOrEmpty(data.session)) throw new Exception("no token");
    tokens.Add(data.session);
    return data.session;
}
async Task<LobbyEvent[]> Send(string token, Command command)
{
    var envelope = JsonSerializer.Deserialize<Envelope>(await Post("send", command, token), json);
    return envelope.events;
}
async Task<LobbyEvent[]> Poll(string token)
{
    var envelope = JsonSerializer.Deserialize<Envelope>(await Post("poll", new { }, token), json);
    return envelope.events;
}
try
{
    var host = await Open();
    var hostJoin = (await Send(host, new Command { type = "create", name = "Host", skin = "male", title = "Test", capacity = 6 })).First(e => e.type == "joined");
    var guest = await Open();
    var guestJoin = (await Send(guest, new Command { type = "join", name = "Guest", skin = "female", room_id = hostJoin.room.id })).First(e => e.type == "joined");
    for (int i = 0; i < 4; i++) await Send(host, new Command { type = "add_bot" });
    var hostStart = await Send(host, new Command { type = "online_start" });
    var hostState = hostStart.First(e => e.type == "game_state").state;
    var guestState = (await Poll(guest)).Last(e => e.type == "game_state").state;
    Check(hostState.players.Length == 6 && guestState.players.Length == 6, "two clients receive full room");
    var privateCard = guestState.players.First(p => p.id == hostJoin.player_id).cards.First(c => !c.revealed);
    Check(privateCard.value == null, "other player's hidden characteristic not sent");
    Check(hostState.players.First(p => p.id == hostJoin.player_id).cards.Count(c => c.revealed) == 1, "only profession public initially");
    var hostCard = hostState.players.First(p => p.id == hostJoin.player_id).cards.First(c => !c.revealed);
    await Send(host, new Command { type = "game_action", action = "reveal", value = hostCard.id });
    guestState = (await Poll(guest)).Last(e => e.type == "game_state").state;
    Check(guestState.players.First(p => p.id == hostJoin.player_id).cards.First(c => c.id == hostCard.id).revealed, "reveal reaches guest");
    await Send(host, new Command { type = "game_action", action = "food" });
    guestState = (await Poll(guest)).Last(e => e.type == "game_state").state;
    Check(guestState.stations.meals == 2, "server food shared across clients");
    await Send(guest, new Command { type = "game_action", action = "radio_tune", value = "bunkers" });
    hostState = (await Poll(host)).Last(e => e.type == "game_state").state;
    Check(hostState.stations.radio.station == "bunkers", "radio setting shared across clients");
    var radioPower = JsonSerializer.Serialize(new BooleanCommand { action = "radio_power", value = false }, json);
    Check(radioPower.Contains("\"value\":false"), "radio power uses JSON boolean");
    Console.WriteLine("Protocol compile and server integration passed. Unity engine and APK are NOT tested here.");
}
finally
{
    foreach (var token in tokens)
        try { await Post("close", new { }, token); } catch { }
}

sealed class FakeRadioOutput : IRadioOutput
{
    public readonly List<int> music = new();
    public readonly List<string> spoken = new();
    public int cancels;
    public void Music(int index) => music.Add(index);
    public void Speak(string text) => spoken.Add(text);
    public void CancelSpeech() => cancels++;
}
