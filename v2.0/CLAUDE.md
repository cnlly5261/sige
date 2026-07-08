# Sige — Engineering Notes

> **Slogan**: 息止屏幕，界守双眼 / Rest the screen. Shield the eyes.
>
> **Product page**: https://sige-break-reminder.surge.sh

## Project Snapshot

Sige is a macOS menu-bar break reminder built with native SwiftUI + AppKit and no third-party app dependencies. The repository root is versioned manually:

- `../v1.1/`: archived v1.1 implementation. Treat as read-only.
- `./`: active v2.0 workspace.

Current v2.0 scope:

- Refined fixed-sidebar settings window.
- Sidebar label uses `界面 / Interface`, not `休息界面 / Break Screen`.
- Full-screen break overlay removes top status badges.
- Break overlay typography follows the user-selected break font, including remaining-time label and action buttons.
- H5 product page uses a dark, animated, centered hero layout and keeps the original slogan.
- H5 title is `Sige — 息止屏幕，界守双眼` without `2.0`.

Latest scheduler fixes:

- Pre-reminder Cancel now calls `BreakScheduler.restartWorkCycle()` so the next countdown restarts from one full work interval.
- `BreakScheduler.postpone(minutes:)` now uses a one-off `postponedUntil` date, so a 5-minute postpone means 5 minutes, not work interval + 5 minutes.
- System wake and long timer gaps reset the work cycle to avoid stale zero countdown after lid-close/sleep overnight.

## Tech Stack

| Area | Value |
|------|-------|
| Language | Swift 5.9+ |
| UI | SwiftUI + AppKit |
| Minimum macOS | macOS 14.0 Sonoma |
| Build | Swift Package Manager |
| App type | `LSUIElement=true` menu-bar app |
| Product page | Static HTML deployed to Surge |
| Contact | caoruihua@gmail.com |

## Important Paths

```text
Package.swift
Resources/Info.plist
Sources/Sige/AppDelegate.swift
Sources/Sige/MenuBar/MenuBarManager.swift
Sources/Sige/Timer/BreakScheduler.swift
Sources/Sige/Timer/BreakTimer.swift
Sources/Sige/Windows/SettingsView.swift
Sources/Sige/Windows/BreakOverlayView.swift
Sources/Sige/Windows/BreakWindow.swift
Sources/Sige/Windows/PreReminderPanel.swift
Sources/Sige/Models/AppPreferences.swift
Sources/Sige/Models/BreakTheme.swift
Sources/Sige/Models/ScheduleConfig.swift
Sources/Sige/Utils/L10n.swift
Sources/Sige/Utils/SoundManager.swift
build/build-dmg.sh
build/product-page/index.html
build/product-page/AppIcon.png
build/product-page/Sige-2.0.dmg
```

## Runtime Architecture

```text
main.swift
  -> NSApplication.shared
  -> AppDelegate.applicationDidFinishLaunching()
      -> MenuBarManager.setup()
      -> BreakScheduler.start()
      -> NotificationManager.setup()
  -> app.run()
```

Core data flow:

```text
SettingsView
  -> AppPreferences / ScheduleConfig / BreakTheme
  -> UserDefaults
  -> BreakScheduler
  -> PreReminderPanel
  -> BreakWindow + BreakOverlayView
  -> BreakTimer.stopBreak()
  -> stats update + scheduler reset
```

## Key Implementation Notes

- The app starts through AppKit, not SwiftUI `@main App`, to avoid macOS 14 menu-bar routing issues.
- `MenuBarManager` manually pops up the menu instead of assigning `statusItem.menu`.
- Shared runtime managers are singletons: `MenuBarManager`, `BreakScheduler`, `BreakTimer`, `BreakOverlayCoordinator`, `SoundManager`, `AppPreferences`.
- `ScheduleMode.pomodoro` is kept as an internal compatibility value. User-facing copy should say interval mode.
- `BreakScheduler` keeps `lastBreakEndTime` for normal interval mode and `postponedUntil` for one-off postpones. Do not implement postpones by shifting `lastBreakEndTime`, or the work interval will be added twice.
- `BreakScheduler.restartWorkCycle()` is the correct behavior for canceling a pre-reminder and for wake-from-sleep reset.
- Settings UI is a fixed two-column layout, not `NavigationSplitView`, to avoid the sidebar collapse/show toolbar button.
- Settings forms should use shared row alignment (`SettingsRow`) when adding new controls.
- About page should use the real `AppIcon` resource where available.
- The product page logo uses `build/product-page/AppIcon.png`, copied from the generated app icon.

## Build Commands

Development:

```bash
cd /Users/peter/Documents/Workspace/Product/sige/v2.0
swift build
swift run
```

Codex or sandbox-friendly build:

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" swift build --disable-sandbox
```

Release:

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" swift build -c release --disable-sandbox
```

## DMG Packaging

Run:

```bash
bash build/build-dmg.sh
```

The script:

1. Locates the release `Sige` binary.
2. Copies it to `build/staging/Sige.app/Contents/MacOS/Sige`.
3. Writes the app `Info.plist`.
4. Ensures `AppIcon.icns` exists.
5. Runs `xattr -cr` on the app bundle.
6. Runs ad-hoc signing with `codesign --force --deep --sign -`.
7. Verifies with `codesign --verify --deep --strict`.
8. Creates `build/Sige-2.0.dmg`.
9. Copies it to `build/product-page/Sige-2.0.dmg`.

Known environment note: Codex may fail on `hdiutil` with `设备未配置`. In that case, run `bash build/build-dmg.sh` in the normal macOS Terminal.

## H5 Product Page

Files:

- `build/product-page/index.html`
- `build/product-page/AppIcon.png`
- `build/product-page/Sige-2.0.dmg`

Current page direction:

- Dark, animated, premium visual style.
- Centered hero.
- Original slogan retained.
- No visible “new release” or `2.0` tag in the hero.
- Page title does not include `2.0`.
- Download button still points to `Sige-2.0.dmg`.

Before deploy, validate:

```bash
node - <<'NODE'
const fs=require('fs'); const vm=require('vm');
const s=fs.readFileSync('build/product-page/index.html','utf8');
const keys=[...new Set([...s.matchAll(/data-i18n="([^"]+)"/g)].map(m=>m[1]))];
const script=s.match(/var copy=([\s\S]*?);\nfunction setLang/)[1];
const copy=vm.runInNewContext('('+script+')');
console.log({
  title:(s.match(/<title>(.*?)<\/title>/)||[])[1],
  missingZh:keys.filter(k=>!(k in copy.zh)),
  missingEn:keys.filter(k=>!(k in copy.en)),
  hasDmg:s.includes('Sige-2.0.dmg'),
  hasIcon:s.includes('AppIcon.png')
});
NODE
```

## Surge Deployment

Deploy:

```bash
surge build/product-page sige-break-reminder.surge.sh
```

Verify homepage:

```bash
curl -L https://sige-break-reminder.surge.sh/ -o /tmp/sige_online.html
```

Verify DMG:

```bash
curl -I https://sige-break-reminder.surge.sh/Sige-2.0.dmg
```

The `etag` should match the local SHA256:

```bash
shasum -a 256 build/Sige-2.0.dmg build/product-page/Sige-2.0.dmg
```

Latest known DMG SHA256:

```text
52493e3bd6e84ccfb1fce154dcec498aadf934ad00b94887c8e4b7559e3e8486
```

## Gatekeeper, Signing, and Notarization

Current packages are ad-hoc signed. This fixes invalid bundle signatures and avoids the earlier “app is damaged” class of issue, but it does not satisfy Apple Developer ID verification.

Expected behavior for web downloads without notarization:

- Browser adds `com.apple.quarantine`.
- macOS may show “无法验证开发者” / “未打开 Sige”.
- User can right-click and choose Open, or remove quarantine manually:

```bash
xattr -dr com.apple.quarantine /Applications/Sige.app
```

Why v1.1 may have behaved differently:

- v1.1 was also ad-hoc signed, and its staging signature verification is actually invalid.
- If it was installed from a local file or without quarantine attributes, Gatekeeper may not have shown the same warning.
- The warning is tied to download quarantine and notarization, not only app contents.

Check available signing identities:

```bash
security find-identity -v -p codesigning
```

Current machine state observed during v2.0 work:

```text
0 valid identities found
```

Formal public release requires:

```bash
codesign --force --deep --options runtime --sign "Developer ID Application: <Name> (<TeamID>)" build/staging/Sige.app
hdiutil create -srcfolder build/staging -volname "Sige" -format UDZO -o build/Sige-2.0.dmg
xcrun notarytool submit build/Sige-2.0.dmg --apple-id "<apple-id>" --team-id "<team-id>" --password "<app-specific-password>" --wait
xcrun stapler staple build/Sige-2.0.dmg
spctl --assess --type open --verbose build/Sige-2.0.dmg
```

## Release Checklist

Use this whenever client code changes:

1. Update code and localized strings.
2. Run debug build:
   `CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" swift build --disable-sandbox`
3. Run release build:
   `CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" swift build -c release --disable-sandbox`
4. Run `bash build/build-dmg.sh` in Terminal if Codex cannot create DMG.
5. Run:
   `shasum -a 256 build/Sige-2.0.dmg build/product-page/Sige-2.0.dmg`
6. Update H5 size/SHA if changed.
7. Run the H5 key validation script.
8. Deploy with Surge.
9. Verify homepage and DMG URL.
10. Test install on a clean `/Applications/Sige.app` path.

## Privacy

- Pure local app.
- No account system.
- No telemetry.
- No network requests from the client.
- User preferences and stats are stored in `UserDefaults`.
