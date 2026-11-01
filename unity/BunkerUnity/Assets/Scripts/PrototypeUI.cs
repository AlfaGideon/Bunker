using System;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Bunker.UnityPort
{
    // Deliberately a protocol test surface, not the finished 3D game.
    // All match actions are commands; no server state is mutated locally.
    public sealed class PrototypeUI : MonoBehaviour
    {
        private LobbyTransport transport;
        private RadioAudio radioAudio;
        private Canvas canvas;
        private Font font;
        private RectTransform page;
        private Text statusText, timerText;
        private InputField addressInput, nameInput, roomInput;
        private string status = "Unity-перенос: сетевой тест, не готовая игра";
        private string address = "https://alfagideon.blitz.cloud";
        private string nickname = "Игрок";
        private string roomCode = "";
        private string playerId = "", selectedId = "";
        private int capacity = 6;
        private Room room;
        private Room[] rooms = Array.Empty<Room>();
        private MatchState state;
        private LocalMatch localMatch;
        private float localRemaining;
        private bool stationsPage;
        private bool radioPage;
        private string screen = "home";
#if UNITY_5_3_OR_NEWER
        private World.BunkerWorld world;
        private World.CampWorld camp;
        private CanvasGroup fadingMenu;
        private bool campFailed;
        private int outfit;
#endif

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Create()
        {
            if (FindObjectOfType<PrototypeUI>() != null) return;
            var root = new GameObject("BunkerUnityPrototype");
            root.AddComponent<PrototypeUI>();
        }

        private void Start()
        {
            Screen.orientation = ScreenOrientation.LandscapeLeft;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            font = Resources.GetBuiltinResource<Font>("Arial.ttf");
            address = PlayerPrefs.GetString("bunker.server", address);
            nickname = PlayerPrefs.GetString("bunker.nickname", nickname);
#if UNITY_5_3_OR_NEWER
            int.TryParse(PlayerPrefs.GetString("bunker.outfit", "0"), out outfit);
#endif
            radioAudio = gameObject.AddComponent<RadioAudio>();
            transport = gameObject.AddComponent<LobbyTransport>();
            transport.Status += OnStatus;
            transport.Event += OnEvent;
            if (FindObjectOfType<EventSystem>() == null)
                new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
            var canvasObject = new GameObject("Canvas", typeof(RectTransform), typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280, 720);
            scaler.matchWidthOrHeight = 0.5f;
            Draw();
        }

        private void OnDestroy()
        {
            if (transport != null) { transport.Status -= OnStatus; transport.Event -= OnEvent; }
        }

        private void Update()
        {
#if UNITY_5_3_OR_NEWER
            if (screen == "loading" && fadingMenu != null && camp != null)
                fadingMenu.alpha = Mathf.Clamp01(1f - camp.TransitionProgress * 3f);
#endif
            if (state == null || (screen != "game" && screen != "world")) return;
            radioAudio.Restore(state.stations?.radio);
            if (localMatch != null && localMatch.Tick(Time.unscaledDeltaTime))
            {
                state = localMatch.Snapshot();
                localRemaining = state.remaining;
                Draw();
            }
            else localRemaining = Mathf.Max(0, localRemaining - Time.unscaledDeltaTime);
            if (timerText != null) timerText.text = PhaseName(state.phase) + "  ·  " + Mathf.CeilToInt(localRemaining) + " с";
        }

        private void OnStatus(string message)
        {
            status = message;
            if (statusText != null) statusText.text = status;
            if (transport.Connected && (screen == "home" || screen == "network") && message == "Подключено")
            {
                transport.Send(new Command { type = "list" });
                Draw();
            }
            else if (!transport.Connected && (message.StartsWith("Ошибка") || message == "Соединение закрыто"))
            {
                radioAudio.ResetRadio(); screen = "home"; room = null; state = null; playerId = ""; selectedId = ""; rooms = Array.Empty<Room>(); Draw();
            }
        }

        private void OnEvent(LobbyEvent item)
        {
            switch (item.type)
            {
                case "error": status = "Сервер: " + ErrorName(item.code); Draw(); break;
                case "rooms": rooms = item.rooms ?? Array.Empty<Room>(); if (screen == "home" || screen == "network") Draw(); break;
                case "joined":
                    radioAudio.ResetRadio(); localMatch = null; playerId = item.player_id; room = item.room; state = null; screen = "room";
                    status = "Комната создана или подключена"; Draw(); break;
                case "room": room = item.room; if (screen == "room") Draw(); break;
                case "online_game_start": status = "Партия запускается…"; break;
                case "game_state":
                    if (item.state == null || item.state.players == null) break;
                    if (state != null && item.state.revision < state.revision) break;
                    bool newMatch = state == null;
                    state = item.state; localRemaining = state.remaining; if (screen != "world" && screen != "loading") screen = "game";
                    if (string.IsNullOrEmpty(selectedId)) selectedId = playerId;
#if UNITY_5_3_OR_NEWER
                    if (newMatch) { BeginLaunch(OpenWorld); break; }
                    if (screen == "loading") break;
#endif
                    Draw(); break;
                case "room_closed":
                    radioAudio.ResetRadio(); room = null; state = null; playerId = ""; screen = "home";
                    status = "Комната закрыта: " + item.reason; Draw(); break;
                case "left": radioAudio.ResetRadio(); room = null; state = null; playerId = ""; screen = "home"; Draw(); break;
            }
        }

        private static string ErrorName(string code)
        {
            switch (code)
            {
                case "unknown_game_action": return "сервер устарел, обновите его из main";
                case "not_enough_players": return "нужно заполнить комнату";
                case "host_only": return "действие доступно только ведущему";
                case "wrong_profession": return "профессия не подходит";
                case "station_used": return "станция уже использована в этом раунде";
                case "already_ate": return "вы уже ели в этом раунде";
                case "already_rested": return "вы уже отдыхали в этом раунде";
                case "no_meals": return "готовые порции закончились";
                case "medical_first_round": return "врач может открыть медблок после первого раунда";
                case "medical_closed": return "медблок закрыт";
                case "warehouse_closed": return "склад закрыт";
                case "radio_specialist_required": return "для маяка нужен связист или радиотехник";
                default: return code ?? "неизвестная ошибка";
            }
        }

        private void Draw()
        {
            if (canvas == null) return;
            if ((screen == "game" || screen == "world") && state != null) radioAudio.Restore(state.stations?.radio);
#if UNITY_5_3_OR_NEWER
            if (world != null) world.gameObject.SetActive(screen == "world");
            bool needsCamp = screen == "home" || screen == "network" || screen == "profile" || screen == "loading" || screen == "room";
            if (needsCamp && camp == null && !campFailed)
            {
                try { camp = World.CampWorld.Create(); camp.SetOutfit(outfit); }
                catch (Exception ex) { campFailed = true; status = "Лагерь не загрузился: " + ex.Message; }
            }
            if (camp != null) camp.gameObject.SetActive(needsCamp);
#endif
            if (page != null) { page.gameObject.SetActive(false); Destroy(page.gameObject); }
            page = Rect("Page", canvas.transform, 0, 0, 1, 1);
#if UNITY_5_3_OR_NEWER
            if (screen == "world") { DrawWorld(); return; }
#endif
#if UNITY_5_3_OR_NEWER
            if (camp == null || (screen != "home" && screen != "network" && screen != "profile" && screen != "room"))
#endif
                Panel(page, 0, 0, 1, 1, new Color(0.025f, 0.055f, 0.065f));
            Label(page, "Б У Н К Е Р  ·  ПОСЛЕДНИЙ ШЛЮЗ", 0.025f, 0.93f, 0.70f, 0.985f, 23, TextAnchor.MiddleLeft);
            statusText = Label(page, status, 0.025f, 0.012f, 0.975f, 0.07f, 16, TextAnchor.MiddleLeft);
            if (screen == "home") DrawHome();
            else if (screen == "network") DrawNetwork();
            else if (screen == "profile") DrawProfile();
            else if (screen == "room") DrawRoom();
            else if (screen == "game") DrawGame();
        }

        private void DrawHome()
        {
            Panel(page, .025f, .16f, .30f, .78f, new Color(.055f, .043f, .035f, .86f));
            Label(page, nickname, .05f, .69f, .27f, .76f, 18, TextAnchor.MiddleLeft);
            Button(page, "НАЧАТЬ ИГРУ", .05f, .56f, .27f, .66f, () => {
#if UNITY_5_3_OR_NEWER
                BeginLaunch(StartLocal);
#else
                StartLocal();
#endif
            }, 17);
            Button(page, "ИГРОКОВ: " + capacity, .05f, .45f, .27f, .53f, () => { capacity = capacity == 6 ? 8 : capacity == 8 ? 10 : 6; Draw(); }, 14);
            Button(page, "ИНТЕРНЕТ", .05f, .34f, .27f, .42f, () => { screen = "network"; Draw(); }, 14);
            Button(page, "ПРОФИЛЬ", .05f, .23f, .27f, .31f, () => { screen = "profile"; Draw(); }, 14);
        }
        private void DrawProfile()
        {
            Panel(page, .025f, .24f, .32f, .75f, new Color(.055f, .043f, .035f, .88f));
            Label(page, "ИМЯ ИГРОКА", .05f, .63f, .29f, .70f, 17, TextAnchor.MiddleLeft);
            nameInput = Input(page, nickname, .05f, .52f, .29f, .61f, value => nickname = value);
#if UNITY_5_3_OR_NEWER
            Button(page, "ОДЕЖДА: " + (outfit + 1) + " / 3", .05f, .40f, .29f, .50f, () => {
                outfit = (outfit + 1) % 3; if (camp != null) camp.SetOutfit(outfit); Draw();
            }, 13);
#else
            Label(page, "Внешность пока не поддерживается", .05f, .40f, .29f, .50f, 13, TextAnchor.MiddleLeft);
#endif
            Button(page, "СОХРАНИТЬ", .05f, .29f, .29f, .38f, () => { PlayerPrefs.SetString("bunker.nickname", nickname);
#if UNITY_5_3_OR_NEWER
                PlayerPrefs.SetString("bunker.outfit", outfit.ToString());
#endif
                PlayerPrefs.Save(); screen = "home"; Draw(); }, 14);
        }
        private void DrawNetwork()
        {
            Button(page, "НАЗАД", .82f, .93f, .97f, .985f, () => { screen = "home"; Draw(); }, 13);
            Panel(page, .02f, .11f, .49f, .90f, new Color(.045f, .04f, .035f, .88f));
            Label(page, "СЕТЕВОЙ ТЕСТ · НЕ ПОЛНАЯ ИГРА", .04f, .81f, .47f, .88f, 18, TextAnchor.MiddleLeft);
            Label(page, "Адрес сервера", .04f, .75f, .47f, .80f, 15, TextAnchor.MiddleLeft);
            addressInput = Input(page, address, .04f, .68f, .47f, .75f, value => address = value);
            Label(page, "Имя игрока", .04f, .62f, .47f, .67f, 15, TextAnchor.MiddleLeft);
            nameInput = Input(page, nickname, .04f, .55f, .47f, .62f, value => nickname = value);
            if (!transport.Connected)
                Button(page, "ПОДКЛЮЧИТЬСЯ", .04f, .42f, .47f, .52f, () => {
                    PlayerPrefs.SetString("bunker.server", address); PlayerPrefs.SetString("bunker.nickname", nickname); PlayerPrefs.Save();
                    transport.Open(address);
                });
            else
            {
                Button(page, "СОЗДАТЬ КОМНАТУ · " + capacity, .04f, .43f, .33f, .52f, () => {
                    transport.Send(new Command { type = "create", name = nickname, title = "Бункер", capacity = capacity, skin = "male" });
                });
                Button(page, "6 / 8 / 10", .34f, .43f, .47f, .52f, () => { capacity = capacity == 6 ? 8 : capacity == 8 ? 10 : 6; Draw(); });
                roomInput = Input(page, roomCode, .04f, .30f, .32f, .39f, value => roomCode = value);
                Button(page, "ВОЙТИ ПО КОДУ", .33f, .30f, .47f, .39f, () => Join(roomCode));
                Button(page, "ОБНОВИТЬ СПИСОК", .04f, .16f, .27f, .25f, () => transport.Send(new Command { type = "list" }));
                Button(page, "ОТКЛЮЧИТЬСЯ", .29f, .16f, .47f, .25f, () => { transport.Close(); Draw(); });
            }
            Panel(page, .51f, .11f, .98f, .90f, new Color(.045f, .04f, .035f, .88f));
            if (!transport.Connected)
            {
                Button(page, "ЛОКАЛЬНЫЙ ТЕСТ РАУНДОВ", .53f, .16f, .81f, .25f, StartLocal, 13);
                Button(page, "ИГРОКИ: " + capacity, .82f, .16f, .96f, .25f, () => { capacity = capacity == 6 ? 8 : capacity == 8 ? 10 : 6; Draw(); }, 13);
            }
            Label(page, "ОТКРЫТЫЕ КОМНАТЫ", .53f, .81f, .96f, .88f, 20, TextAnchor.MiddleLeft);
            if (rooms.Length == 0) Label(page, "Пока нет комнат", .53f, .70f, .96f, .78f, 17, TextAnchor.MiddleLeft);
            for (int i = 0; i < Math.Min(6, rooms.Length); i++)
            {
                var found = rooms[i]; float top = .79f - i * .095f;
                Button(page, found.title + "  " + found.count + "/" + found.capacity, .53f, top - .08f, .96f, top, () => Join(found.id));
            }
        }
        private void StartLocal()
        {
            var content = Resources.Load<TextAsset>("content");
            var scenarios = Resources.Load<TextAsset>("scenarios");
            var radio = Resources.Load<TextAsset>("radio");
            if (content == null || scenarios == null || radio == null) { status = "Не найдены игровые данные"; Draw(); return; }
            try
            {
                var pool = JsonUtility.FromJson<ContentData>(content.text);
                var list = JsonUtility.FromJson<ScenarioList>("{\"items\":" + scenarios.text + "}");
                var radioData = JsonUtility.FromJson<RadioContent>(radio.text);
                radioAudio.ResetRadio();
                localMatch = new LocalMatch(pool, list.items, capacity, nickname, Environment.TickCount, radioData);
                playerId = LocalMatch.HumanId; selectedId = playerId;
                state = localMatch.Snapshot(); localRemaining = state.remaining;
                screen = "game"; stationsPage = false; radioPage = false;
                status = "Локальная партия";
#if UNITY_5_3_OR_NEWER
                OpenWorld();
#else
                Draw();
#endif
            }
            catch (Exception ex) { status = "Не удалось загрузить данные: " + ex.Message; Draw(); }
        }
        private void Join(string id)
        {
            transport.Send(new Command { type = "join", room_id = (id ?? "").Trim(), name = nickname, skin = "male" });
        }
        private void DrawRoom()
        {
            if (room == null) return;
            Panel(page, .03f, .11f, .97f, .90f, new Color(.055f, .12f, .14f));
            Label(page, room.title + "  ·  " + room.count + "/" + room.capacity + "  ·  Код: " + room.id, .06f, .78f, .92f, .87f, 22, TextAnchor.MiddleLeft);
            var members = room.players ?? Array.Empty<Member>();
            for (int i = 0; i < members.Length && i < 10; i++)
            {
                int col = i / 5, row = i % 5;
                float left = .06f + col * .38f, top = .75f - row * .105f;
                Label(page, (members[i].bot ? "◌  " : "●  ") + members[i].name, left, top - .08f, left + .34f, top, 18, TextAnchor.MiddleLeft);
            }
            if (room.host_id == playerId)
            {
                Button(page, "+ БОТ", .78f, .65f, .94f, .73f, () => transport.Send(new Command { type = "add_bot" }));
                Button(page, "− БОТ", .78f, .54f, .94f, .62f, () => transport.Send(new Command { type = "remove_bot" }));
                Button(page, "НАЧАТЬ", .78f, .43f, .94f, .51f, () => transport.Send(new Command { type = "online_start" }));
            }
            Button(page, "ПОКИНУТЬ", .78f, .16f, .94f, .25f, () => transport.Send(new Command { type = "leave" }));
        }
        private void Action(string action, string value = null)
        {
            if (localMatch != null)
            {
                bool isTurnAction = action == "reveal" || action == "pass" || action == "vote";
                bool accepted = isTurnAction ? localMatch.Command(action, value) : localMatch.StationCommand(selectedId, action, value);
                status = accepted ? "Действие выполнено" : (isTurnAction ? "Действие сейчас недоступно" : (localMatch.LastError ?? "Действие сейчас недоступно"));
                state = localMatch.Snapshot(); localRemaining = state.remaining; Draw(); return;
            }
            if (!transport.Send(new Command { type = "game_action", action = action, value = value }))
            { status = "Нет соединения"; Draw(); }
        }
#if UNITY_5_3_OR_NEWER
        private void BeginLaunch(Action callback)
        {
            if (screen == "loading") return;
            if (camp == null) { callback(); return; }
            screen = "loading";
            fadingMenu = page.gameObject.AddComponent<CanvasGroup>();
            fadingMenu.interactable = false; fadingMenu.blocksRaycasts = false;
            camp.BeginTransition(() => { fadingMenu = null; callback(); });
        }
        private void OpenWorld()
        {
            try
            {
                if (world == null)
                {
                    world = World.BunkerWorld.Create();
                    world.PlayerSelected += id => { selectedId = id; stationsPage = false; radioPage = false; screen = "game"; Draw(); };
                    world.ActionRequested += action => {
                        selectedId = playerId;
                        if (action == "radio") { screen = "game"; stationsPage = true; radioPage = true; Draw(); }
                        else if (action == "exit") { status = "Выходной шлюз откроется при исключении — пока не подключено"; Draw(); }
                        else Action(action);
                    };
                }
                world.SyncPlayers(state.players, playerId);
                screen = "world";
                Draw();
            }
            catch (Exception ex)
            {
                if (world != null) { Destroy(world.gameObject); world = null; }
                status = "Не удалось открыть 3D-тест: " + ex.Message;
                screen = "game"; Draw();
            }
        }
        private void DrawWorld()
        {
            if (world == null || state == null) { screen = "game"; Draw(); return; }
            world.SyncPlayers(state.players, playerId);
            world.SyncLayout(state.seed);
            world.SyncStations(state.stations);
            Button(page, "КАРТОЧКИ И ХОД", .66f, .92f, .84f, .99f, () => { screen = "game"; Draw(); }, 12);
            Button(page, "ВИД", .85f, .92f, .98f, .99f, () => world.ToggleView(), 13);
            timerText = Label(page, "", .02f, .92f, .39f, .99f, 18, TextAnchor.MiddleLeft);
            statusText = Label(page, status + " · движение не синхронизируется", .02f, .01f, .65f, .06f, 13, TextAnchor.MiddleLeft);
        }
#endif
        private void DrawGame()
        {
            if (state == null) return;
#if UNITY_5_3_OR_NEWER
            Button(page, "3D · ТЕСТ", .68f, .93f, .81f, .985f, OpenWorld, 13);
#endif
            Button(page, "В МЕНЮ", .82f, .93f, .97f, .985f, () => {
                if (localMatch != null) { radioAudio.ResetRadio(); localMatch = null; state = null; playerId = ""; selectedId = ""; screen = "home"; status = "Локальный тест завершён"; Draw(); }
                else transport.Send(new Command { type = "leave" });
            }, 13);
            Panel(page, .02f, .09f, .30f, .90f, new Color(.055f, .12f, .14f));
            Panel(page, .32f, .09f, .98f, .90f, new Color(.055f, .12f, .14f));
            timerText = Label(page, "", .04f, .81f, .28f, .88f, 18, TextAnchor.MiddleLeft);
            string roundTitle = "Раунд " + state.round + " · " + (state.scenario?.title ?? "");
            if (state.result != null && (state.phase == "result" || state.phase == "end"))
            {
                var eliminated = (state.players ?? Array.Empty<Player>()).FirstOrDefault(p => p.id == state.result.player);
                if (eliminated != null) roundTitle += " · Выбыл: " + eliminated.name;
            }
            Label(page, roundTitle, .34f, .82f, .96f, .88f, 19, TextAnchor.MiddleLeft);
            var players = state.players ?? Array.Empty<Player>();
            for (int i = 0; i < players.Length && i < 10; i++)
            {
                Player p = players[i]; float top = .78f - i * .057f;
                bool alive = (state.active ?? Array.Empty<string>()).Contains(p.id);
                string tag = p.id == state.speaker ? "▶ " : alive ? "● " : "× ";
                Button(page, tag + p.name, .04f, top - .052f, .28f, top, () => { selectedId = p.id; stationsPage = false; radioPage = false; Draw(); }, 14);
            }
            Button(page, "КАРТОЧКА", .04f, .14f, .155f, .20f, () => { stationsPage = false; radioPage = false; Draw(); }, 13);
            Button(page, "СТАНЦИИ", .165f, .14f, .28f, .20f, () => { stationsPage = true; radioPage = false; Draw(); }, 13);
            if (stationsPage) { DrawStations(); return; }
            Player selected = players.FirstOrDefault(p => p.id == selectedId);
            if (selected == null) return;
            Label(page, selected.name + (selected.id == playerId ? " · ВЫ" : ""), .34f, .75f, .95f, .81f, 20, TextAnchor.MiddleLeft);
            var cards = selected.cards ?? Array.Empty<Card>();
            for (int i = 0; i < cards.Length && i < 7; i++)
            {
                Card card = cards[i]; float top = .74f - i * .075f;
                bool own = selected.id == playerId;
                string value = card.revealed || own ? (card.value ?? "—") : "СКРЫТО";
                Label(page, (card.revealed ? "●  " : "🔒  ") + card.label + ": " + value, .35f, top - .067f, .80f, top, 16, TextAnchor.MiddleLeft);
                if (own && !card.revealed && state.phase == "reveal" && state.speaker == playerId && !state.revealed_this_turn)
                    Button(page, "ОТКРЫТЬ", .81f, top - .064f, .95f, top, () => Action("reveal", card.id), 13);
            }
            if (state.phase == "reveal" && state.speaker == playerId)
                Button(page, "ПЕРЕДАТЬ ХОД", .72f, .12f, .95f, .19f, () => Action("pass"));
            else if (state.phase == "vote" && (state.active ?? Array.Empty<string>()).Contains(selected.id))
                Button(page, "ГОЛОСОВАТЬ: " + selected.name, .67f, .12f, .95f, .19f, () => Action("vote", selected.id), 13);
            else if (state.phase == "vote")
                Label(page, "Выберите участника для голосования", .43f, .12f, .95f, .19f, 14, TextAnchor.MiddleRight);
        }
        private void DrawStations()
        {
            if (state.stations == null)
            {
                Label(page, localMatch != null ? "Станции ещё не перенесены в локальный тест." : "Сервер не поддерживает станции: обновите сервер.", .35f, .57f, .95f, .70f, 18, TextAnchor.MiddleLeft);
                return;
            }
            var st = state.stations;
            string stock = st.stock == null ? "" : "Вода " + st.stock.water + " · Еда " + st.stock.food + " · Лекарства " + st.stock.medicine + " · Фильтры " + st.stock.filters;
            Label(page, "Порции: " + st.meals + "   " + stock + (localMatch != null ? " · Бодрость " + st.local_stamina : ""), .35f, .75f, .95f, .81f, 16, TextAnchor.MiddleLeft);
            if (radioPage) { DrawRadio(st.radio); return; }
            string[] labels = { "ПОЕСТЬ", "ОТДЫХ", "ТЕРМИНАЛ", "МЕДБЛОК · ДВЕРЬ", "МЕДОСМОТР", "КУХНЯ", "СКЛАД · ГОЛОС", "СНАБЖЕНИЕ", "СПОРТЗАЛ", "МАСТЕРСКАЯ", "ТЕПЛИЦА", "РАДИО" };
            string[] actions = { "food", "rest", "terminal", "gate", "medical", "kitchen", "warehouse_gate", "supply", "gym", "workshop", "greenhouse", "radio" };
            for (int i = 0; i < labels.Length; i++)
            {
                int index = i, col = i % 3, row = i / 3;
                float left = .35f + col * .20f, top = .70f - row * .13f;
                Button(page, labels[i], left, top - .10f, left + .19f, top,
                    () => { if (actions[index] == "radio") { radioPage = true; Draw(); } else Action(actions[index]); }, 13);
            }
            var actor = (state.players ?? Array.Empty<Player>()).FirstOrDefault(p => p.id == selectedId);
            Label(page, localMatch != null ? "Исполнитель: " + (actor?.name ?? "—") + ". Выберите его слева." : "Тест: движение и доступ к комнатам пока не перенесены.", .35f, .13f, .95f, .19f, 13, TextAnchor.MiddleLeft);
        }
        private void DrawRadio(RadioState radio)
        {
            if (radio == null) { Label(page, "Нет данных радио", .35f, .55f, .95f, .65f, 18, TextAnchor.MiddleLeft); return; }
            Label(page, (radio.powered ? "ВКЛЮЧЕНО" : "ВЫКЛЮЧЕНО") + " · " + radio.station, .35f, .67f, .95f, .74f, 18, TextAnchor.MiddleLeft);
            string[] labels = { "АВРОРА", "БУНКЕРЫ", "МАЯК", "ИНТЕРНЕТ" };
            string[] ids = { "aurora", "bunkers", "beacon", "internet" };
            for (int i = 0; i < labels.Length; i++)
            {
                int index = i; float left = .35f + i * .15f;
                Button(page, labels[i], left, .54f, left + .14f, .64f, () => Action("radio_tune", ids[index]), 13);
            }
            Button(page, radio.powered ? "ВЫКЛЮЧИТЬ" : "ВКЛЮЧИТЬ", .35f, .43f, .54f, .51f, () => { if (localMatch != null) Action("radio_power", radio.powered ? "off" : "on"); else transport.SendRadioPower(!radio.powered); }, 13);
            Button(page, "СКАНИРОВАТЬ", .55f, .43f, .74f, .51f, () => Action("radio_scan"), 13);
            Button(page, "НАЗАД", .75f, .43f, .94f, .51f, () => { radioPage = false; Draw(); }, 13);
            var received = radio.received ?? Array.Empty<RadioMessage>();
            string text = received.Length == 0 ? "Передач пока нет" : received[received.Length - 1].from + ": " + received[received.Length - 1].text;
            Label(page, text + "\n" + radioAudio.VoiceStatus + (radio.station == "internet" ? " · Интернет-аудио ещё не перенесено" : ""), .35f, .17f, .94f, .39f, 14, TextAnchor.UpperLeft);
        }
        private static string PhaseName(string phase)
        {
            switch (phase) { case "reveal": return "Выступление"; case "discussion": return "Обсуждение"; case "vote": return "Голосование"; case "result": return "Результат"; case "end": return "Итог"; default: return phase ?? ""; }
        }
        private static RectTransform Rect(string name, Transform parent, float x1, float y1, float x2, float y2)
        {
            var obj = new GameObject(name, typeof(RectTransform));
            var rect = obj.GetComponent<RectTransform>(); rect.SetParent(parent, false);
            rect.anchorMin = new Vector2(x1, y1); rect.anchorMax = new Vector2(x2, y2);
            rect.offsetMin = Vector2.zero; rect.offsetMax = Vector2.zero;
            return rect;
        }
        private static void Panel(Transform parent, float x1, float y1, float x2, float y2, Color color)
        {
            var rect = Rect("Panel", parent, x1, y1, x2, y2);
            rect.gameObject.AddComponent<Image>().color = color;
        }
        private Text Label(Transform parent, string text, float x1, float y1, float x2, float y2, int size, TextAnchor alignment)
        {
            var rect = Rect("Text", parent, x1, y1, x2, y2);
            var label = rect.gameObject.AddComponent<Text>(); label.font = font; label.fontSize = size;
            label.color = new Color(.86f, .93f, .91f); label.alignment = alignment; label.text = text;
            label.resizeTextForBestFit = true; label.resizeTextMinSize = Math.Max(10, size - 4); label.resizeTextMaxSize = size;
            label.horizontalOverflow = HorizontalWrapMode.Wrap; label.verticalOverflow = VerticalWrapMode.Truncate; label.raycastTarget = false;
            return label;
        }
        private void Button(Transform parent, string text, float x1, float y1, float x2, float y2, Action click, int size = 16)
        {
            var rect = Rect("Button", parent, x1, y1, x2, y2);
            var image = rect.gameObject.AddComponent<Image>(); image.color = new Color(.25f, .17f, .11f, .94f);
            var button = rect.gameObject.AddComponent<Button>(); button.targetGraphic = image;
            button.onClick.AddListener(() => click());
            Label(rect, text, .04f, .05f, .96f, .95f, size, TextAnchor.MiddleCenter);
        }
        private InputField Input(Transform parent, string value, float x1, float y1, float x2, float y2, Action<string> changed)
        {
            var rect = Rect("Input", parent, x1, y1, x2, y2);
            var image = rect.gameObject.AddComponent<Image>(); image.color = new Color(.10f, .20f, .22f);
            var input = rect.gameObject.AddComponent<InputField>(); input.targetGraphic = image;
            var text = Label(rect, value, .03f, .08f, .97f, .92f, 17, TextAnchor.MiddleLeft);
            text.supportRichText = false; input.textComponent = text; input.text = value;
            input.onValueChanged.AddListener(value2 => changed(value2));
            return input;
        }
    }
}
