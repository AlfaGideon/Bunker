using System;
using System.Linq;
using UnityEngine;

namespace Bunker.UnityPort.World
{
    /// <summary>Camp menu background. Not the loading transition or a finished profile scene.</summary>
    public sealed class CampWorld : MonoBehaviour
    {
        private Light fireLight;
        private Transform flames;
        private Transform[] trees;
        private Quaternion[] treeRotations;
        private GameObject person;
        private AnimationClip idle, run;
        private CharacterRigPlayback playback;
        private Camera campCamera;
        private Vector3 cameraStart, seatStart;
        private float transitionTime = -1f;
        private Action onTransitionFinished;
        public float TransitionProgress => transitionTime < 0 ? 0 : Mathf.Clamp01(transitionTime / 7f);
        public Vector3 CharacterPosition => person.transform.position;
        public Vector3 CameraPosition => campCamera.transform.position;
        private Transform leftThigh, rightThigh, leftShin, rightShin;
        private float elapsed;

        public static CampWorld Create()
        {
            var root = new GameObject("Camp menu environment");
            var camp = root.AddComponent<CampWorld>();
            try { camp.Build(); return camp; }
            catch { Destroy(root); throw; }
        }
        private GameObject Place(string path, Vector3 position, Quaternion rotation, float height)
        {
            var prefab = Resources.Load<GameObject>(path);
            if (prefab == null) throw new InvalidOperationException("Missing camp model " + path);
            var obj = Instantiate(prefab, position, Quaternion.identity, transform);
            var renderers = obj.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0) throw new InvalidOperationException("Camp model has no renderer: " + path);
            var bounds = renderers[0].bounds;
            foreach (var renderer in renderers) bounds.Encapsulate(renderer.bounds);
            if (bounds.size.y < .001f) throw new InvalidOperationException("Bad camp model size: " + path);
            obj.transform.localScale *= height / bounds.size.y;
            bounds = renderers[0].bounds;
            foreach (var renderer in renderers) bounds.Encapsulate(renderer.bounds);
            obj.transform.position += Vector3.up * (position.y - bounds.min.y);
            obj.transform.rotation = rotation;
            return obj;
        }
        private void Build()
        {
            var texture = Resources.Load<Texture2D>("Camp/Ground");
            if (texture == null) throw new InvalidOperationException("Forest texture missing");
            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Forest ground"; ground.transform.SetParent(transform, false);
            ground.transform.localScale = Vector3.one * 20;
            var mat = new Material(Shader.Find("Standard")); mat.mainTexture = texture;
            mat.mainTextureScale = new Vector2(100, 100); mat.SetFloat("_Glossiness", .05f);
            ground.GetComponent<Renderer>().sharedMaterial = mat;
            var groundCollider = ground.GetComponent<Collider>();
            if (Application.isPlaying) Destroy(groundCollider); else DestroyImmediate(groundCollider);
            var list = new System.Collections.Generic.List<Transform>();
            for (int i = 0; i < 12; i++)
            {
                float angle = (i * 137.5f) * Mathf.Deg2Rad;
                float radius = 6f + (i % 4) * 2.4f;
                var t = Place("Camp/Tree", new Vector3(Mathf.Cos(angle) * radius, 0, Mathf.Sin(angle) * radius + 3), Quaternion.Euler(0, i * 77, 0), 5.5f + i % 4 * .6f);
                list.Add(t.transform);
            }
            trees = list.ToArray(); treeRotations = trees.Select(t => t.localRotation).ToArray();
            Place("Camp/Rock", new Vector3(-1.6f, 0, 2.2f), Quaternion.Euler(0, 55, 0), .5f);
            Place("Camp/Stump", new Vector3(-.9f, 0, 0), Quaternion.identity, .48f);
            Place("Furniture/Radio", new Vector3(-1.6f, 0, .35f), Quaternion.Euler(0, 25, 0), .35f);
            BuildBunker();
            var fire = Place("Camp/Bonfire", new Vector3(1.15f, 0, .8f), Quaternion.identity, .75f);
            flames = fire.transform;
            CreateFlameParticles();
            fireLight = new GameObject("Fire light").AddComponent<Light>();
            fireLight.transform.SetParent(transform, false); fireLight.transform.localPosition = new Vector3(1.15f, .8f, .8f);
            fireLight.type = LightType.Point; fireLight.range = 7; fireLight.color = new Color(1f, .45f, .16f); fireLight.intensity = 2;
            person = Place("People/player_base", new Vector3(-.9f, -.38f, 0), Quaternion.Euler(0, 90, 0), 1.75f);
            seatStart = person.transform.position;
            playback = person.AddComponent<CharacterRigPlayback>(); playback.Initialize();
            idle = Resources.LoadAll<AnimationClip>("People/player_anims_cc0").FirstOrDefault(c => c.name == "unarmed_idle");
            run = Resources.LoadAll<AnimationClip>("People/player_anims_cc0").FirstOrDefault(c => c.name == "unarmed_run");
            if (idle == null || run == null) throw new InvalidOperationException("Camp animation clips missing");
            foreach (var bone in person.GetComponentsInChildren<Transform>())
            {
                if (bone.name == "mixamorig:LeftUpLeg") leftThigh = bone;
                else if (bone.name == "mixamorig:RightUpLeg") rightThigh = bone;
                else if (bone.name == "mixamorig:LeftLeg") leftShin = bone;
                else if (bone.name == "mixamorig:RightLeg") rightShin = bone;
            }
            var camera = new GameObject("Camp camera"); camera.transform.SetParent(transform, false);
            camera.transform.localPosition = new Vector3(0, 2.2f, -6.3f);
            camera.transform.LookAt(new Vector3(.1f, 1.1f, .3f));
            campCamera = camera.AddComponent<Camera>(); campCamera.fieldOfView = 48; campCamera.clearFlags = CameraClearFlags.SolidColor; campCamera.backgroundColor = new Color(.10f, .16f, .16f);
            cameraStart = camera.transform.position;
            var sun = new GameObject("Camp sky light").AddComponent<Light>(); sun.transform.SetParent(transform, false);
            sun.type = LightType.Directional; sun.intensity = .45f; sun.color = new Color(.72f, .8f, .85f); sun.transform.rotation = Quaternion.Euler(45, 35, 0);
            RenderSettings.ambientLight = new Color(.25f, .28f, .29f);
            RenderSettings.fog = true; RenderSettings.fogColor = new Color(.10f, .16f, .16f);
            RenderSettings.fogMode = FogMode.ExponentialSquared; RenderSettings.fogDensity = .025f;
            ApplyPose(0);
        }
        private void CreateFlameParticles()
        {
            var go = new GameObject("Moving flames"); go.transform.SetParent(transform, false);
            go.transform.localPosition = new Vector3(1.15f, .28f, .8f);
            var particles = go.AddComponent<ParticleSystem>();
            var main = particles.main; main.loop = true; main.playOnAwake = true; main.startLifetime = new ParticleSystem.MinMaxCurve(.35f, .7f);
            main.startSpeed = new ParticleSystem.MinMaxCurve(.45f, .9f); main.startSize = new ParticleSystem.MinMaxCurve(.13f, .32f); main.maxParticles = 90;
            var emission = particles.emission; emission.rateOverTime = 40;
            var shape = particles.shape; shape.shapeType = ParticleSystemShapeType.Cone; shape.angle = 12; shape.radius = .20f; shape.rotation = new Vector3(-90, 0, 0);
            var color = particles.colorOverLifetime; color.enabled = true;
            var gradient = new Gradient(); gradient.SetKeys(
                new[] { new GradientColorKey(new Color(1, .75f, .18f), 0), new GradientColorKey(new Color(1, .2f, .025f), .65f), new GradientColorKey(new Color(.3f, .06f, 0), 1) },
                new[] { new GradientAlphaKey(.8f, 0), new GradientAlphaKey(.65f, .4f), new GradientAlphaKey(0, 1) });
            color.color = gradient;
            var texture = new Texture2D(32, 32, TextureFormat.RGBA32, false);
            for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++)
            {
                float dx=(x-15.5f)/15.5f, dy=(y-15.5f)/15.5f;
                texture.SetPixel(x, y, new Color(1, 1, 1, Mathf.Pow(Mathf.Clamp01(1 - dx*dx - dy*dy), 2)));
            }
            texture.Apply();
            var material = new Material(Shader.Find("Particles/Standard Unlit")); material.mainTexture = texture;
            var renderer = go.GetComponent<ParticleSystemRenderer>(); renderer.material = material;
        }
        // Outdoor vault entrance: a circular metal door, structural arch and
        // visible hardware. It remains part of the forest scene during travel.
        private void BuildBunker()
        {
            var bunker = new GameObject("Forest bunker entrance");
            bunker.transform.SetParent(transform, false);
            bunker.transform.localPosition = new Vector3(7.6f, 0, 1.4f);
            var concrete = new Material(Shader.Find("Standard")); concrete.color = new Color(.23f, .24f, .22f); concrete.SetFloat("_Glossiness", .08f);
            var metal = new Material(Shader.Find("Standard")); metal.color = new Color(.25f, .29f, .28f); metal.SetFloat("_Metallic", .75f); metal.SetFloat("_Glossiness", .35f);
            var trim = new Material(Shader.Find("Standard")); trim.color = new Color(.13f, .16f, .16f); trim.SetFloat("_Metallic", .8f);
            VaultPiece("Reinforced wall", PrimitiveType.Cube, bunker.transform, new Vector3(0, 1.8f, .5f), new Vector3(4.5f, 3.6f, .9f), Quaternion.identity, concrete);
            VaultPiece("Door frame", PrimitiveType.Cylinder, bunker.transform, new Vector3(0, 1.55f, -.08f), new Vector3(3.3f, .13f, 3.3f), Quaternion.Euler(90, 0, 0), trim);
            VaultPiece("Circular hatch", PrimitiveType.Cylinder, bunker.transform, new Vector3(0, 1.55f, -.25f), new Vector3(2.85f, .09f, 2.85f), Quaternion.Euler(90, 0, 0), metal);
            VaultPiece("Central wheel", PrimitiveType.Cylinder, bunker.transform, new Vector3(0, 1.55f, -.39f), new Vector3(.52f, .08f, .52f), Quaternion.Euler(90, 0, 0), trim);
            for (int i=0; i<12; i++)
            {
                float a = i * Mathf.PI * 2 / 12;
                VaultPiece("Rivet", PrimitiveType.Sphere, bunker.transform, new Vector3(Mathf.Sin(a)*1.52f, 1.55f+Mathf.Cos(a)*1.52f, -.36f), Vector3.one*.09f, Quaternion.identity, metal);
            }
        }
        private static void VaultPiece(string name, PrimitiveType type, Transform parent, Vector3 position, Vector3 scale, Quaternion rotation, Material material)
        {
            var obj = GameObject.CreatePrimitive(type); obj.name = name;
            obj.transform.SetParent(parent, false); obj.transform.localPosition = position; obj.transform.localRotation = rotation; obj.transform.localScale = scale;
            obj.GetComponent<Renderer>().sharedMaterial = material;
            var collider = obj.GetComponent<Collider>();
            if (Application.isPlaying) Destroy(collider); else DestroyImmediate(collider);
        }

        public void SetOutfit(int index)
        {
            if (person == null) return;
            Color[] colors = { Color.white, new Color(.42f, .53f, .37f), new Color(.38f, .49f, .62f) };
            var selected = colors[Mathf.Abs(index) % colors.Length];
            foreach (var renderer in person.GetComponentsInChildren<Renderer>())
                foreach (var material in renderer.materials)
                    if (material.name.IndexOf("outfit", StringComparison.OrdinalIgnoreCase) >= 0 && material.HasProperty("_Color"))
                        material.color = selected;
        }
        public void BeginTransition(Action finished)
        {
            if (transitionTime >= 0) return;
            transitionTime = 0; onTransitionFinished = finished;
        }
        // Deterministic timeline also lets the Unity audit render multiple frames.
        public void EvaluateTransition(float seconds)
        {
            float rise = Mathf.SmoothStep(0, 1, Mathf.Clamp01(seconds / 1.3f));
            float travel = Mathf.SmoothStep(0, 1, Mathf.Clamp01((seconds - 1.3f) / 5.7f));
            person.transform.position = seatStart + new Vector3(travel * 7.4f, rise * .38f, 0);
            campCamera.transform.position = cameraStart + Vector3.right * (travel * 5.7f);
            if (seconds < 1.3f) ApplyPose(seconds, 1 - rise);
            else if (run != null) playback.Sample(run, ((seconds - 1.3f) * 1.1f) % Mathf.Max(.01f, run.length));
        }
        // Provisional seated pose; the upper body continues its idle animation.
        public void ApplyPose(float seconds, float seated = 1f)
        {
            if (person == null || idle == null) return;
            playback.Sample(idle, idle.length > 0 ? seconds % idle.length : 0);
            if (leftThigh != null) leftThigh.localRotation *= Quaternion.Euler(-70 * seated, 0, 0);
            if (rightThigh != null) rightThigh.localRotation *= Quaternion.Euler(-70 * seated, 0, 0);
            if (leftShin != null) leftShin.localRotation *= Quaternion.Euler(75 * seated, 0, 0);
            if (rightShin != null) rightShin.localRotation *= Quaternion.Euler(75 * seated, 0, 0);
        }
        private void OnEnable()
        {
            if (campCamera == null) return;
            transitionTime = -1; onTransitionFinished = null;
            campCamera.transform.position = cameraStart;
            person.transform.position = seatStart;
            RenderSettings.fog = true; RenderSettings.fogColor = new Color(.10f, .16f, .16f);
            RenderSettings.fogMode = FogMode.ExponentialSquared; RenderSettings.fogDensity = .025f;
            RenderSettings.ambientLight = new Color(.25f, .28f, .29f);
        }
        private void Update()
        {
            elapsed += Time.deltaTime;
            if (transitionTime < 0) ApplyPose(elapsed);
            else
            {
                transitionTime += Time.deltaTime;
                EvaluateTransition(transitionTime);
                if (transitionTime >= 7f && onTransitionFinished != null)
                {
                    var callback = onTransitionFinished; onTransitionFinished = null; callback();
                }
            }
            if (fireLight != null) fireLight.intensity = 1.8f + .3f * Mathf.Sin(elapsed * 7) + .2f * Mathf.Sin(elapsed * 11.3f);
            if (flames != null) flames.localRotation = Quaternion.Euler(0, Mathf.Sin(elapsed * 2) * 3, 0);
            if (trees != null) for (int i = 0; i < trees.Length; i++)
                if (trees[i] != null) trees[i].localRotation = treeRotations[i] * Quaternion.Euler(0, 0, Mathf.Sin(elapsed * .65f + i) * .45f);
        }
        private void OnDestroy()
        {
            var ground = transform.Find("Forest ground");
            if (ground != null) { var r = ground.GetComponent<Renderer>(); if (r != null) { if (Application.isPlaying) Destroy(r.sharedMaterial); else DestroyImmediate(r.sharedMaterial); } }
        }
    }
}
