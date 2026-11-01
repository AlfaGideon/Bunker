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
            var characterStart = camp.CharacterPosition;
            var cameraStart = camp.CameraPosition;
            float[] times = { 0f, 3.5f, 6.9f };
            for (int i = 0; i < times.Length; i++)
            {
                camp.EvaluateTransition(times[i]);
                if (i > 0 && (camp.CharacterPosition.x <= characterStart.x || camp.CameraPosition.x <= cameraStart.x))
                    throw new Exception("Loading transition did not move character and camera to the right");
                var target = new RenderTexture(640, 360, 24, RenderTextureFormat.ARGB32);
                camera.targetTexture = target; camera.Render(); RenderTexture.active = target;
                var texture = new Texture2D(640, 360, TextureFormat.RGB24, false);
                texture.ReadPixels(new Rect(0, 0, 640, 360), 0, 0); texture.Apply();
                var path = Path.GetFullPath(Path.Combine(Application.dataPath, "../Builds/camp-audit-" + i + ".jpg"));
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                File.WriteAllBytes(path, texture.EncodeToJPG(55));
                RenderTexture.active = null; camera.targetTexture = null; target.Release();
            }
            UnityEngine.Object.DestroyImmediate(camp.gameObject);
            Debug.Log("CAMP_AUDIT_OK three transition frames");
        }
    }
}
#endif
