using System;
using System.Linq;

namespace Bunker.UnityPort
{
    public interface IRadioOutput
    {
        void Music(int index); // -1 stops music
        void Speak(string text);
        void CancelSpeech();
    }

    // Independent of the engine: deduplicates snapshots and never replays old history.
    public sealed class RadioPlayback
    {
        private readonly IRadioOutput output;
        private int lastMessage;
        private bool initialized, paused;
        private string mode;
        public RadioPlayback(IRadioOutput output) { this.output = output; }
        public void Sync(RadioState radio)
        {
            if (radio == null) return;
            string next = radio.powered ? radio.station ?? "" : "off";
            string nextMode = next == "aurora" ? "aurora:" + radio.track_index : next;
            if (!paused && mode != nextMode)
            {
                if (mode != null) output.CancelSpeech();
                output.Music(next == "aurora" ? radio.track_index : -1);
                mode = nextMode;
            }
            var messages = radio.received ?? Array.Empty<RadioMessage>();
            if (!initialized)
            {
                lastMessage = Math.Max(radio.message_id, messages.Where(m => m != null).Select(m => m.id).DefaultIfEmpty(0).Max());
                initialized = true;
                return;
            }
            foreach (var message in messages.Where(m => m != null && m.id > lastMessage).OrderBy(m => m.id))
            {
                if (!paused && radio.powered && (next == "bunkers" || next == "beacon") && !string.IsNullOrWhiteSpace(message.text))
                    output.Speak((string.IsNullOrWhiteSpace(message.from) ? "" : message.from + ". ") + message.text);
                lastMessage = Math.Max(lastMessage, message.id);
            }
            lastMessage = Math.Max(lastMessage, radio.message_id);
        }
        public void Pause()
        {
            if (paused) return;
            paused = true; mode = null; output.Music(-1); output.CancelSpeech();
        }
        public void Resume() { paused = false; }
        public void Reset()
        {
            output.Music(-1); output.CancelSpeech();
            initialized = false; lastMessage = 0; mode = null; paused = false;
        }
    }
}
