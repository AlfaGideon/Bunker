using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;

namespace Bunker.UnityPort.World
{
    /// <summary>Experimental local rendering of the current match, not network movement sync.</summary>
    public sealed class BunkerWorld : MonoBehaviour
    {
        private Material wallMaterial;
        private Transform peopleRoot, furnitureRoot, privateRoomsRoot, optionalRoomsRoot;
        private int? layoutSeed;
        private GameObject warehouseBarrier;
        private string privateRoomSignature;
        private int furnitureCapacity = -1;
        private BunkerTouchController movement;
        private Camera worldCamera;
        private GameObject medicalDoor;
        private Vector3 medicalClosedPosition;
        private bool medicalOpen;
        private bool overhead;
        private int tapFinger = -1;
        private Vector2 tapStart;
        public event Action<string> PlayerSelected;
        public event Action<string> ActionRequested;
        private readonly Dictionary<string, GameObject> people = new Dictionary<string, GameObject>();

        public static BunkerWorld Create()
        {
            var root = new GameObject("Experimental 3D bunker");
            var world = root.AddComponent<BunkerWorld>();
            try { world.Build(); return world; }
            catch { Destroy(root); throw; }
        }

        private void Build()
        {
            var albedo = Resources.Load<Texture2D>("Irondust/Albedo");
            var normal = Resources.Load<Texture2D>("Irondust/NormalMap");
            var shader = Shader.Find("Standard");
            if (albedo == null || normal == null || shader == null) throw new InvalidOperationException("Missing bunker materials");
            wallMaterial = new Material(shader);
            wallMaterial.mainTexture = albedo;
            wallMaterial.SetTexture("_BumpMap", normal);
            wallMaterial.EnableKeyword("_NORMALMAP");
            wallMaterial.SetFloat("_Glossiness", .25f);
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(.36f, .34f, .30f);
            for (int x = -1; x <= 1; x++) for (int z = -1; z <= 1; z++)
            {
                Module("Floor", new Vector3(x * 4, 0, z * 4), Quaternion.identity, true);
                Module("Floor", new Vector3(x * 4, 4, z * 4), Quaternion.Euler(180, 0, 0), false);
            }
            for (int i = -1; i <= 1; i++)
            {
                if (i != 0) Module("Wall1", new Vector3(i * 4, 0, 6.5f), Quaternion.identity, true);
                if (i != 0) Module("Wall3", new Vector3(i * 4, 0, -6.5f), Quaternion.identity, true);
                if (i != 0) Module("Wall2", new Vector3(-6.5f, 0, i * 4), Quaternion.Euler(0, 90, 0), true);
                if (i != 0) Module("Wall3", new Vector3(6.5f, 0, i * 4), Quaternion.Euler(0, 90, 0), true);
            }
            // Real ceiling luminaires illuminate both the room and wall joins.
            for (int z = -1; z <= 1; z++)
            {
                var light = new GameObject("Ceiling lamp " + z).AddComponent<Light>();
                light.transform.SetParent(transform, false);
                light.transform.localPosition = new Vector3(0, 3.65f, z * 4);
                light.type = LightType.Point; light.range = 8; light.intensity = 1.5f;
                light.color = new Color(1, .88f, .72f);
            }
            // Two metre openings in the hall walls: one to the medical room,
            // the other to the exit corridor. Wall stubs meet the opening.
            foreach (float side in new[] { -1.5f, 1.5f })
            {
                Module("Wall1", new Vector3(side, 0, 6.5f), Quaternion.identity, true, new Vector3(.25f, 1, 1));
                Module("Wall3", new Vector3(side, 0, -6.5f), Quaternion.identity, true, new Vector3(.25f, 1, 1));
                Module("Wall3", new Vector3(6.5f, 0, side), Quaternion.Euler(0, 90, 0), true, new Vector3(.25f, 1, 1));
                Module("Wall2", new Vector3(-6.5f, 0, side), Quaternion.Euler(0, 90, 0), true, new Vector3(.25f, 1, 1));
            }
            BuildMedicalRoom();
            BuildExitCorridor();
            furnitureRoot = new GameObject("Furniture").transform;
            furnitureRoot.SetParent(transform, false);
            medicalDoor = Furniture("Door", new Vector3(6.2f, 0, 0), Quaternion.Euler(0, 90, 0), 2.8f, "gate");
            medicalDoor.transform.SetParent(transform, true);
            medicalClosedPosition = medicalDoor.transform.position;
            var exitDoor = Furniture("Door", new Vector3(0, 0, 6.2f), Quaternion.identity, 2.8f, "exit");
            exitDoor.transform.SetParent(transform, true);
            optionalRoomsRoot = new GameObject("Seeded optional rooms").transform;
            optionalRoomsRoot.SetParent(transform, false);
            privateRoomsRoot = new GameObject("Private bedrooms").transform;
            privateRoomsRoot.SetParent(transform, false);
            peopleRoot = new GameObject("Match participants").transform;
            peopleRoot.SetParent(transform, false);
            var player = new GameObject("Local observer"); player.transform.SetParent(transform, false);
            player.transform.localPosition = new Vector3(0, .1f, -4.6f);
            var controller = player.AddComponent<CharacterController>();
            controller.height = 1.7f; controller.radius = .3f; controller.center = new Vector3(0, .85f, 0);
            // Add on inactive object so Awake sees the configured pivot.
            player.SetActive(false);
            var camera = new GameObject("Camera"); camera.transform.SetParent(player.transform, false);
            camera.transform.localPosition = new Vector3(0, 1.62f, 0);
            worldCamera = camera.AddComponent<Camera>(); worldCamera.fieldOfView = 70;
            worldCamera.clearFlags = CameraClearFlags.SolidColor; worldCamera.backgroundColor = new Color(.04f, .04f, .04f);
            camera.AddComponent<AudioListener>();
            movement = player.AddComponent<BunkerTouchController>(); movement.cameraPivot = camera.transform;
            player.SetActive(true);
        }

