package com.meysam.dailyreminder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public class AlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        Diagnostics.write(context, "RECEIVER_FIRED");
        Intent service = new Intent(context, AlarmService.class);
        if (intent != null) service.putExtra("title", intent.getStringExtra("title"));
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service);
            else context.startService(service);
            Diagnostics.write(context, "SERVICE_REQUESTED");
        } catch (Exception ex) {
            Diagnostics.write(context, "SERVICE_START_ERROR " + ex.getClass().getSimpleName());
        }
    }
}
