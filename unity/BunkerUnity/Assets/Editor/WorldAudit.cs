#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using Bunker.UnityPort.World;
using UnityEditor;
using UnityEngine;

namespace Bunker.UnityPort.Editor
{
    public static class WorldAudit
    {
        public static void Render()
        {
            var world = BunkerWorld.Create();
            world.SyncPlayers(new [] {
                new Player { id="human", name="Игрок" },
                new Player { id="bot1", name="Алексей", bot=true },
                new Player { id="bot2", name="Мария", bot=true }
            }, "human");
            if (world.GetComponentsInChildren<WorldPlayerTarget>().Length != 2)
                throw new Exception("Participants missing from 3D match");
            if (world.GetComponentsInChildren<MeshCollider>().Length < 10)
                throw new Exception("Environment collision missing");
            var actors = world.GetComponentsInChildren<WorldPlayerTarget>();
            var clip = Resources.LoadAll<AnimationClip>("People/player_anims_cc0").FirstOrDefault(c => c.name == "unarmed_idle");
            if (clip == null) throw new Exception("No idle clip in Resources");
            var bones = actors[0].GetComponentsInChildren<Transform>();
            clip.SampleAnimation(actors[0].gameObject, 0f);
            var rotations = bones.Select(b => b.localRotation).ToArray();
            clip.SampleAnimation(actors[0].gameObject, Mathf.Min(.5f, clip.length * .5f));
            if (!bones.Where((b, i) => Quaternion.Angle(b.localRotation, rotations[i]) > .1f).Any())
                throw new Exception("Animation clip did not bind to character skeleton");
            foreach (var actor in actors) clip.SampleAnimation(actor.gameObject, Mathf.Min(.5f, clip.length * .5f));
            var camera = world.GetComponentInChildren<Camera>();
            if (camera == null) throw new Exception("World camera missing");
            var target = new RenderTexture(960, 540, 24, RenderTextureFormat.ARGB32);
            camera.targetTexture = target; camera.Render(); RenderTexture.active = target;
            var texture = new Texture2D(960, 540, TextureFormat.RGB24, false);
            texture.ReadPixels(new Rect(0, 0, 960, 540), 0, 0); texture.Apply();
            var path = Path.GetFullPath(Path.Combine(Application.dataPath, "../Builds/world-audit.jpg"));
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllBytes(path, texture.EncodeToJPG(60));
            RenderTexture.active = null; camera.targetTexture = null; target.Release();
            UnityEngine.Object.DestroyImmediate(world.gameObject);
            Debug.Log("WORLD_AUDIT_OK " + path);
        }
    }
}
#endif
