/*
 * DARKTG privacy controls for Telegram-FOSS.
 * Distributed as a modification under the upstream GPL-2.0 license.
 */
package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;

import org.telegram.tgnet.TLObject;

public final class GhostModeManager {
    private static final String PREFS = "darktg_ghost_mode";
    private static final String HIDE_ONLINE = "hide_online";
    private static final String HIDE_READ = "hide_read";
    private static final String HIDE_TYPING = "hide_typing";

    private GhostModeManager() {}

    private static SharedPreferences prefs() {
        Context context = ApplicationLoader.applicationContext;
        return context == null ? null :
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static boolean get(String key) {
        SharedPreferences p = prefs();
        return p != null && p.getBoolean(key, false);
    }

    private static void put(String key, boolean value) {
        SharedPreferences p = prefs();
        if (p != null) p.edit().putBoolean(key, value).apply();
    }

    public static boolean isHideOnlineEnabled() { return get(HIDE_ONLINE); }
    public static boolean isHideReadEnabled() { return get(HIDE_READ); }
    public static boolean isHideTypingEnabled() { return get(HIDE_TYPING); }

    public static boolean isEnabled() {
        return isHideOnlineEnabled() || isHideReadEnabled() || isHideTypingEnabled();
    }

    public static void setHideOnlineEnabled(boolean value) { put(HIDE_ONLINE, value); }
    public static void setHideReadEnabled(boolean value) { put(HIDE_READ, value); }
    public static void setHideTypingEnabled(boolean value) { put(HIDE_TYPING, value); }

    /**
     * Filters outgoing MTProto requests before serialization. Telegram's
     * updateUserStatus is an incoming update; the outgoing presence request
     * is account.updateStatus. Request names are checked by class name so
     * this helper remains resilient to generated TLRPC nesting changes.
     */
    public static boolean shouldBlockRequest(TLObject request) {
        if (request == null) return false;
        String type = request.getClass().getSimpleName();

        if (isHideOnlineEnabled() && "TL_account_updateStatus".equals(type)) {
            return true;
        }
        if (isHideTypingEnabled() && "TL_messages_setTyping".equals(type)) {
            return true;
        }
        if (isHideReadEnabled()) {
            return "TL_messages_readMessages".equals(type)
                    || "TL_messages_readHistory".equals(type)
                    || "TL_channels_readHistory".equals(type)
                    || "TL_messages_readMessageContents".equals(type)
                    || "TL_channels_readMessageContents".equals(type);
        }
        return false;
    }
}
