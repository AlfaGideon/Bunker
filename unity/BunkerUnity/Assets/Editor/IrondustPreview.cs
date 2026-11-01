#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace Bunker.UnityPort.Editor
{
    // Asset-import and visual audit only; this is not a game level.
    public static class IrondustPreview
    {
        private static Material material;
        private static void Part(string name, Vector3 position, float rotation = 0f, Vector3? scale = null)
        {
            var prefab = Resources.Load<GameObject>("Irondust/Models/" + name);
            if (prefab == null) throw new Exception("Missing imported mesh: " + name);
            var obj = UnityEngine.Object.Instantiate(prefab);
            obj.name = name;
            obj.transform.position = position;
            obj.transform.rotation = Quaternion.Euler(0, rotation, 0);
            obj.transform.localScale = scale ?? Vector3.one;
            var renderers = obj.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0) throw new Exception("No renderer on " + name);
            foreach (var renderer in renderers) renderer.sharedMaterial = material;
        }
        public static void Render()
        {
            var importer = (TextureImporter)AssetImporter.GetAtPath("Assets/Resources/Irondust/NormalMap.jpg");
            if (importer == null) throw new Exception("Normal map was not imported");
            importer.textureType = TextureImporterType.NormalMap;
            importer.SaveAndReimport();
            material = new Material(Shader.Find("Standard"));
            material.mainTexture = Resources.Load<Texture2D>("Irondust/Albedo");
            material.SetTexture("_BumpMap", Resources.Load<Texture2D>("Irondust/NormalMap"));
            material.EnableKeyword("_NORMALMAP");
            material.SetFloat("_Glossiness", .25f);
            if (material.mainTexture == null) throw new Exception("Albedo missing");
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(.26f, .27f, .27f);
            for (int x = -1; x <= 1; x++) for (int z = -1; z <= 1; z++)
                Part("Floor", new Vector3(x * 4, 0, z * 4));
            for (int i = -1; i <= 1; i++)
            {
                Part("Wall1", new Vector3(i * 4, 0, 6.5f));
                Part("Wall3", new Vector3(-6.5f, 0, i * 4), 90);
                Part("Wall2", new Vector3(6.5f, 0, i * 4), 90);
            }
            Part("Crate", new Vector3(-2.7f, 0, 3.0f), 15, Vector3.one * .6f);
            Part("Barrel", new Vector3(3.1f, 0, 3.0f), 0, Vector3.one * .6f);
            var lamp = new GameObject("Ceiling light").AddComponent<Light>();
            lamp.type = LightType.Point; lamp.transform.position = new Vector3(0, 3.5f, 1);
            lamp.range = 16; lamp.intensity = 2.0f; lamp.color = new Color(1f, .86f, .7f);
            var cam = new GameObject("Audit camera").AddComponent<Camera>();
            cam.transform.position = new Vector3(0, 1.7f, -4.5f);
            cam.transform.LookAt(new Vector3(0, 1.8f, 4));
            cam.fieldOfView = 75;
            cam.clearFlags = CameraClearFlags.SolidColor; cam.backgroundColor = new Color(.08f, .08f, .08f);
            var target = new RenderTexture(960, 540, 24, RenderTextureFormat.ARGB32);
            cam.targetTexture = target; cam.Render();
            RenderTexture.active = target;
            var image = new Texture2D(960, 540, TextureFormat.RGB24, false);
            image.ReadPixels(new Rect(0, 0, 960, 540), 0, 0); image.Apply();
            var path = Path.Combine(Application.dataPath, "../Builds/irondust-audit.jpg");
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllBytes(path, image.EncodeToJPG(65));
            RenderTexture.active = null; cam.targetTexture = null; target.Release();
            Debug.Log("IRONDUST_AUDIT_IMAGE " + path);
        }
    }
}
#endif
