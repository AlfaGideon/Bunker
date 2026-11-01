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
        private AnimationClip idle;
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
            Destroy(ground.GetComponent<Collider>());
            var list = new System.Collections.Generic.List<Transform>();
            for (int i = 0; i < 8; i++)
            {
                float angle = (i * 137.5f) * Mathf.Deg2Rad;
                float radius = 6f + (i % 4) * 2.4f;
                var t = Place("Camp/Tree", new Vector3(Mathf.Cos(angle) * radius, 0, Mathf.Sin(angle) * radius + 3), Quaternion.Euler(0, i * 77, 0), 5.5f + i % 4 * .6f);
                list.Add(t.transform);
            }
            trees = list.ToArray(); treeRotations = trees.Select(t => t.localRotation).ToArray();
            Place("Camp/Rock", new Vector3(-1.6f, 0, 2.2f), Quaternion.Euler(0, 55, 0), .5f);
            Place("Camp/Stump", new Vector3(-.9f, 0, 0), Quaternion.identity, .48f);
            var fire = Place("Camp/Bonfire", new Vector3(1.15f, 0, .8f), Quaternion.identity, .75f);
            flames = fire.transform;
            fireLight = new GameObject("Fire light").AddComponent<Light>();
            fireLight.transform.SetParent(transform, false); fireLight.transform.localPosition = new Vector3(1.15f, .8f, .8f);
            fireLight.type = LightType.Point; fireLight.range = 7; fireLight.color = new Color(1f, .45f, .16f); fireLight.intensity = 2;
            person = Place("People/player_base", new Vector3(-.9f, -.38f, 0), Quaternion.Euler(0, 45, 0), 1.75f);
            idle = Resources.LoadAll<AnimationClip>("People/player_anims_cc0").FirstOrDefault(c => c.name == "unarmed_idle");
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
            var cam = camera.AddComponent<Camera>(); cam.fieldOfView = 48; cam.clearFlags = CameraClearFlags.SolidColor; cam.backgroundColor = new Color(.10f, .16f, .16f);
            var sun = new GameObject("Camp sky light").AddComponent<Light>(); sun.transform.SetParent(transform, false);
            sun.type = LightType.Directional; sun.intensity = .45f; sun.color = new Color(.72f, .8f, .85f); sun.transform.rotation = Quaternion.Euler(45, 35, 0);
            RenderSettings.ambientLight = new Color(.25f, .28f, .29f);
            ApplyPose(0);
        }
        // Provisional procedural pose; replace with an authored seated clip.
        public void ApplyPose(float seconds)
        {
            if (person == null || idle == null) return;
            idle.SampleAnimation(person, idle.length > 0 ? seconds % idle.length : 0);
            if (leftThigh != null) leftThigh.localRotation *= Quaternion.Euler(-70, 0, 0);
            if (rightThigh != null) rightThigh.localRotation *= Quaternion.Euler(-70, 0, 0);
            if (leftShin != null) leftShin.localRotation *= Quaternion.Euler(75, 0, 0);
            if (rightShin != null) rightShin.localRotation *= Quaternion.Euler(75, 0, 0);
        }
        private void Update()
        {
            elapsed += Time.deltaTime;
            ApplyPose(elapsed);
            if (fireLight != null) fireLight.intensity = 1.8f + .3f * Mathf.Sin(elapsed * 7) + .2f * Mathf.Sin(elapsed * 11.3f);
            if (flames != null) flames.localRotation = Quaternion.Euler(0, Mathf.Sin(elapsed * 2) * 3, 0);
            if (trees != null) for (int i = 0; i < trees.Length; i++)
                if (trees[i] != null) trees[i].localRotation = treeRotations[i] * Quaternion.Euler(0, 0, Mathf.Sin(elapsed * .65f + i) * .45f);
        }
        private void OnDestroy()
        {
            var ground = transform.Find("Forest ground");
            if (ground != null) { var r = ground.GetComponent<Renderer>(); if (r != null) Destroy(r.sharedMaterial); }
        }
    }
}
