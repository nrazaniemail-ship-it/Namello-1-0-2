import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const read = (f) => fs.readFileSync(f, "utf8");
const index = read("index.html");
const java = read("native/android/MainActivity.java.tpl");

test("layer-order arrows are orange", () => {
  assert.ok(index.includes('RE(ChevronUp,{size:15,color:"#F59E0B"'));
  assert.ok(index.includes('RE(ChevronDown,{size:15,color:"#F59E0B"'));
});

test("widget page has a bottom-right curved back arrow that returns to the app", () => {
  for (const f of ["widget.html", "public/widget.html"]) {
    const w = read(f);
    assert.match(w, /id="backBtn"/);
    assert.match(w, /\.back-btn\s*{[^}]*position:\s*fixed;[^}]*right:[^}]*bottom:/s);
    assert.match(w, /M20 20v-7a4 4 0 0 0-4-4H4/); // curved arrow path
    assert.match(w, /window\.__nmNativeBack\s*=/);
    assert.match(w, /location\.href\s*=\s*'\.\/index\.html'/);
  }
  assert.equal(read("widget.html"), read("public/widget.html"));
});

test("settings call the native Android hooks", () => {
  assert.match(index, /NamelloAndroid\.setLauncherIcon\(next\)/);
  assert.match(index, /NamelloAndroid\.setReturnNotification\(/);
});

test("launcher icon keys match between app and the build script", () => {
  const appKeys = [...index.match(/const NM_ICON_THEMES = \[([\s\S]*?)\n\];/)[1].matchAll(/key: "(\w+)"/g)].map((m) => m[1]);
  const cfgKeys = [...read("scripts/configure-android.mjs").match(/const THEMES = \[([^\]]*)\]/)[1].matchAll(/"(\w+)"/g)].map((m) => m[1]);
  assert.deepEqual(cfgKeys, appKeys);
  for (const k of appKeys.filter((x) => x !== "default")) assert.ok(fs.existsSync(`icon-${k}-512.png`), `icon-${k}-512.png`);
});

test("Navigation bar setting: two modes (تداخل / جدایش) wired from Settings to MainActivity", () => {
  assert.ok(java.includes("WindowInsetsCompat.CONSUMED"), "insets are consumed so nothing is padded twice");
  assert.match(java, /view\.setPadding\(bars\.left, 0, bars\.right, bottom\)/);
  assert.match(java, /separate \? Math\.max\(bars\.bottom, keyboard\.bottom\) : keyboard\.bottom/);
  assert.ok(java.includes("setNavBarMode") && java.includes("getNavBarMode") && java.includes("KEY_NAV_MODE"));
  assert.ok(index.includes("function NmNavBarModeCard"));
  assert.ok(index.includes('title: "Navigation bar"'));
  assert.ok(index.includes('title: "تداخل"') && index.includes('title: "جدایش (پیش‌فرض)"'));
  assert.ok(index.includes('RE(NmNavBarModeCard, { value: navBarMode, onChange: persistNavBarMode })'));
  assert.ok(index.includes('"ns_namello_navbar_mode_v1") === "overlap" ? "overlap" : "separate"'), "default is separate");
  assert.ok(index.includes("window.NamelloAndroid.setNavBarMode(mode)"));
  assert.ok(read("native-bridge.js").includes("namello_navbar_mode_v1"));
  assert.ok(index.includes("var(--nm-safe-top, env(safe-area-inset-top, 0px))"));
  assert.equal((java.match(/\{/g) || []).length, (java.match(/\}/g) || []).length, "balanced braces");
});

test("configure-android produces launcher aliases, permissions and MainActivity (idempotent)", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "nm-android-"));
  const main = path.join(dir, "app/src/main");
  fs.mkdirSync(path.join(main, "java/com/namello/app"), { recursive: true });
  fs.writeFileSync(path.join(dir, "app/build.gradle"), 'android { defaultConfig {\n versionCode 1\n versionName "1.0"\n } }');
  fs.writeFileSync(path.join(main, "java/com/namello/app/MainActivity.java"), "package com.namello.app;\npublic class MainActivity extends com.getcapacitor.BridgeActivity {}\n");
  fs.writeFileSync(path.join(main, "AndroidManifest.xml"), `<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round" android:label="@string/app_name">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>`);
  for (let i = 0; i < 2; i++) {
    const r = spawnSync(process.execPath, ["scripts/configure-android.mjs"], { env: { ...process.env, ANDROID_DIR: dir }, encoding: "utf8" });
    assert.equal(r.status, 0, r.stderr);
  }
  const m = read(path.join(main, "AndroidManifest.xml"));
  assert.equal((m.match(/<activity-alias/g) || []).length, 7);
  assert.equal((m.match(/android:enabled="true"/g) || []).length, 1);
  const act = m.slice(m.indexOf('android:name=".MainActivity"'), m.indexOf("</activity>"));
  assert.ok(!act.includes("LAUNCHER"), "MainActivity itself must not be a launcher entry");
  for (const p of ["POST_NOTIFICATIONS", "SCHEDULE_EXACT_ALARM"]) assert.ok(m.includes(p));
  assert.ok(read(path.join(main, "java/com/namello/app/MainActivity.java")).includes("package com.namello.app;"));
  assert.ok(fs.existsSync(path.join(main, "res/drawable-nodpi/namello_launcher_ruby.png")));
  fs.rmSync(dir, { recursive: true, force: true });
});
