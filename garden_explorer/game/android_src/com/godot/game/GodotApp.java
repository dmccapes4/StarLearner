package com.godot.game;

import org.godotengine.godot.GodotActivity;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import androidx.activity.OnBackPressedCallback;
import androidx.core.splashscreen.SplashScreen;

import java.io.File;

/**
 * Garden Explorer — Back returns to Star Learner; EXTRA_WIPE_SAVE clears progress.
 */
public class GodotApp extends GodotActivity {
	private static GodotApp instance;

	public static final String EXTRA_WIPE_SAVE = "com.dylan.star_learner.EXTRA_WIPE_SAVE";

	@Override
	public void onCreate(Bundle savedInstanceState) {
		SplashScreen.installSplashScreen(this);
		Intent intent = getIntent();
		if (intent != null && intent.getBooleanExtra(EXTRA_WIPE_SAVE, false)) {
			wipeSaveFiles();
			intent.removeExtra(EXTRA_WIPE_SAVE);
		}
		super.onCreate(savedInstanceState);
		instance = this;
		// Past Godot splash (~2.5s): Back becomes PAUSE instead of home.
		new Handler(Looper.getMainLooper()).postDelayed(() -> {
			backHijackEnabled = true;
			android.util.Log.i("GodotApp", "back hijack auto-armed");
		}, 2500L);
		getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
			@Override
			public void handleOnBackPressed() {
				if (!backHijackEnabled) {
					moveTaskToBack(true);
					return;
				}
				requestPauseFromBack();
			}
		});

	}





	public static GodotApp getInstance() {
		return instance;
	}

	/** False during Godot splash — Back returns to Star Learner.
	 *  Auto-armed after splash; IdleGuard may also call setBackHijackEnabled. */
	private volatile boolean backHijackEnabled = false;
	/** Set on Back while hijacked; IdleGuard polls and clears via consumeBackPause. */
	private volatile boolean pendingBackPause = false;

	/** Called from Godot IdleGuard via AndroidRuntime.getActivity(). */
	public void setBackHijackEnabled(boolean enabled) {
		backHijackEnabled = enabled;
	}

	/** IdleGuard polls this each frame while hijack is on. */
	public boolean consumeBackPause() {
		if (!pendingBackPause) {
			return false;
		}
		pendingBackPause = false;
		return true;
	}

	@Override
	public boolean dispatchKeyEvent(android.view.KeyEvent event) {
		if (event.getKeyCode() == android.view.KeyEvent.KEYCODE_BACK) {
			if (!backHijackEnabled) {
				// Splash / boot logo — normal kiosk Back (warm task, no pause UI yet).
				if (event.getAction() == android.view.KeyEvent.ACTION_UP) {
					moveTaskToBack(true);
				}
				return true;
			}
			// Game ready: do NOT finish / moveTaskToBack — IdleGuard shows PAUSED.
			if (event.getAction() == android.view.KeyEvent.ACTION_UP) {
				requestPauseFromBack();
			}
			return true;
		}
		return super.dispatchKeyEvent(event);
	}


	@Override
	public void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		setIntent(intent);
		if (intent != null && intent.getBooleanExtra(EXTRA_WIPE_SAVE, false)) {
			wipeSaveFiles();
			intent.removeExtra(EXTRA_WIPE_SAVE);
		}
	}

	@Override
	protected void onDestroy() {
		if (instance == this) {
			instance = null;
		}
		super.onDestroy();
	}


	private android.view.View pauseOverlay;

	private void requestPauseFromBack() {
		pendingBackPause = true;
		runOnUiThread(this::showPauseOverlay);
	}

	private void showPauseOverlay() {
		if (pauseOverlay != null) {
			return;
		}
		android.widget.FrameLayout root = findViewById(android.R.id.content);
		if (root == null) {
			return;
		}
		android.widget.FrameLayout overlay = new android.widget.FrameLayout(this);
		overlay.setBackgroundColor(0x8C000000);
		overlay.setClickable(true);
		overlay.setOnClickListener(v -> hidePauseOverlay());

		android.widget.TextView label = new android.widget.TextView(this);
		label.setText("PAUSED");
		label.setTextColor(0xFFFFFFFF);
		label.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 48);
		label.setGravity(android.view.Gravity.CENTER);
		overlay.addView(label, new android.widget.FrameLayout.LayoutParams(
				android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
				android.widget.FrameLayout.LayoutParams.MATCH_PARENT));

		android.widget.Button back = new android.widget.Button(this);
		back.setText("◀");
		back.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 48);
		back.setTextColor(0xFF26190D);
		back.setAllCaps(false);
		back.setGravity(android.view.Gravity.CENTER);
		back.setIncludeFontPadding(false);
		back.setPadding(0, 0, 0, 0);
		back.setMinWidth(0);
		back.setMinHeight(0);
		android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
		bg.setColor(0xFAF2DB73);
		bg.setCornerRadius(dp(18));
		bg.setStroke(dp(4), 0xE6FFFFFF);
		back.setBackground(bg);
		android.widget.FrameLayout.LayoutParams bp = new android.widget.FrameLayout.LayoutParams(dp(112), dp(88));
		bp.gravity = android.view.Gravity.TOP | android.view.Gravity.START;
		bp.setMargins(dp(28), dp(28), 0, 0);
		back.setOnClickListener(v -> {
			// Keep overlay for warm return; go to Star Learner.
			moveTaskToBack(true);
		});
		overlay.addView(back, bp);

		root.addView(overlay, new android.widget.FrameLayout.LayoutParams(
				android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
				android.widget.FrameLayout.LayoutParams.MATCH_PARENT));
		pauseOverlay = overlay;
		android.util.Log.i("GodotApp", "pause overlay shown");
	}

	/** Called from IdleGuard / tap-to-resume. */
	public void hidePauseOverlay() {
		runOnUiThread(() -> {
			if (pauseOverlay == null) {
				return;
			}
			android.view.ViewParent parent = pauseOverlay.getParent();
			if (parent instanceof android.view.ViewGroup) {
				((android.view.ViewGroup) parent).removeView(pauseOverlay);
			}
			pauseOverlay = null;
			pendingBackPause = false;
			android.util.Log.i("GodotApp", "pause overlay hidden");
		});
	}

	public boolean isPauseOverlayShowing() {
		return pauseOverlay != null;
	}

	private int dp(int v) {
		return Math.round(v * getResources().getDisplayMetrics().density);
	}

	private void wipeSaveFiles() {
		File dir = getFilesDir();
		if (dir == null) {
			return;
		}
		String[] names = {"garden_explorer_save.json"};
		for (String name : names) {
			File f = new File(dir, name);
			if (f.isFile()) {
				//noinspection ResultOfMethodCallIgnored
				f.delete();
			}
		}
		File[] children = dir.listFiles();
		if (children != null) {
			for (File child : children) {
				if (child != null && child.isFile() && child.getName().endsWith("_save.json")) {
					//noinspection ResultOfMethodCallIgnored
					child.delete();
				}
			}
		}
		try {
			File wipe = new File(dir, ".antphone_wipe");
			//noinspection ResultOfMethodCallIgnored
			wipe.createNewFile();
		} catch (Exception ignored) {
		}
	}
}