        private void BuildMedicalRoom()
        {
            for (int x = 8; x <= 12; x += 4) for (int z = -2; z <= 2; z += 4)
            {
                Module("Floor", new Vector3(x, 0, z), Quaternion.identity, true);
                Module("Floor", new Vector3(x, 4, z), Quaternion.Euler(180, 0, 0), false);
            }
            for (int z = -2; z <= 2; z += 4)
                Module("Wall2", new Vector3(14.5f, 0, z), Quaternion.Euler(0, 90, 0), true);
            for (int x = 8; x <= 12; x += 4)
            {
                Module("Wall3", new Vector3(x, 0, -4.5f), Quaternion.identity, true);
                Module("Wall3", new Vector3(x, 0, 4.5f), Quaternion.identity, true);
            }
            var lamp = new GameObject("Medical room light").AddComponent<Light>();
            lamp.transform.SetParent(transform, false); lamp.transform.localPosition = new Vector3(10, 3.5f, 0);
            lamp.type = LightType.Point; lamp.range = 10; lamp.intensity = 1.5f;
        }

        private void BuildExitCorridor()
        {
            for (int z = 8; z <= 12; z += 4)
            {
                Module("Floor", new Vector3(0, 0, z), Quaternion.identity, true);
                Module("Floor", new Vector3(0, 4, z), Quaternion.Euler(180, 0, 0), false);
                Module("Wall3", new Vector3(-2.5f, 0, z), Quaternion.Euler(0, 90, 0), true);
                Module("Wall3", new Vector3(2.5f, 0, z), Quaternion.Euler(0, 90, 0), true);
            }
            Module("Wall1", new Vector3(0, 0, 14.5f), Quaternion.identity, true);
            var lamp = new GameObject("Exit corridor light").AddComponent<Light>();
            lamp.transform.SetParent(transform, false); lamp.transform.localPosition = new Vector3(0, 3.5f, 10);
            lamp.type = LightType.Point; lamp.range = 10; lamp.intensity = 1.2f;
        }

