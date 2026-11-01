#if UNITY_EDITOR
using System;
using System.IO;
using Bunker.UnityPort.World;
using UnityEngine;

namespace Bunker.UnityPort.Editor
{
    public static class CampAudit
    {
        public static void Render()
        {
            var camp = CampWorld.Create();
            camp.ApplyPose(.5f);
            var camera = camp.GetComponentInChildren<Camera>();
            if (camera == null || camp.GetComponentsInChildren<SkinnedMeshRenderer>().Length == 0)
                throw new Exception("Camp character or camera missing");
            var target = new RenderTexture(960, 540, 24, RenderTextureFormat.ARGB32);
            camera.targetTexture = target; camera.Render(); RenderTexture.active = target;
            var texture = new Texture2D(960, 540, TextureFormat.RGB24, false);
            texture.ReadPixels(new Rect(0, 0, 960, 540), 0, 0); texture.Apply();
            var path = Path.GetFullPath(Path.Combine(Application.dataPath, "../Builds/camp-audit.jpg"));
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllBytes(path, texture.EncodeToJPG(60));
            RenderTexture.active = null; camera.targetTexture = null; target.Release();
            UnityEngine.Object.DestroyImmediate(camp.gameObject);
            Debug.Log("CAMP_AUDIT_OK " + path);
        }
    }
}
#endif
