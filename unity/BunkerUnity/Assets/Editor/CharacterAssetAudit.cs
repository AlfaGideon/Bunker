#if UNITY_EDITOR
using System;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace Bunker.UnityPort.Editor
{
    public static class CharacterAssetAudit
    {
        public static void VerifyAll()
        {
            TouchControllerAudit.Verify();
            Verify();
        }
        public static void Verify()
        {
            const string bodyPath = "Assets/Models/People/player_base.glb";
            const string animPath = "Assets/Models/People/player_anims_cc0.glb";
            var body = AssetDatabase.LoadAssetAtPath<GameObject>(bodyPath);
            if (body == null) throw new Exception("Character GLB was not imported as a GameObject");
            var skin = body.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            if (skin.Length == 0) throw new Exception("Character has no skinned mesh");
            var clips = AssetDatabase.LoadAllAssetsAtPath(animPath).OfType<AnimationClip>().Select(c => c.name).ToArray();
            foreach (string name in new[] { "unarmed_idle", "unarmed_walk", "unarmed_run" })
                if (!clips.Contains(name)) throw new Exception("Missing character clip: " + name + "; found: " + string.Join(", ", clips));
            Debug.Log("CHARACTER_AUDIT_OK skins=" + skin.Length + " clips=" + string.Join(", ", clips));
        }
    }
}
#endif