        private void Module(string id, Vector3 position, Quaternion rotation, bool collision, Vector3? scale = null)
        {
            var prefab = Resources.Load<GameObject>("Irondust/Models/" + id);
            if (prefab == null) throw new InvalidOperationException("Missing environment module: " + id);
            var obj = Instantiate(prefab, position, rotation, transform);
            obj.transform.localScale = scale ?? Vector3.one;
            foreach (var r in obj.GetComponentsInChildren<MeshRenderer>()) r.sharedMaterial = wallMaterial;
            if (collision)
                foreach (var filter in obj.GetComponentsInChildren<MeshFilter>())
                    if (filter.sharedMesh != null) filter.gameObject.AddComponent<MeshCollider>().sharedMesh = filter.sharedMesh;
        }

        // Normalize authored furniture to plausible metric heights before placing
        // it. Quaternius and MakeHuman source packs use different scales.
        private GameObject Furniture(string id, Vector3 position, Quaternion rotation, float targetHeight, string action = null)
        {
            var prefab = Resources.Load<GameObject>("Furniture/" + id);
            if (prefab == null) throw new InvalidOperationException("Missing furniture: " + id);
            var obj = Instantiate(prefab, position, Quaternion.identity, furnitureRoot);
            var renderers = obj.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0) throw new InvalidOperationException("No renderers on furniture: " + id);
            var bounds = renderers[0].bounds;
            foreach (var renderer in renderers) bounds.Encapsulate(renderer.bounds);
            if (bounds.size.y < .01f) throw new InvalidOperationException("Invalid furniture size: " + id);
            obj.transform.localScale *= targetHeight / bounds.size.y;
            bounds = renderers[0].bounds;
            foreach (var renderer in renderers) bounds.Encapsulate(renderer.bounds);
            obj.transform.position += new Vector3(0, position.y - bounds.min.y, 0);
            if (!string.IsNullOrEmpty(action))
            {
                bounds = renderers[0].bounds;
                foreach (var renderer in renderers) bounds.Encapsulate(renderer.bounds);
                var collider = obj.AddComponent<BoxCollider>();
                collider.center = obj.transform.InverseTransformPoint(bounds.center);
                collider.size = bounds.size / obj.transform.lossyScale.x;
                var target = obj.AddComponent<WorldInteractionTarget>(); target.action = action;
            }
            obj.transform.rotation = rotation;
            return obj;
        }

        public void SyncStations(StationState stations)
        {
            medicalOpen = stations != null && stations.medical_open;
            if (medicalDoor != null)
                medicalDoor.transform.position = medicalClosedPosition + (medicalOpen ? Vector3.up * 3f : Vector3.zero);
            if (warehouseBarrier != null) warehouseBarrier.SetActive(stations == null || !stations.warehouse_open);
        }

        private void SyncFurniture(int capacity)
        {
            if (capacity == furnitureCapacity) return;
            furnitureCapacity = capacity;
            foreach (Transform child in furnitureRoot) { child.gameObject.SetActive(false); Destroy(child.gameObject); }
            Furniture("Table", new Vector3(0, 0, .3f), Quaternion.identity, .78f, "food");
            for (int i = 0; i < capacity; i++)
            {
                float angle = (i - (capacity - 1) * .5f) * Mathf.PI / Mathf.Max(1, capacity - 1) * .85f;
                Furniture("Chair", new Vector3(Mathf.Sin(angle) * 2.05f, 0, .3f + Mathf.Cos(angle) * 2.05f), Quaternion.Euler(0, angle * Mathf.Rad2Deg + 180, 0), .9f, "rest");
            }
            Furniture("Computer", new Vector3(4.6f, 0, 5.2f), Quaternion.Euler(0, -90, 0), 1.4f, "terminal");
            Furniture("Radio", new Vector3(1, .78f, .3f), Quaternion.identity, .25f, "radio");
            Furniture("Bunk", new Vector3(12.5f, 0, 2.8f), Quaternion.Euler(0, 90, 0), 1.85f, "medical");
            Furniture("FirstAid", new Vector3(9, 0, 2.8f), Quaternion.identity, .55f, "medical");
        }

