using System;
using System.Collections.Generic;
using UnityEngine;

namespace Bunker.UnityPort.World
{
    // The animation GLB and the visible mesh have different scene-root paths.
    // Sample on the source hierarchy, then copy bone rotations by name.
    public sealed class CharacterRigPlayback : MonoBehaviour
    {
        private GameObject animationRig;
        private readonly List<Transform> sources = new List<Transform>();
        private readonly List<Transform> targets = new List<Transform>();

        public void Initialize()
        {
            if (animationRig != null) return;
            var prefab = Resources.Load<GameObject>("People/player_anims_cc0");
            if (prefab == null) throw new InvalidOperationException("Animation skeleton missing");
            var targetBones = new Dictionary<string, Transform>();
            foreach (var bone in GetComponentsInChildren<Transform>(true))
                if (bone.name.StartsWith("mixamorig:", StringComparison.Ordinal)) targetBones[bone.name] = bone;
            animationRig = Instantiate(prefab);
            animationRig.name = "Animation source (not visible)";
            animationRig.transform.SetParent(transform.parent, false);
            foreach (var renderer in animationRig.GetComponentsInChildren<Renderer>(true)) renderer.enabled = false;
            foreach (var bone in animationRig.GetComponentsInChildren<Transform>(true))
                if (targetBones.TryGetValue(bone.name, out var target)) { sources.Add(bone); targets.Add(target); }
            if (sources.Count < 20) throw new InvalidOperationException("Character skeletons do not match");
        }
        public void Sample(AnimationClip clip, float seconds)
        {
            Initialize();
            if (clip == null) return;
            clip.SampleAnimation(animationRig, seconds);
            for (int i = 0; i < sources.Count; i++) targets[i].localRotation = sources[i].localRotation;
        }
        private void OnDestroy()
        {
            if (animationRig != null) { if (Application.isPlaying) Destroy(animationRig); else DestroyImmediate(animationRig); }
        }
    }
}
