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