        private GameObject OptionalPanel(string name, Vector3 center, Vector3 size)
        {
            var panel = GameObject.CreatePrimitive(PrimitiveType.Cube); panel.name = name;
            panel.transform.SetParent(optionalRoomsRoot, false); panel.transform.localPosition = center;
            panel.transform.localScale = size; panel.GetComponent<Renderer>().sharedMaterial = wallMaterial;
            return panel;
        }
        // The seed swaps the two connected rooms; stock access follows match state.
        public void SyncLayout(int seed)
        {
            if (layoutSeed == seed) return;
            layoutSeed = seed;
            foreach (var child in optionalRoomsRoot.Cast<Transform>().ToArray())
            { child.gameObject.SetActive(false); if (Application.isPlaying) Destroy(child.gameObject); else DestroyImmediate(child.gameObject); }
            OptionalPanel("Connector floor", new Vector3(0, -.12f, -10), new Vector3(4, .24f, 7));
            OptionalPanel("Connector ceiling", new Vector3(0, 3.05f, -10), new Vector3(4, .1f, 7));
            OptionalPanel("Connector end", new Vector3(0, 1.5f, -13.5f), new Vector3(4, 3, .15f));
            int kitchenSide = (new System.Random(seed).Next(2) == 0) ? -1 : 1;
            foreach (int side in new[] { -1, 1 })
            {
                bool kitchen = side == kitchenSide;
                string title = kitchen ? "Kitchen" : "Warehouse";
                float x = side * 4;
                OptionalPanel(title + " floor", new Vector3(x, -.12f, -10), new Vector3(4, .24f, 7));
                OptionalPanel(title + " ceiling", new Vector3(x, 3.05f, -10), new Vector3(4, .1f, 7));
                OptionalPanel(title + " outside wall", new Vector3(side * 6, 1.5f, -10), new Vector3(.15f, 3, 7));
                foreach (float z in new[] { -6.5f, -13.5f }) OptionalPanel(title + " end wall", new Vector3(x, 1.5f, z), new Vector3(4, 3, .15f));
                foreach (float z in new[] { -7.75f, -12.25f }) OptionalPanel(title + " doorway wall", new Vector3(side * 2, 1.5f, z), new Vector3(.15f, 3, 2.5f));
                OptionalPanel(title + " lintel", new Vector3(side * 2, 2.7f, -10), new Vector3(.15f, .6f, 2));
                if (!kitchen) warehouseBarrier = OptionalPanel("Warehouse locked", new Vector3(side * 2, 1.05f, -10), new Vector3(.2f, 2.1f, 2));
                var furniture = Furniture(kitchen ? "Table" : "Computer", new Vector3(x, 0, -10.4f), Quaternion.identity, kitchen ? .78f : 1.4f, kitchen ? "cook" : null);
                furniture.transform.SetParent(optionalRoomsRoot, true);
                var lamp = new GameObject(title + " light").AddComponent<Light>(); lamp.transform.SetParent(optionalRoomsRoot, false);
                lamp.transform.localPosition = new Vector3(x, 2.75f, -10); lamp.type = LightType.Point; lamp.range = 7; lamp.intensity = 1.25f;
            }
        }

