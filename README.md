# Tapdeck

**One-tap Mac tools in Control Center and the menu bar.** Built for people who vibe code and just want things to work.

[Website](https://devehab.github.io/Tapdeck/) · [Download](https://github.com/Devehab/Tapdeck/releases/latest/download/Tapdeck.dmg) · [العربية](README.ar.md)

Tapdeck has no window, no Dock icon and no settings. Its tools show up as native controls you add to Control Center or pin to the menu bar, and as actions in Spotlight and the Shortcuts app.

## Tools

### Lights Out
Turns off the screen and keyboard light while the Mac keeps running, so a long agent run, build or download continues in the dark.

- Remembers the exact display brightness, keyboard light and "Adjust keyboard brightness in low light" setting first.
- Sets brightness to 0 and paints the screen black (on mini-LED panels the backlight zones actually switch off).
- Keeps the Mac and display from idling to sleep, so work isn't interrupted and you don't land on the lock screen.
- The first touch of the trackpad, mouse or any key brings everything back exactly as it was.
- Needs no permissions: no Accessibility, no Input Monitoring.

### Stay Awake
A toggle that keeps the Mac running, even with the lid closed. It's the same as:

```bash
sudo pmset -a disablesleep 1   # on
sudo pmset -a disablesleep 0   # off
```

- ☀️ **Won't Sleep**: the Mac stays on, lid open or closed. 🌙 **Sleeps Normally**: regular macOS sleep.
- It always reads the real system state, so it stays correct even if you change the setting from Terminal.
- Changing the setting needs root, so a tiny helper does it. The helper can only run `pmset -a disablesleep 0|1` and only accepts calls from Tapdeck signed by the same team. macOS asks you to approve it once.

> Don't carry a closed Mac in a bag with Stay Awake on. It keeps running, gets warm and drains the battery.

Check it from Terminal:

```bash
pmset -g | grep SleepDisabled   # 1 = on, 0 = off
pmset -g stats                  # Sleep Count stays the same if the Mac never slept
```

### Mic Mute
A toggle that mutes every microphone at once, the way the mute button on an external mic does.

- Flips each microphone's own hardware mute switch. Apps keep their audio stream and their permission and receive exact digital silence; nothing is revoked, paused or restarted.
- Tap again and sound flows immediately. Red struck-through mic = **Muted**, plain mic = **On**.
- Microphones that connect while muted are muted too, and the mute holds even if Tapdeck quits.
- If another app turns the mic back on, the toggle follows.
- Needs no permissions. It never listens to the microphone.
- Some inputs, such as an iPhone used through Continuity or a virtual mic from a recording app, have no mute or volume control. If the input in use is one of them, Tapdeck says so instead of showing a mute that isn't real. `Tapdeck --status` lists every input and whether it can be muted.

## Install

1. Download [Tapdeck.dmg](https://github.com/Devehab/Tapdeck/releases/latest/download/Tapdeck.dmg) and drag Tapdeck into Applications.
2. Open it. This build isn't notarized yet, so the first time macOS says it can't verify Tapdeck: click **Done**, then **System Settings › Privacy & Security › Open Anyway**.
3. Open **Control Center › Edit Controls › Tapdeck** and drag **Lights Out**, **Stay Awake** and **Mic Mute** into Control Center, or up into the menu bar.
4. The first time you tap Stay Awake, click **Open System Settings** and turn on Tapdeck under **General › Login Items & Extensions › Allow in the Background**.

Spotlight: press ⌘ Space and type **Lights Out**, **Toggle Stay Awake** or **Toggle Mic Mute**. For a keyboard shortcut (a mute key, say), add the action to a shortcut in the Shortcuts app and choose **Add Keyboard Shortcut**.

Requires macOS 26 Tahoe or later. Universal (Apple silicon and Intel).

### Updating

Tapdeck keeps running in the background, so Finder says the item “Tapdeck” is in use if you replace it directly. Quit it first:

```bash
pkill -x Tapdeck; pkill -x TapdeckControls
```

Then drag the new Tapdeck into Applications, choose **Replace**, and open it. Your settings and Control Center buttons stay as they are.

If a new tool doesn't show up in Edit Controls afterwards, or a button looks old, macOS is still using an older copy of Tapdeck it remembers (in Downloads, the Trash or an old disk image). This makes it forget every copy outside Applications and reload the buttons:

```bash
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
pkill -x Tapdeck; pkill -x TapdeckControls
"$LSR" -dump | grep -E "^path: +/.*/Tapdeck\.app( |$)" | sed -E 's/^path: +//; s/ \(0x[0-9a-f]+\)$//' | sort -u | grep -v "^/Applications/Tapdeck.app$" | while read -r old; do echo "Forgetting old copy: $old"; "$LSR" -u "$old"; done
"$LSR" -f /Applications/Tapdeck.app
pluginkit -a /Applications/Tapdeck.app/Contents/PlugIns/TapdeckControls.appex
killall chronod
open /Applications/Tapdeck.app
echo "Tapdeck version: $(defaults read /Applications/Tapdeck.app/Contents/Info.plist CFBundleShortVersionString)"
```

The last line should show the version you installed. If it shows an older one, the new Tapdeck never reached Applications: download it again and drag it in.

## Terminal and browser extensions

Every tool can also be read and switched from outside Control Center, with no server running:

```bash
/Applications/Tapdeck.app/Contents/MacOS/Tapdeck install-cli   # once: adds `tapdeck` to ~/.local/bin
tapdeck status --json
tapdeck mic toggle
tapdeck awake on
tapdeck lights out
```

Browser extensions reach Tapdeck through Chrome's native messaging: run `tapdeck chrome install`, then load the sample extension ([download the zip](https://github.com/Devehab/Tapdeck/releases/latest/download/tapdeck-chrome-extension.zip), or use [`extensions/chrome`](extensions/chrome)). Its popup shows all three tools, and Alt+Shift+M toggles the mic.

The full guide, with every command, the JSON format, building your own extension and troubleshooting, is in [docs/integrations.md](docs/integrations.md).

## Build from source

Requires Xcode 26 or later and an Apple Development certificate. Put your Team ID in a local config file (git ignores it):

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # then edit DEVELOPMENT_TEAM
./scripts/install.sh
```

| Script | What it does |
|---|---|
| `scripts/build.sh` | Builds `Tapdeck.app` (Release, universal) with a fresh build number |
| `scripts/install.sh` | Builds, installs to `/Applications` and registers the controls |
| `scripts/make-dmg.sh` | Builds `dist/Tapdeck-<version>.dmg`, `dist/Tapdeck.dmg` and `dist/tapdeck-chrome-extension.zip` for a release |
| `scripts/make-icon.swift` | Draws the app icon and the website icons |

Every build gets a new build number because WidgetKit caches each extension's list of controls by build number. `install.sh` also stops the old extension process so Control Center redraws with the new code.

### Release

```bash
./scripts/make-dmg.sh
gh release create v1.2 dist/Tapdeck.dmg dist/tapdeck-chrome-extension.zip --title "Tapdeck 1.2"
```

The website's download buttons point to `releases/latest/download/Tapdeck.dmg`, so they always serve the newest release.

### Website

The landing page is `site/index.html` (English and Arabic, light and dark). `.github/workflows/pages.yml` publishes it to GitHub Pages on every push that changes `site/`. To preview it locally:

```bash
python3 -m http.server 8765 --directory site
```

## How it works

```
App/                 The app (not sandboxed). Does the real work.
  Features/          One folder per tool: LightsOut, StayAwake, MicMute
  Hardware/          Display brightness, keyboard light, input activity, root helper client
  AppShortcuts.swift Spotlight and Shortcuts actions
ControlsExtension/   WidgetKit extension with the Control Center controls
Shared/              Code in both the app and the extension: TapdeckAction, ControlKind, App Intents, AudioInputs
Helper/              TapdeckHelper, the root launchd daemon (SMAppService)
HelperInterface/     XPC protocol shared by the app and the helper
Config/              Info.plists, entitlements, the helper's launchd plist, Signing.xcconfig
site/                The landing page
```

On macOS 26, a control's intent runs inside the sandboxed, short-lived widget extension. It can't touch hardware or keep watching for input, so it hands the action to the app by opening `tapdeck://<action>` in the background. The app launches if needed, never takes focus, and does the work.

### Adding a tool

1. Add a case to `TapdeckAction` in `Shared/TapdeckAction.swift`.
2. Handle it in `App/TapdeckActionHandler.swift`, ideally in its own folder under `App/Features/`.
3. Add an intent in `Shared/Intents/` that calls `TapdeckAction.<case>.run()`.
4. Add a `ControlKind`, a `ControlWidget` in `ControlsExtension/Controls/`, and list it in `TapdeckBundle`.
5. Optionally add it to `App/AppShortcuts.swift` and give it a card on the website.

Anything that needs root becomes a new, narrowly scoped method on `TapdeckHelperProtocol`, never "run this command".

## Troubleshooting

```bash
/Applications/Tapdeck.app/Contents/MacOS/Tapdeck --status
```

Prints what Tapdeck can see and control (displays, brightness, keyboard light, Stay Awake, helper approval, every microphone and whether it can be muted) without changing anything.

```bash
/usr/bin/log show --last 10m --style compact --predicate 'subsystem == "com.ibtkrgo.Tapdeck"'
```

Logs from the app, the extension and the helper. In zsh, `log` is a shell builtin, so use the full path.

To uninstall: turn Stay Awake and Mic Mute off, run `Tapdeck --unregister-helper` (same path as above), quit with `pkill -x Tapdeck`, and move the app to the Trash.

## Notes

- Display brightness and keyboard light use Apple's private `DisplayServices` and `CoreBrightness` frameworks. That rules out the Mac App Store and may break with a macOS update; `--status` shows it right away.
- External displays without brightness control are painted black but keep their backlight on.
- Builds are signed with an Apple Development certificate and aren't notarized, hence the one-time Open Anyway step. A Developer ID signature plus notarization would remove it.

## License

MIT. See [LICENSE](LICENSE).
