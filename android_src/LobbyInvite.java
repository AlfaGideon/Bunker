package org.bunker.prototype;

import android.content.Intent;
import android.net.Uri;

/** Captures the latest invitation for consumption by the Godot UI thread. */
public final class LobbyInvite {
    private static String pending = "";
    private LobbyInvite() {}
    public static synchronized void capture(Intent intent) {
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction())) return;
        Uri data = intent.getData();
        if (data != null && "bunkerinvite".equals(data.getScheme()) && "join".equals(data.getHost())) {
            pending = data.toString();
        }
    }
    public static synchronized String consume() {
        String value = pending;
        pending = "";
        return value;
    }
}
