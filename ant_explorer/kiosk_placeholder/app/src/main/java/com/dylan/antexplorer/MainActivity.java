package com.dylan.antexplorer;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.AlertDialog;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Outline;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewOutlineProvider;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.VideoView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Star Learner home shell — catalog of educational game tiles.
 * Progress lives in each game; Back returns here without wiping.
 * Long-press a tile for a rare full reset. Help (?) narrates how to use the kiosk.
 */
public class MainActivity extends Activity implements TextToSpeech.OnInitListener {

    private static final String CATALOG_PRIMARY = "/sdcard/AntPhone/catalog.json";
    private static final String CATALOG_FALLBACK = "/data/local/tmp/antphone_catalog.json";
    /** Where deploy pushes the per-game explainer videos (first readable wins). */
    private static final String[] VIDEO_DIRS = {
            "/sdcard/AntPhone/videos", "/data/local/tmp/antphone_videos"};
    private static final String COLONY_PACKAGE = "com.dylan.antexplorer.colony";
    private static final String EXTRA_WIPE_SAVE = "com.dylan.antexplorer.EXTRA_WIPE_SAVE";

    private static final String HELP_SCRIPT =
            "Welcome to Star Learner. Tap a game to play. "
                    + "Press Back anytime to come home here — your progress is saved. "
                    + "To start a game all the way over, press and hold its picture, then choose Start over.";

    private final Handler handler = new Handler(Looper.getMainLooper());
    private LinearLayout tileRow;
    private FrameLayout rootLayout;
    private FrameLayout videoOverlay;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    /** Last game package we launched — used to show the restart chip while it is alive. */
    private String activeGamePackage = null;
    private final Runnable keepImmersive = new Runnable() {
        @Override public void run() {
            applyImmersive();
            tryStartLockTask();
            handler.postDelayed(this, 2500);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        | WindowManager.LayoutParams.FLAG_FULLSCREEN
                        | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        );

        tts = new TextToSpeech(this, this);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(0xFF1B3D24);
        rootLayout = root;

        // Subtle help control — top-left, narrates kiosk instructions.
        Button help = makeHelpChip();
        FrameLayout.LayoutParams hp = new FrameLayout.LayoutParams(dp(44), dp(44));
        hp.gravity = Gravity.TOP | Gravity.START;
        hp.setMargins(dp(12), dp(10), 0, 0);
        root.addView(help, hp);
        help.setOnClickListener(v -> speak(HELP_SCRIPT, "help"));

        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setGravity(Gravity.CENTER);
        column.setPadding(dp(16), dp(12), dp(16), dp(12));

        TextView brand = new TextView(this);
        brand.setText("Star Learner");
        brand.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28);
        brand.setTextColor(0xFFE8F5E9);
        brand.setTypeface(Typeface.DEFAULT_BOLD);
        brand.setGravity(Gravity.CENTER);
        column.addView(brand);

        TextView sub = new TextView(this);
        sub.setText("pick a game");
        sub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        sub.setTextColor(0xFFA5D6A7);
        sub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        sp.topMargin = dp(2);
        sp.bottomMargin = dp(12);
        column.addView(sub, sp);

        tileRow = new LinearLayout(this);
        tileRow.setOrientation(LinearLayout.HORIZONTAL);
        tileRow.setGravity(Gravity.CENTER);
        column.addView(tileRow);

        root.addView(column, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        setContentView(root);

        rebuildTiles();
        applyImmersive();
        ensureLockTaskPackages();
        tryStartLockTask();
    }

    @Override
    public void onInit(int status) {
        ttsReady = status == TextToSpeech.SUCCESS;
        if (ttsReady && tts != null) {
            tts.setLanguage(Locale.US);
            tts.setSpeechRate(0.95f);
        }
    }

    @Override
    protected void onDestroy() {
        if (tts != null) {
            tts.stop();
            tts.shutdown();
            tts = null;
        }
        super.onDestroy();
    }

