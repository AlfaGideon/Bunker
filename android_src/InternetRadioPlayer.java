package org.bunker.prototype;

import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Looper;

/** Foreground-only internet stream player. Callbacks run on Android's main looper. */
public final class InternetRadioPlayer {
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static MediaPlayer player;
    private static volatile String state = "stopped";
    private static volatile int generation = 0;
    private static volatile float gain = 0.7f;
    private InternetRadioPlayer() {}

    public static void play(String url, float volume) {
        final int token = ++generation;
        gain = Math.max(0f, Math.min(1f, volume));
        state = "connecting";
        MAIN.post(() -> {
            if (token != generation) return;
            releasePlayer();
            try {
                MediaPlayer next = new MediaPlayer();
                player = next;
                next.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build());
                next.setVolume(gain, gain);
                next.setOnPreparedListener(mp -> {
                    if (token != generation || mp != player) return;
                    try { mp.start(); state = "playing"; }
                    catch (RuntimeException e) { state = "error"; releasePlayer(); }
                });
                next.setOnErrorListener((mp, what, extra) -> {
                    if (token == generation && mp == player) { state = "error"; releasePlayer(); }
                    return true;
                });
                next.setOnCompletionListener(mp -> {
                    if (token == generation && mp == player) { state = "error"; releasePlayer(); }
                });
                next.setDataSource(url);
                next.prepareAsync();
                MAIN.postDelayed(() -> {
                    if (token == generation && "connecting".equals(state)) {
                        state = "error";
                        releasePlayer();
                    }
                }, 20000);
            } catch (Exception e) {
                state = "error";
                releasePlayer();
            }
        });
    }

    public static void stop() {
        ++generation;
        state = "stopped";
        MAIN.post(InternetRadioPlayer::releasePlayer);
    }
    public static void setVolume(float value) {
        gain = Math.max(0f, Math.min(1f, value));
        MAIN.post(() -> { if (player != null) try { player.setVolume(gain, gain); } catch (RuntimeException ignored) {} });
    }
    public static String getState() { return state; }
    private static void releasePlayer() {
        if (player != null) { player.release(); player = null; }
    }
}