        private GameObject RoomPanel(string name, Vector3 center, Vector3 size)
        {
            var panel = GameObject.CreatePrimitive(PrimitiveType.Cube); panel.name = name;
            panel.transform.SetParent(privateRoomsRoot, false); panel.transform.localPosition = center;
            panel.transform.localScale = size; panel.GetComponent<Renderer>().sharedMaterial = wallMaterial;
            return panel;
        }
        // Client-side physical privacy, not server authorization: network movement
        // is not yet synchronized. Every roster entry gets a separate bedroom.
        private void SyncPrivateRooms(Player[] players, string localId)
        {
            var ordered = players.Where(p => p != null && !string.IsNullOrEmpty(p.id))
                .OrderBy(p => p.seat).ThenBy(p => p.id, StringComparer.Ordinal).ToArray();
            var signature = localId + "|" + string.Join("|", ordered.Select(p => p.id + ":" + p.name));
            if (privateRoomSignature == signature) return;
            privateRoomSignature = signature;
            foreach (var child in privateRoomsRoot.Cast<Transform>().ToArray()) { child.gameObject.SetActive(false); if (Application.isPlaying) Destroy(child.gameObject); else DestroyImmediate(child.gameObject); }
            int columns = (ordered.Length + 1) / 2;
            for (int c = 0; c < columns; c++)
            {
                float x = -8.6f - c * 4f;
                RoomPanel("Bedroom corridor floor", new Vector3(x, -.12f, 0), new Vector3(4, .24f, 3.6f));
                RoomPanel("Bedroom corridor ceiling", new Vector3(x, 3.05f, 0), new Vector3(4, .1f, 3.6f));
                var light = new GameObject("Bedroom corridor light").AddComponent<Light>();
                light.transform.SetParent(privateRoomsRoot, false); light.transform.localPosition = new Vector3(x, 2.8f, 0);
                light.type = LightType.Point; light.range = 7; light.intensity = 1.1f;
            }
            if (ordered.Length % 2 == 1)
                RoomPanel("Corridor side closure", new Vector3(-8.6f - (columns - 1) * 4f, 1.5f, -1.8f), new Vector3(4, 3, .15f));
            if (columns > 0) RoomPanel("Corridor end", new Vector3(-6.6f - columns * 4, 1.5f, 0), new Vector3(.2f, 3, 3.6f));
            for (int i = 0; i < ordered.Length; i++)
            {
                var p = ordered[i]; float x = -8.6f - (i / 2) * 4f; float side = i % 2 == 0 ? 1 : -1;
                float z = side * 3.6f;
                RoomPanel("Bedroom floor " + p.id, new Vector3(x, -.12f, z), new Vector3(4, .24f, 3.6f));
                RoomPanel("Bedroom ceiling " + p.id, new Vector3(x, 3.05f, z), new Vector3(4, .1f, 3.6f));
                RoomPanel("Bedroom back " + p.id, new Vector3(x, 1.5f, side * 5.4f), new Vector3(4, 3, .15f));
                foreach (float dx in new[] { -2f, 2f }) RoomPanel("Bedroom side " + p.id, new Vector3(x + dx, 1.5f, z), new Vector3(.15f, 3, 3.6f));
                foreach (float dx in new[] { -1.5f, 1.5f }) RoomPanel("Bedroom front " + p.id, new Vector3(x + dx, 1.5f, side * 1.8f), new Vector3(1, 3, .15f));
                RoomPanel("Bedroom door lintel " + p.id, new Vector3(x, 2.7f, side * 1.8f), new Vector3(2, .6f, .15f));
                if (p.id != localId) RoomPanel("Locked bedroom " + p.id, new Vector3(x, 1.05f, side * 1.8f), new Vector3(2, 2.1f, .18f));
                var bed = Furniture("Bed", new Vector3(x - 1f, 0, z + side * .5f), Quaternion.identity, .65f, "rest");
                bed.transform.SetParent(privateRoomsRoot, true);
                var bedside = Furniture("Table", new Vector3(x + 1f, 0, z + side * .55f), Quaternion.identity, .55f);
                bedside.transform.SetParent(privateRoomsRoot, true);
                var label = new GameObject("Owner label " + p.id).AddComponent<TextMesh>();
                label.transform.SetParent(privateRoomsRoot, false); label.transform.localPosition = new Vector3(x, 2.4f, side * 1.68f);
                label.transform.localRotation = Quaternion.Euler(0, side > 0 ? 180 : 0, 0);
                label.text = p.name; label.anchor = TextAnchor.MiddleCenter; label.characterSize = .12f; label.fontSize = 32; label.color = Color.white;
            }
        }