    @Override
    protected void onResume() {
        super.onResume();
        rebuildTiles();
        applyImmersive();
        ensureLockTaskPackages();
        tryStartLockTask();
        handler.removeCallbacks(keepImmersive);
        handler.postDelayed(keepImmersive, 800);
    }

    @Override
    protected void onPause() {
        handler.removeCallbacks(keepImmersive);
        super.onPause();
    }

    @Override
    public void onBackPressed() {
        // Close a playing video first; otherwise stay in launcher.
        if (videoOverlay != null) {
            closeVideoOverlay();
            return;
        }
        rebuildTiles();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) applyImmersive();
    }

    private void speak(String text, String utteranceId) {
        if (text == null || text.isEmpty()) return;
        if (!ttsReady || tts == null) {
            Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
            return;
        }
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId);
    }

    // All catalog tiles share one size (dp). Silver rounded frame on the art.
    private static final int TILE_BOX_DP = 180;
    private static final int TILE_IMG_DP = 168;
    private static final int TILE_MARGIN_DP = 12;
    private static final int TILE_CORNER_DP = 24;
    private static final int TILE_BORDER_DP = 7;
    private static final int SILVER = 0xFFE8ECF2;
    // Match the silver plate so clip/AA hairlines don't flash a dark ring.
    private static final int FRAME_FILL = 0xFFE8ECF2;

    private void rebuildTiles() {
        tileRow.removeAllViews();
        List<Tile> tiles = loadCatalog();
        if (tiles.isEmpty()) {
            tiles.add(Tile.builtinAnts());
        }
        for (Tile t : tiles) {
            tileRow.addView(makeTileView(t));
        }
    }

    private View makeTileView(final Tile t) {
        int boxDp = TILE_BOX_DP;
        int imgDp = TILE_IMG_DP;

        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(Gravity.CENTER_HORIZONTAL);
        LinearLayout.LayoutParams bp = new LinearLayout.LayoutParams(dp(boxDp), LinearLayout.LayoutParams.WRAP_CONTENT);
        bp.setMargins(dp(TILE_MARGIN_DP), 0, dp(TILE_MARGIN_DP), 0);
        bp.gravity = Gravity.CENTER_VERTICAL;
        box.setLayoutParams(bp);

        // Layered frame: full silver outer plate + inset dark fill. A GradientDrawable
        // stroke is centered on the edge and gets half-clipped by the view bounds;
        // the inset layer keeps the entire silver ring visible.
        FrameLayout imgWrap = new FrameLayout(this);
        final int borderPx = dp(TILE_BORDER_DP);
        final float outerR = dp(TILE_CORNER_DP);
        final float innerR = Math.max(0f, outerR - borderPx);
        GradientDrawable silver = new GradientDrawable();
        silver.setShape(GradientDrawable.RECTANGLE);
        silver.setCornerRadius(outerR);
        silver.setColor(SILVER);
        GradientDrawable fill = new GradientDrawable();
        fill.setShape(GradientDrawable.RECTANGLE);
        fill.setCornerRadius(innerR);
        fill.setColor(FRAME_FILL);
        LayerDrawable frame = new LayerDrawable(new android.graphics.drawable.Drawable[]{silver, fill});
        frame.setLayerInset(1, borderPx, borderPx, borderPx, borderPx);
        imgWrap.setBackground(frame);
        imgWrap.setPadding(borderPx, borderPx, borderPx, borderPx);
        imgWrap.setClipToOutline(false);
        box.addView(imgWrap, new LinearLayout.LayoutParams(dp(imgDp), dp(imgDp)));

        ImageView img = new ImageView(this);
        int res = getResources().getIdentifier(t.drawableName, "drawable", getPackageName());
        if (res != 0) {
            img.setImageResource(res);
        } else {
            img.setImageResource(R.drawable.tile_ants);
        }
        img.setScaleType(ImageView.ScaleType.CENTER_CROP);
        img.setAdjustViewBounds(false);
        img.setOutlineProvider(new ViewOutlineProvider() {
            @Override
            public void getOutline(View view, Outline outline) {
                outline.setRoundRect(0, 0, view.getWidth(), view.getHeight(), innerR);
            }
        });
        img.setClipToOutline(true);
        imgWrap.addView(img, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        FrameLayout under = new FrameLayout(this);
        LinearLayout.LayoutParams up = new LinearLayout.LayoutParams(dp(imgDp), ViewGroup.LayoutParams.WRAP_CONTENT);
        up.topMargin = dp(6);
        under.setLayoutParams(up);

        TextView label = new TextView(this);
        label.setText(t.label);
        label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        label.setTextColor(Color.WHITE);
        label.setTypeface(Typeface.DEFAULT_BOLD);
        label.setGravity(Gravity.CENTER);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER);
        under.addView(label, lp);

        if (isGameInProgress(t.packageName)) {
            // Tiny resume hint — long-press is the rare full wipe.
            Button restart = makeRestartChip();
            FrameLayout.LayoutParams rp = new FrameLayout.LayoutParams(dp(36), dp(36), Gravity.BOTTOM | Gravity.END);
            rp.topMargin = dp(2);
            under.addView(restart, rp);
            restart.setOnClickListener(v -> confirmStartOver(t));
        }

        box.addView(under);

        // ▶ chip below the label — plays this game's explainer video, if deployed.
        final File video = resolveVideo(t.videoName);
        if (video != null) {
            Button play = makePlayChip();
            LinearLayout.LayoutParams pp = new LinearLayout.LayoutParams(dp(40), dp(40));
            pp.topMargin = dp(6);
            pp.gravity = Gravity.CENTER_HORIZONTAL;
            box.addView(play, pp);
            play.setOnClickListener(v -> showVideoOverlay(video));
        }

        box.setOnClickListener(v -> launchTile(t, false));
        box.setOnLongClickListener(v -> {
            confirmStartOver(t);
            return true;
        });
        box.setClickable(true);
        box.setFocusable(true);
        box.setLongClickable(true);
        return box;
    }

    private Button makeHelpChip() {
        Button b = new Button(this);
        b.setText("?");
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        b.setTextColor(0xFFE8F5E9);
        b.setPadding(0, 0, 0, 0);
        b.setMinWidth(0);
        b.setMinHeight(0);
        b.setAllCaps(false);
        b.setContentDescription("How to use Star Learner");
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0x552E7D32);
        bg.setCornerRadius(dp(22));
        bg.setStroke(dp(1), 0x66A5D6A7);
        b.setBackground(bg);
        return b;
    }

    private Button makePlayChip() {
        Button b = new Button(this);
        b.setText("\u25B6");
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        b.setTextColor(0xFF1B3D24);
        b.setPadding(0, 0, 0, 0);
        b.setMinWidth(0);
        b.setMinHeight(0);
        b.setAllCaps(false);
        b.setContentDescription("Watch what this game is about");
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xFFFFD54F);
        bg.setCornerRadius(dp(20));
        bg.setStroke(dp(1), 0x66FFFFFF);
        b.setBackground(bg);
        return b;
    }

    /** First readable copy of the named explainer video, or null. */
    private File resolveVideo(String name) {
        if (name == null || name.isEmpty()) return null;
        // Already cached in private storage? (mediaserver can always read that)
        File cached = new File(new File(getFilesDir(), "videos"), name);
        if (cached.canRead() && cached.length() > 0) return cached;
        for (String dir : VIDEO_DIRS) {
            File f = new File(dir, name);
            if (f.canRead()) return f;
        }
        return null;
    }

    /**
     * MediaPlayer (mediaserver) cannot open /data/local/tmp or scoped /sdcard
     * paths even when this app can. Copy into private files/ once and play that.
     */
    private File cacheVideoForPlayback(File src) {
        File dir = new File(getFilesDir(), "videos");
        File dst = new File(dir, src.getName());
        if (dst.equals(src)) return dst;
        if (dst.canRead() && dst.length() == src.length()) return dst;
        try {
            if (!dir.isDirectory() && !dir.mkdirs()) return src;
            try (FileInputStream in = new FileInputStream(src);
                 java.io.FileOutputStream out = new java.io.FileOutputStream(dst)) {
                byte[] buf = new byte[1 << 16];
                int n;
                while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            }
            return dst;
        } catch (Exception e) {
            android.util.Log.w("StarLearner", "video cache copy failed", e);
            return src;
        }
    }

    /** Fullscreen in-launcher video player. Tap anywhere (or finish) to close. */
    private void showVideoOverlay(File file) {
        if (videoOverlay != null) closeVideoOverlay();
        if (tts != null) tts.stop();

        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackgroundColor(0xFF000000);
        overlay.setClickable(true);

        VideoView vv = new VideoView(this);
        FrameLayout.LayoutParams vp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER);
        overlay.addView(vv, vp);

        TextView hint = new TextView(this);
        hint.setText("tap to close");
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        hint.setTextColor(0x99FFFFFF);
        FrameLayout.LayoutParams hp2 = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.END);
        hp2.setMargins(0, 0, dp(16), dp(10));
        overlay.addView(hint, hp2);

        overlay.setOnClickListener(v -> closeVideoOverlay());
        vv.setOnCompletionListener(mp -> closeVideoOverlay());
        vv.setOnErrorListener((mp, what, extra) -> {
            Toast.makeText(this, "can't play video", Toast.LENGTH_SHORT).show();
            closeVideoOverlay();
            return true;
        });

        rootLayout.addView(overlay, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        videoOverlay = overlay;

        vv.setVideoPath(cacheVideoForPlayback(file).getAbsolutePath());
        vv.start();
        applyImmersive();
    }

    private void closeVideoOverlay() {
        if (videoOverlay == null) return;
        FrameLayout overlay = videoOverlay;
        videoOverlay = null;
        // Stop playback before detach so the media player releases cleanly.
        for (int i = 0; i < overlay.getChildCount(); i++) {
            View child = overlay.getChildAt(i);
            if (child instanceof VideoView) {
                try { ((VideoView) child).stopPlayback(); } catch (Exception ignored) {}
            }
        }
        rootLayout.removeView(overlay);
        applyImmersive();
    }

    private Button makeRestartChip() {
        Button b = new Button(this);
        b.setText("↻");
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        b.setTextColor(Color.WHITE);
        b.setPadding(0, 0, 0, 0);
        b.setMinWidth(0);
        b.setMinHeight(0);
        b.setAllCaps(false);
        b.setContentDescription("Start over");
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0x99E53935);
        bg.setCornerRadius(dp(18));
        b.setBackground(bg);
        return b;
    }

    private void confirmStartOver(final Tile t) {
        String name = t.enterName != null && !t.enterName.isEmpty() ? t.enterName : t.label;
        new AlertDialog.Builder(this)
                .setTitle("Start over?")
                .setMessage("Erase progress in " + name + " and begin from the start?")
                .setNegativeButton("Cancel", (d, w) -> applyImmersive())
                .setPositiveButton("Start over", (d, w) -> {
                    launchTile(t, true);
                    applyImmersive();
                })
                .setOnDismissListener(d -> applyImmersive())
                .show();
    }

    private Intent gameLaunchIntent(Tile t) {
        // Prefer the package-manager launcher intent (correct component + extras).
        Intent launch = getPackageManager().getLaunchIntentForPackage(t.packageName);
        if (launch == null && t.activity != null && !t.activity.isEmpty()) {
            launch = new Intent(Intent.ACTION_MAIN);
            launch.addCategory(Intent.CATEGORY_LAUNCHER);
            launch.setClassName(t.packageName, t.activity);
        }
        if (launch == null && COLONY_PACKAGE.equals(t.packageName)) {
            launch = new Intent(Intent.ACTION_MAIN);
            launch.addCategory(Intent.CATEGORY_LAUNCHER);
            launch.setClassName(COLONY_PACKAGE, "com.godot.game.GodotApp");
        }
        return launch;
    }

    private boolean isGameInProgress(String packageName) {
        if (packageName == null || packageName.isEmpty()) return false;
        if (packageName.equals(getPackageName())) return false;
        boolean tracked = packageName.equals(activeGamePackage);
        boolean running = isPackageProcessRunning(packageName);
        if (!running && tracked) {
            activeGamePackage = null;
            return false;
        }
        return running;
    }

    private boolean isPackageProcessRunning(String packageName) {
        ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        if (am == null) return false;
        try {
            for (ActivityManager.RunningAppProcessInfo proc : am.getRunningAppProcesses()) {
                if (proc == null) continue;
                if (packageName.equals(proc.processName)) return true;
                if (proc.pkgList != null) {
                    for (String p : proc.pkgList) {
                        if (packageName.equals(p)) return true;
                    }
                }
            }
        } catch (Exception ignored) {}
        return false;
    }

    private void launchTile(Tile t, boolean wipeSave) {
        try {
            if (getPackageName().equals(t.packageName)) {
                Toast.makeText(this, "coming soon", Toast.LENGTH_SHORT).show();
                return;
            }
            // Refresh lock-task whitelist so newly installed catalog games can open.
            ensureLockTaskPackages();
            Intent launch = gameLaunchIntent(t);
            if (launch == null) {
                Toast.makeText(this, "not installed yet", Toast.LENGTH_SHORT).show();
                return;
            }
            if (wipeSave) {
                launch.putExtra(EXTRA_WIPE_SAVE, true);
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                // Force a new process so Save reloads empty (in-memory autoload is sticky).
                forceStopPackage(t.packageName);
            } else {
                // Resume existing task when possible — keeps mid-session progress warm.
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            }
            if (!isLockTaskPermitted(t.packageName)) {
                try { stopLockTask(); } catch (Exception ignored) {}
            }
            String line = t.enterLine;
            if (line == null || line.isEmpty()) {
                String name = t.enterName != null && !t.enterName.isEmpty() ? t.enterName : t.label;
                line = "You are entering " + name;
            }
            // Speak first, then start immediately. A delayed startActivity loses the
            // tap's "user gesture" token on modern Android and fails with can't-open.
            speak(line, "enter:" + t.id);
            activeGamePackage = t.packageName;
            startActivity(launch);
        } catch (Exception e) {
            // One retry after leaving lock-task — covers whitelist race on first launch.
            try {
                stopLockTask();
                Intent retry = gameLaunchIntent(t);
                if (retry != null) {
                    retry.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
                    if (wipeSave) {
                        retry.putExtra(EXTRA_WIPE_SAVE, true);
                        retry.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    }
                    startActivity(retry);
                    return;
                }
            } catch (Exception ignored) {}
            android.util.Log.e("StarLearner", "launch failed: " + t.packageName, e);
            Toast.makeText(this, "can't open", Toast.LENGTH_SHORT).show();
        }
    }

    private List<Tile> loadCatalog() {
        List<Tile> out = new ArrayList<>();
        String json = readFile(CATALOG_FALLBACK);
        if (json == null) json = readFile(CATALOG_PRIMARY);
        if (json == null) json = readAssetCatalog();
        if (json == null) return out;
        try {
            JSONObject root = new JSONObject(json);
            JSONArray apps = root.optJSONArray("apps");
            if (apps == null) return out;
            for (int i = 0; i < apps.length(); i++) {
                JSONObject o = apps.getJSONObject(i);
                Tile t = new Tile();
                t.id = o.optString("id", "app" + i);
                t.label = o.optString("label", t.id);
                t.packageName = o.optString("package", "");
                t.activity = o.has("activity") ? o.optString("activity", null) : null;
                t.drawableName = o.optString("tile", "tile_ants");
                t.enterName = o.optString("enter_name", o.optString("title", ""));
                t.enterLine = o.optString("enter_line", "");
                t.videoName = o.optString("video", "");
                t.preview = o.optBoolean("preview", false);
                if (!t.packageName.isEmpty()) out.add(t);
            }
        } catch (Exception ignored) {}
        return out;
    }

    private String readAssetCatalog() {
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(getAssets().open("catalog.json"), StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append('\n');
            return sb.toString();
        } catch (Exception e) {
            return null;
        }
    }

    private static String readFile(String path) {
        File f = new File(path);
        if (!f.canRead()) return null;
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(new FileInputStream(f), StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append('\n');
            return sb.toString();
        } catch (Exception e) {
            return null;
        }
    }

    private void applyImmersive() {
        View decor = getWindow().getDecorView();
        decor.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        );
    }

    private void ensureLockTaskPackages() {
        try {
            DevicePolicyManager dpm =
                    (DevicePolicyManager) getSystemService(Context.DEVICE_POLICY_SERVICE);
            if (dpm == null || !dpm.isDeviceOwnerApp(getPackageName())) return;
            ComponentName admin = new ComponentName(this, AdminReceiver.class);
            // Whitelist every catalog game so she can move between them under lock-task.
            List<String> pkgs = new ArrayList<>();
            pkgs.add(getPackageName());
            for (Tile t : loadCatalog()) {
                if (t.packageName != null && !t.packageName.isEmpty() && !pkgs.contains(t.packageName)) {
                    pkgs.add(t.packageName);
                }
            }
            if (!pkgs.contains(COLONY_PACKAGE)) pkgs.add(COLONY_PACKAGE);
            dpm.setLockTaskPackages(admin, pkgs.toArray(new String[0]));
        } catch (Exception ignored) {}
    }

    private boolean isLockTaskPermitted(String packageName) {
        try {
            DevicePolicyManager dpm =
                    (DevicePolicyManager) getSystemService(Context.DEVICE_POLICY_SERVICE);
            return dpm != null && packageName != null && dpm.isLockTaskPermitted(packageName);
        } catch (Exception e) {
            return false;
        }
    }

    private void tryStartLockTask() {
        try {
            if (!isLockTaskPermitted(getPackageName())) return;
            ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
            if (am != null && am.getLockTaskModeState() == ActivityManager.LOCK_TASK_MODE_NONE) {
                startLockTask();
            }
        } catch (Exception ignored) {}
    }

    /** Best-effort process kill so wipe/start-over always cold-boots the game. */
    private void forceStopPackage(String packageName) {
        try {
            ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
            if (am == null) return;
            java.lang.reflect.Method m =
                    ActivityManager.class.getMethod("forceStopPackage", String.class);
            m.invoke(am, packageName);
        } catch (Exception e) {
            try {
                ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
                if (am != null) am.killBackgroundProcesses(packageName);
            } catch (Exception ignored) {}
        }
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }

    private static class Tile {
        String id;
        String label;
        String packageName;
        String activity;
        String drawableName;
        String enterName;
        String enterLine;
        String videoName;
        boolean preview;

        static Tile builtinAnts() {
            Tile t = new Tile();
            t.id = "colony";
            t.label = "ants";
            t.packageName = COLONY_PACKAGE;
            t.activity = "com.godot.game.GodotApp";
            t.drawableName = "tile_ants";
            t.enterName = "Ant Explorer";
            t.enterLine = "You are entering Ant Explorer";
            return t;
        }
    }
}
