using System;
using UnityEngine;

namespace Bunker.UnityPort
{
    // Native speech uses the device's installed Russian TTS voice, not cloud speech.
    public sealed class RadioAudio : MonoBehaviour, IRadioOutput
    {
        private static readonly string[] Tracks = { "music_campfire", "music_zone", "music_bunker", "music_gate" };
        private AudioSource music;
        private RadioPlayback playback;
        private bool suspended;
        private float nextStatusPoll;
#if UNITY_ANDROID && !UNITY_EDITOR
        private AndroidJavaClass speech;
#endif
        public string VoiceStatus { get; private set; } = "Голос доступен только на Android";
        private void Awake()
        {
            music = gameObject.AddComponent<AudioSource>();
            music.playOnAwake = false; music.loop = true; music.volume = .7f;
            playback = new RadioPlayback(this);
#if UNITY_ANDROID && !UNITY_EDITOR
            try {
                speech = new AndroidJavaClass("org.bunker.unityprototype.RadioSpeech");
                using (var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                using (var activity = player.GetStatic<AndroidJavaObject>("currentActivity")) speech.CallStatic("start", activity);
                VoiceStatus = "Ожидаем русский голос Android…";
            } catch (Exception) { VoiceStatus = "Голос Android недоступен; текст сохранён"; }
#endif
        }
        public void Sync(RadioState radio)
        {
            playback.Sync(radio);
#if UNITY_ANDROID && !UNITY_EDITOR
            if (speech != null && Time.unscaledTime >= nextStatusPoll) try {
                nextStatusPoll = Time.unscaledTime + 1f;
                string state = speech.CallStatic<string>("getStatus");
                VoiceStatus = state == "ready" ? "Русский голос Android" : state == "initializing" ? "Ожидаем русский голос Android…" : "Русский голос недоступен; текст сохранён";
            } catch (Exception) { VoiceStatus = "Голос Android недоступен; текст сохранён"; }
#endif
        }
        public void Music(int index)
        {
            if (music == null) return;
            music.Stop(); music.clip = null;
            if (index < 0 || index >= Tracks.Length) return;
            music.clip = Resources.Load<AudioClip>("RadioMusic/" + Tracks[index]);
            if (music.clip != null) music.Play();
        }
        public void Speak(string text)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            if (speech != null) try { speech.CallStatic("speak", text); } catch (Exception) { VoiceStatus = "Голос Android недоступен; текст сохранён"; }
#endif
        }
        public void CancelSpeech()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            if (speech != null) try { speech.CallStatic("cancel"); } catch (Exception) { }
#endif
        }
        public void ResetRadio() { playback.Reset(); }
        private void OnApplicationPause(bool pause)
        {
            suspended = pause;
            if (pause) playback.Pause(); else playback.Resume();
        }
        public void Restore(RadioState radio) { if (!suspended) Sync(radio); }
        private void OnDestroy()
        {
            if (playback != null) playback.Reset();
#if UNITY_ANDROID && !UNITY_EDITOR
            if (speech != null) { try { speech.CallStatic("shutdown"); } catch (Exception) { } speech.Dispose(); }
#endif
        }
    }
}
