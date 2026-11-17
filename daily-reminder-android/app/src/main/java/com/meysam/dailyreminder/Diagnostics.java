package com.meysam.dailyreminder;

import android.content.Context;
import android.content.SharedPreferences;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public final class Diagnostics {
    private Diagnostics() {}
    public static synchronized void write(Context context, String event) {
        SharedPreferences p = context.getSharedPreferences("reminder_diagnostics", Context.MODE_PRIVATE);
        String timestamp = new SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(new Date());
        String previous = p.getString("events", "");
        String next = timestamp + " " + event + "\n" + previous;
        p.edit().putString("events", next.substring(0, Math.min(1600, next.length()))).apply();
    }
    public static String read(Context context) {
        return context.getSharedPreferences("reminder_diagnostics", Context.MODE_PRIVATE)
            .getString("events", "هنوز زنگی ثبت نشده");
    }
}
