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
        private Transform peopleRoot;
        private BunkerTouchController movement;
        private Camera worldCamera;
        private bool overhead;
        private int tapFinger = -1;
        private Vector2 tapStart;
        public event Action<string> PlayerSelected;
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
                Module("Wall1", new Vector3(i * 4, 0, 6.5f), Quaternion.identity, true);
                Module("Wall3", new Vector3(i * 4, 0, -6.5f), Quaternion.identity, true);
                Module("Wall2", new Vector3(-6.5f, 0, i * 4), Quaternion.Euler(0, 90, 0), true);
                Module("Wall3", new Vector3(6.5f, 0, i * 4), Quaternion.Euler(0, 90, 0), true);
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
            Furniture("Table", new Vector3(0, 0, .3f), Quaternion.identity);
            for (int i = 0; i < 6; i++)
            {
                float a = i * Mathf.PI * 2 / 6;
                Furniture("Chair", new Vector3(Mathf.Sin(a) * 2.1f, 0, .3f + Mathf.Cos(a) * 2.1f), Quaternion.Euler(0, i * 60, 0));
            }
            Furniture("Bunk", new Vector3(-5.1f, 0, 4.8f), Quaternion.Euler(0, 90, 0));
            Furniture("Computer", new Vector3(4.7f, 0, 4.5f), Quaternion.Euler(0, -90, 0));
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

        private void Module(string id, Vector3 position, Quaternion rotation, bool collision)
        {
            var prefab = Resources.Load<GameObject>("Irondust/Models/" + id);
            if (prefab == null) throw new InvalidOperationException("Missing environment module: " + id);
            var obj = Instantiate(prefab, position, rotation, transform);
            foreach (var r in obj.GetComponentsInChildren<MeshRenderer>()) r.sharedMaterial = wallMaterial;
            if (collision)
                foreach (var filter in obj.GetComponentsInChildren<MeshFilter>())
                    if (filter.sharedMesh != null) filter.gameObject.AddComponent<MeshCollider>().sharedMesh = filter.sharedMesh;
        }

        private void Furniture(string id, Vector3 position, Quaternion rotation)
        {
            var prefab = Resources.Load<GameObject>("Furniture/" + id);
            if (prefab == null) throw new InvalidOperationException("Missing furniture: " + id);
            Instantiate(prefab, position, rotation, transform);
        }

        public void SyncPlayers(Player[] players, string localId)
        {
            if (players == null) players = Array.Empty<Player>();
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
                float angle = (index++ * Mathf.PI * 2) / Mathf.Max(1, others);
                actor.transform.localPosition = new Vector3(Mathf.Sin(angle) * 3, 0, .3f + Mathf.Cos(angle) * 3);
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
                        }
                    }
                    tapFinger = -1;
                }
            }
        }
        private void OnDisable() { tapFinger = -1; }
        private void OnDestroy() { if (wallMaterial != null) Destroy(wallMaterial); }
    }
    public sealed class WorldPlayerTarget : MonoBehaviour { public string id; }
}
