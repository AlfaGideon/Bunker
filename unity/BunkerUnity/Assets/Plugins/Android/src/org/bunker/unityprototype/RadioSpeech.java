package org.bunker.unityprototype;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import java.util.ArrayDeque;
import java.util.Locale;

/** Android TTS lives on the main looper; messages wait for initialization. */
public final class RadioSpeech {
    private static final Handler main = new Handler(Looper.getMainLooper());
    private static final ArrayDeque<String> pending = new ArrayDeque<>();
    private static TextToSpeech engine;
    private static int generation;
    private static volatile String status = "stopped";
    private RadioSpeech() {}

    public static void start(Context context) {
        final Context app = context.getApplicationContext();
        main.post(() -> {
            if (engine != null) return;
            final int token = ++generation;
            status = "initializing";
            try {
                engine = new TextToSpeech(app, result -> {
                    if (token != generation || engine == null) return;
                    if (result != TextToSpeech.SUCCESS || engine.setLanguage(new Locale("ru", "RU")) < 0) {
                        status = "unavailable";
                        pending.clear();
                        return;
                    }
                    status = "ready";
                    while (!pending.isEmpty()) enqueue(pending.removeFirst());
                });
            } catch (RuntimeException e) { engine = null; pending.clear(); status = "unavailable"; }
        });
    }
    public static void speak(String text) {
        if (text == null || text.trim().isEmpty()) return;
        main.post(() -> {
            if ("ready".equals(status)) enqueue(text);
            else if ("initializing".equals(status)) {
                if (pending.size() >= 24) pending.removeFirst();
                pending.addLast(text);
            }
        });
    }
    private static void enqueue(String text) {
        if (engine != null && engine.speak(text, TextToSpeech.QUEUE_ADD, null, "radio") == TextToSpeech.ERROR)
            status = "unavailable";
    }
    public static void cancel() {
        main.post(() -> { pending.clear(); if (engine != null) engine.stop(); });
    }
    public static String getStatus() { return status; }
    public static void shutdown() {
        main.post(() -> {
            generation++; pending.clear();
            if (engine != null) { engine.stop(); engine.shutdown(); engine = null; }
            status = "stopped";
        });
    }
}
