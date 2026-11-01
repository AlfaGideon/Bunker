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
            const string bodyPath = "Assets/Resources/People/player_base.glb";
            const string animPath = "Assets/Resources/People/player_anims_cc0.glb";
            AssetDatabase.ImportAsset(bodyPath, ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);
            AssetDatabase.ImportAsset(animPath, ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);
            Debug.Log("CHARACTER_IMPORTER " + (AssetImporter.GetAtPath(bodyPath)?.GetType().FullName ?? "none"));
            var body = AssetDatabase.LoadAssetAtPath<GameObject>(bodyPath);
            if (body == null)
            {
                var importer = AssetImporter.GetAtPath(bodyPath);
                var field = importer?.GetType().GetField("reportItems", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
                var items = field?.GetValue(importer) as System.Collections.IEnumerable;
                string details = "";
                if (items != null) foreach (var item in items) details += " " + item;
                throw new Exception("Character GLB import failed:" + details);
            }
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
