package org.bunker.prototype;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

/** Receives external invitation, forwards it into the existing game process. */
public final class LobbyInviteActivity extends Activity {
    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LobbyInvite.capture(getIntent());
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            startActivity(launch);
        }
        finish();
    }
}
