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
            var rooms = world.transform.Find("Private bedrooms");
            if (rooms == null || rooms.Cast<Transform>().Count(t => t.name.StartsWith("Bedroom floor ")) != 3 ||
                rooms.Cast<Transform>().Count(t => t.name.StartsWith("Locked bedroom ")) != 2 ||
                rooms.Find("Locked bedroom human") != null)
                throw new Exception("Private bedrooms or access barriers are incorrect");
            var targets = world.GetComponentsInChildren<WorldInteractionTarget>();
            foreach (var action in new [] { "food", "rest", "radio", "gate", "medical", "exit" })
                if (!targets.Any(t => t.action == action)) throw new Exception("Missing physical interaction: " + action);
            var table = targets.First(t => t.action == "food");
            string receivedAction = null;
            world.ActionRequested += action => receivedAction = action;
            if (world.TryInteract(table, new Vector3(100, 0, 0)) || receivedAction != null)
                throw new Exception("Interaction bypasses distance limit");
            if (!world.TryInteract(table, new Vector3(0, .1f, -4.6f)) || receivedAction != "food")
                throw new Exception("Food interaction was not routed");
            var tableBounds = table.GetComponentsInChildren<Renderer>().Select(r => r.bounds).ToArray();
            var bounds = tableBounds[0]; foreach (var b in tableBounds) bounds.Encapsulate(b);
            if (Mathf.Abs(bounds.size.y - .78f) > .05f) throw new Exception("Table not scaled to human size: " + bounds.size.y);
            var door = targets.First(t => t.action == "gate").transform;
            float closedY = door.position.y;
            world.SyncStations(new StationState { medical_open = true });
            if (door.position.y < closedY + 2f) throw new Exception("Medical door did not follow match state");
            world.SyncStations(new StationState { medical_open = false });
            if (Mathf.Abs(door.position.y - closedY) > .01f) throw new Exception("Medical door failed to close");
            if (world.GetComponentsInChildren<MeshCollider>().Length < 10)
                throw new Exception("Environment collision missing");
            var actors = world.GetComponentsInChildren<WorldPlayerTarget>();
            var clip = Resources.LoadAll<AnimationClip>("People/player_anims_cc0").FirstOrDefault(c => c.name == "unarmed_idle");
            if (clip == null) throw new Exception("No idle clip in Resources");
            var playback = actors[0].GetComponent<CharacterRigPlayback>();
            var run = Resources.LoadAll<AnimationClip>("People/player_anims_cc0").First(c => c.name == "unarmed_run");
            var bones = actors[0].GetComponentsInChildren<Transform>();
            foreach (var name in new[] { "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg", "mixamorig:LeftArm", "mixamorig:RightArm" })
            {
                var bone = bones.First(b => b.name == name);
                playback.Sample(run, 0f); var initial = bone.localRotation;
                float largest = 0;
                for (int i = 1; i < 8; i++) { playback.Sample(run, run.length * i / 8f); largest = Mathf.Max(largest, Quaternion.Angle(initial, bone.localRotation)); }
                if (largest < 2f) throw new Exception("Run animation does not move " + name + ": " + largest);
            }
            foreach (var actor in actors) actor.GetComponent<CharacterRigPlayback>().Sample(clip, Mathf.Min(.5f, clip.length * .5f));
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
            CampAudit.Render();
        }
    }
}
#endif
