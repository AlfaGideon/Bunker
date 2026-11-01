using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

namespace Bunker.UnityPort.World
{
    /// <summary>Experimental local rendering of the current match, not network movement sync.</summary>
    public sealed class BunkerWorld : MonoBehaviour
    {
        private Material wallMaterial;
        private Transform peopleRoot, furnitureRoot;
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
                Module("Wall3", new Vector3(i * 4, 0, -6.5f), Quaternion.identity, true);
                Module("Wall2", new Vector3(-6.5f, 0, i * 4), Quaternion.Euler(0, 90, 0), true);
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
                Module("Wall3", new Vector3(6.5f, 0, side), Quaternion.Euler(0, 90, 0), true, new Vector3(.25f, 1, 1));
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
            for (int i = 0; i < (capacity + 1) / 2; i++)
            {
                float x = i % 2 == 0 ? -5.1f : 5.1f;
                float z = -3.6f + (i / 2) * 3.6f;
                Furniture("Bunk", new Vector3(x, 0, z), Quaternion.Euler(0, i % 2 == 0 ? 90 : -90, 0), 1.85f, "rest");
            }
            Furniture("Computer", new Vector3(4.6f, 0, 5.2f), Quaternion.Euler(0, -90, 0), 1.4f, "terminal");
            Furniture("Radio", new Vector3(1, .78f, .3f), Quaternion.identity, .25f, "radio");
            Furniture("Bunk", new Vector3(12.5f, 0, 2.8f), Quaternion.Euler(0, 90, 0), 1.85f, "medical");
            Furniture("FirstAid", new Vector3(9, 0, 2.8f), Quaternion.identity, .55f, "medical");
        }

        public void SyncPlayers(Player[] players, string localId)
        {
            if (players == null) players = Array.Empty<Player>();
            SyncFurniture(Mathf.Max(1, players.Length));
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
