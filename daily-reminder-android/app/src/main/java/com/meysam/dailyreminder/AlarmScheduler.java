package com.meysam.dailyreminder;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import org.json.JSONArray;
import org.json.JSONObject;
import java.time.Instant;

public final class AlarmScheduler {
    private static final String PREFS = "daily_reminder_native";
    private static final String KEY = "tasks";
    private AlarmScheduler() {}

    public static synchronized void sync(Context context, String json) {
        try {
            JSONArray incoming = new JSONArray(json);
            if (incoming.length() > 200) return;
            SharedPreferences p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            String previous = p.getString(KEY, "[]");
            if (previous.equals(json)) return;
            cancelAll(context, previous);
            p.edit().putString(KEY, json).apply();
            scheduleAll(context, json);
        } catch (Exception ignored) { }
    }

    public static synchronized void rescheduleAll(Context context) {
        String json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]");
        cancelAll(context, json);
        scheduleAll(context, json);
    }

    public static boolean scheduleTest(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return false;
        if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) return false;
        PendingIntent pi = pending(context, "native_alarm_test", "آزمایش زنگ پنج ثانیه‌ای", PendingIntent.FLAG_UPDATE_CURRENT);
        if (pi == null) return false;
        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 60000, pi);
        return true;
    }

    private static void cancelAll(Context context, String json) {
        try {
            JSONArray tasks = new JSONArray(json);
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            for (int i = 0; i < tasks.length(); i++) {
                JSONObject task = tasks.optJSONObject(i);
                if (task == null) continue;
                PendingIntent pi = pending(context, task.optString("id"), task.optString("title"), PendingIntent.FLAG_NO_CREATE);
                if (pi != null) { am.cancel(pi); pi.cancel(); }
            }
        } catch (Exception ignored) { }
    }

    private static void scheduleAll(Context context, String json) {
        try {
            JSONArray tasks = new JSONArray(json);
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            long now = System.currentTimeMillis();
            for (int i = 0; i < tasks.length(); i++) {
                JSONObject task = tasks.optJSONObject(i);
                if (task == null || "done".equals(task.optString("status")) || task.optBoolean("alarm_fired")) continue;
                String due = task.optString("due_at", "");
                if (due.isEmpty() || due.equals("null")) continue;
                long when;
                try { when = Instant.parse(due).toEpochMilli(); }
                catch (Exception ex) { continue; }
                if (when <= now) continue;
                PendingIntent pi = pending(context, task.optString("id"), task.optString("title"), PendingIntent.FLAG_UPDATE_CURRENT);
                if (pi == null) continue;
                try {
                    if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
                    } else {
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
                    }
                } catch (SecurityException ex) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
                }
            }
        } catch (Exception ignored) { }
    }

    private static PendingIntent pending(Context context, String id, String title, int flag) {
        if (id == null || id.isEmpty()) return null;
        Intent intent = new Intent(context, AlarmReceiver.class);
        intent.setAction("com.meysam.dailyreminder.RING");
        intent.setData(Uri.parse("reminder://alarm/" + Uri.encode(id)));
        intent.putExtra("title", title);
        return PendingIntent.getBroadcast(context, id.hashCode(), intent, flag | PendingIntent.FLAG_IMMUTABLE);
    }
}
