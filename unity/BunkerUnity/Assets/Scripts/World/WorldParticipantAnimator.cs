using UnityEngine;

namespace Bunker.UnityPort.World
{
    // Only a local idle animation for the visual test. Player motion is not synced.
    public sealed class WorldParticipantAnimator : MonoBehaviour
    {
        private AnimationClip idle;
        private float time;
        private void Awake()
        {
            foreach (var clip in Resources.LoadAll<AnimationClip>("People/player_anims_cc0"))
                if (clip.name == "unarmed_idle") { idle = clip; break; }
            if (idle == null) Debug.LogError("Participant idle animation is missing");
            else idle.SampleAnimation(gameObject, 0f);
        }
        private void Update()
        {
            if (idle == null || idle.length <= 0) return;
            time = (time + Time.deltaTime) % idle.length;
            idle.SampleAnimation(gameObject, time);
        }
    }
}