        public void SyncPlayers(Player[] players, string localId)
        {
            if (players == null) players = Array.Empty<Player>();
            SyncFurniture(Mathf.Max(1, players.Length));
            SyncPrivateRooms(players, localId);
            var wanted = new HashSet<string>();
            int others = 0;
            foreach (var p in players) if (p != null && p.id != localId) others++;
            int index = 0;
            foreach (var p in players)
            {
                if (p == null || string.IsNullOrEmpty(p.id) || p.id == localId) continue;
                wanted.Add(p.id);
                if (!people.TryGetValue(p.id, out var actor))
                {
                    var prefab = Resources.Load<GameObject>("People/player_base");
                    if (prefab == null) throw new InvalidOperationException("Character not imported");
                    actor = Instantiate(prefab, peopleRoot);
                    actor.name = "Participant " + p.name;
                    var target = actor.AddComponent<WorldPlayerTarget>(); target.id = p.id;
                    actor.AddComponent<CharacterRigPlayback>().Initialize();
                    actor.AddComponent<WorldParticipantAnimator>();
                    var collider = actor.AddComponent<CapsuleCollider>();
                    collider.center = new Vector3(0, .9f, 0); collider.height = 1.8f; collider.radius = .3f;
                    people.Add(p.id, actor);
                }
                float angle = (index++ - (others - 1) * .5f) * Mathf.PI / Mathf.Max(1, others - 1) * .85f;
                actor.transform.localPosition = new Vector3(Mathf.Sin(angle) * 3.1f, 0, .3f + Mathf.Cos(angle) * 3.1f);
                actor.transform.rotation = Quaternion.LookRotation(new Vector3(-Mathf.Sin(angle), 0, -Mathf.Cos(angle)));
            }
            var removed = new List<string>();
            foreach (var pair in people) if (!wanted.Contains(pair.Key)) { Destroy(pair.Value); removed.Add(pair.Key); }
            foreach (var id in removed) people.Remove(id);
        }

        public void ToggleView() { overhead = !overhead; movement.SetTopView(overhead); }
        private void Update()
        {
            foreach (var touch in Input.touches)
            {
                if (touch.phase == TouchPhase.Began && tapFinger < 0 &&
                    (EventSystem.current == null || !EventSystem.current.IsPointerOverGameObject(touch.fingerId)))
                { tapFinger = touch.fingerId; tapStart = touch.position; }
                else if (touch.fingerId == tapFinger && (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled))
                {
                    if (touch.phase == TouchPhase.Ended && (touch.position - tapStart).magnitude < Mathf.Max(15, Screen.dpi * .12f))
                    {
                        var ray = worldCamera.ScreenPointToRay(touch.position);
                        if (Physics.Raycast(ray, out var hit, 20))
                        {
                            var target = hit.collider.GetComponentInParent<WorldPlayerTarget>();
                            if (target != null) PlayerSelected?.Invoke(target.id);
                            else
                            {
                                var interact = hit.collider.GetComponentInParent<WorldInteractionTarget>();
                                if (interact != null) TryInteract(interact, hit.point);
                            }
                        }
                    }
                    tapFinger = -1;
                }
            }
        }
        public bool TryInteract(WorldInteractionTarget target, Vector3 hitPoint)
        {
            if (target == null || string.IsNullOrEmpty(target.action) || movement == null ||
                Vector3.Distance(movement.transform.position, hitPoint) > 3f) return false;
            ActionRequested?.Invoke(target.action);
            return true;
        }
        private void OnEnable() { RenderSettings.fog = false; }
        private void OnDisable() { tapFinger = -1; }
        private void OnDestroy() { if (wallMaterial != null) Destroy(wallMaterial); }
    }
    public sealed class WorldPlayerTarget : MonoBehaviour { public string id; }
    public sealed class WorldInteractionTarget : MonoBehaviour { public string action; }
}
