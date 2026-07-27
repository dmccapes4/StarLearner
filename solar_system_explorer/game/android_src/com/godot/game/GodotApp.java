package com.godot.game;

import org.godotengine.godot.GodotActivity;

import android.content.Intent;
import android.os.Bundle;
import android.view.KeyEvent;

import androidx.activity.OnBackPressedCallback;
import androidx.core.splashscreen.SplashScreen;

import java.io.File;

/**
 * Solar System Explorer activity: keep the task alive on Back (progress +
 * enrolled voice clips stay warm), and honor a wipe-save intent from the
 * Star Learner kiosk — same EXTRA_WIPE_SAVE contract as the other titles.
 *
 * Without this, stock Godot quits on Back, which kills the process and
 * surfaces whatever task was underneath (often Language Explorer), leaving
 * the mic held by that other title.
 */
public class GodotApp extends GodotActivity {
	public static final String EXTRA_WIPE_SAVE = "com.dylan.antexplorer.EXTRA_WIPE_SAVE";

	@Override
	public void onCreate(Bundle savedInstanceState) {
		SplashScreen.installSplashScreen(this);
		Intent intent = getIntent();
		if (intent != null && intent.getBooleanExtra(EXTRA_WIPE_SAVE, false)) {
			wipeSaveFiles();
			intent.removeExtra(EXTRA_WIPE_SAVE);
		}
		super.onCreate(savedInstanceState);
		getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
			@Override
			public void handleOnBackPressed() {
				moveTaskToBack(true);
			}
		});
	}

	@Override
	public boolean dispatchKeyEvent(KeyEvent event) {
		// Nav-bar Back on some Motos never reaches OnBackPressedCallback while
		// Godot owns the surface — intercept here and keep the task warm.
		if (event.getKeyCode() == KeyEvent.KEYCODE_BACK
				&& event.getAction() == KeyEvent.ACTION_UP) {
			moveTaskToBack(true);
			return true;
		}
		if (event.getKeyCode() == KeyEvent.KEYCODE_BACK
				&& event.getAction() == KeyEvent.ACTION_DOWN) {
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

	private void wipeSaveFiles() {
		File dir = getFilesDir();
		if (dir == null) {
			return;
		}
		String[] names = {
			"playground_controls.json",
			"nav_mode.json",
			"solar_flyer.json",
		};
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
		File voice = new File(dir, "voice");
		if (voice.isDirectory()) {
			File[] clips = voice.listFiles();
			if (clips != null) {
				for (File clip : clips) {
					if (clip != null && clip.isFile()) {
						//noinspection ResultOfMethodCallIgnored
						clip.delete();
					}
				}
			}
		}
		try {
			new File(dir, ".antphone_wipe").createNewFile();
		} catch (Exception ignored) {
		}
	}
}
