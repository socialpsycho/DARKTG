/*
 * DARKTG settings screen for Telegram-FOSS.
 */
package org.telegram.ui;

import android.content.Context;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.Switch;

import org.telegram.messenger.AndroidUtilities;
import org.telegram.messenger.GhostModeManager;
import org.telegram.messenger.R;
import org.telegram.ui.ActionBar.BaseFragment;
import org.telegram.ui.ActionBar.Theme;

public class DarkTgSettingsActivity extends BaseFragment {

    @Override
    public View createView(Context context) {
        actionBar.setBackButtonImage(R.drawable.ic_ab_back);
        actionBar.setAllowOverlayTitle(true);
        actionBar.setTitle("DARKTG Settings");

        LinearLayout layout = new LinearLayout(context);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));

        addSwitch(context, layout, "Скрыть онлайн",
                GhostModeManager.isHideOnlineEnabled(),
                GhostModeManager::setHideOnlineEnabled);
        addSwitch(context, layout, "Скрыть прочтение",
                GhostModeManager.isHideReadEnabled(),
                GhostModeManager::setHideReadEnabled);
        addSwitch(context, layout, "Скрыть печать",
                GhostModeManager.isHideTypingEnabled(),
                GhostModeManager::setHideTypingEnabled);

        fragmentView = layout;
        return fragmentView;
    }

    private void addSwitch(Context context, LinearLayout parent, String title,
                           boolean checked, OnToggle listener) {
        Switch row = new Switch(context);
        row.setText(title);
        row.setTextSize(16);
        row.setPadding(AndroidUtilities.dp(18), AndroidUtilities.dp(14),
                AndroidUtilities.dp(18), AndroidUtilities.dp(14));
        row.setMinHeight(AndroidUtilities.dp(56));
        row.setChecked(checked);
        row.setOnCheckedChangeListener((button, value) -> listener.set(value));
        parent.addView(row, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));
    }

    private interface OnToggle {
        void set(boolean enabled);
    }
}
