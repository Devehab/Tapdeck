# Control Tapdeck from Terminal, scripts and browser extensions

[العربية](integrations.ar.md) · [Back to README](../README.md)

Everything Tapdeck does from Control Center can also be read and switched from outside: a `tapdeck` command for Terminal and scripts, and a native messaging host for browser extensions. Neither needs a server. Nothing listens on a port, and nothing keeps running in the background.

- [How it works](#how-it-works)
- [Part 1: The `tapdeck` command](#part-1-the-tapdeck-command)
- [Part 2: Chrome and other browsers](#part-2-chrome-and-other-browsers)
- [Troubleshooting](#troubleshooting)

## How it works

```
 Terminal, a script, Raycast, an AI agent ──┐
                                            ├─▶ Tapdeck (the same app binary)
 A Chrome extension (via native messaging) ─┘        │
                                                     ├─ reads the state directly from macOS
                                                     │    microphone mute switch (CoreAudio)
                                                     │    camera access (CoreMediaIO)
                                                     │    SleepDisabled (power management)
                                                     │    Lights Out state
                                                     │
                                                     └─ hands every change to the Tapdeck app
                                                          over tapdeck://, the path the
                                                          Control Center buttons use
```

- **Reading** is instant and always true. It comes straight from the system, so it's correct even if Tapdeck isn't running or another app changed a setting.
- **Changing** goes through the Tapdeck app, exactly like tapping a Control Center button. The buttons update, a newly connected mic still gets muted, and Lights Out still wakes on your first touch. Tapdeck starts in the background if it isn't running and never takes focus.
- **Security doesn't change.** Muting a microphone needs no permission. Stay Awake and Camera Lock still go through the root helper, unlocking the camera still asks for Touch ID, and the helper only accepts requests from Tapdeck itself. A browser can only reach Tapdeck from extensions you've allowed.

---

## Part 1: The `tapdeck` command

### Install it (once)

```bash
/Applications/Tapdeck.app/Contents/MacOS/Tapdeck install-cli
```

This writes a small `tapdeck` script into `~/.local/bin`. If that folder isn't on your PATH yet, the command tells you the line to add to `~/.zshrc`. To install somewhere else, pass the folder: `… install-cli /usr/local/bin` (that folder needs `sudo`).

### Commands

| Command | What it does |
|---|---|
| `tapdeck status` | The state of every tool |
| `tapdeck mic` | Mic Mute state |
| `tapdeck mic mute` / `unmute` / `toggle` | Mute or unmute every microphone at the hardware level |
| `tapdeck camera` | Camera Lock state |
| `tapdeck camera lock` / `unlock` / `toggle` | Turn every camera off for every app, or back on after Touch ID |
| `tapdeck awake` | Stay Awake state |
| `tapdeck awake on` / `off` / `toggle` | Keep the Mac running with the lid closed, or not |
| `tapdeck lights` | Lights Out state |
| `tapdeck lights out` | Screen and keyboard light off; any touch brings them back |
| `tapdeck lights on` | Bring them back from a script |
| `tapdeck status --verbose` | Diagnostics: displays, keyboard light, every microphone |
| `tapdeck chrome install [ID…]` | Connect browsers (see Part 2) |
| `tapdeck help` | All of the above |

Add `--json` to any command for machine-readable output.

### Output

```
$ tapdeck mic mute
Microphone   Muted  (MacBook Pro Microphone)
Camera       On
Stay Awake   Won't Sleep
Lights Out   Off
```

```
$ tapdeck status --json
{
  "ok" : true,
  "state" : {
    "cameraLock" : { "locked" : false, "touchID" : true },
    "lightsOut" : { "out" : false },
    "micMute" : { "canMute" : true, "input" : "MacBook Pro Microphone", "muted" : true },
    "stayAwake" : { "helper" : "enabled", "on" : true }
  }
}
```

| Field | Meaning |
|---|---|
| `ok` | `true` when the requested state was reached |
| `error` | Present only when `ok` is `false`: what went wrong and how to fix it |
| `state.micMute.muted` | The input apps use by default is muted |
| `state.micMute.input` | That input's name |
| `state.micMute.canMute` | `false` for inputs macOS gives no mute or volume control (an iPhone through Continuity, some virtual mics) |
| `state.cameraLock.locked` | Every camera is hidden from apps |
| `state.cameraLock.touchID` | Touch ID is ready. Camera Lock works only while it is, since only Touch ID unlocks it |
| `state.stayAwake.on` | `pmset -a disablesleep` is in effect |
| `state.stayAwake.helper` | `enabled`, `needs-approval` or `not-registered` (Stay Awake's one-time approval) |
| `state.lightsOut.out` | Lights Out is active right now |

**Exit codes:** `0` done, `1` the change didn't happen (the message says why), `2` the command wasn't understood.

### Examples

Mute before a recording, whatever state it was in:

```bash
tapdeck mic mute && echo "Mic is muted"
```

Read one value with `jq`:

```bash
tapdeck status --json | jq '.state.micMute.muted'
```

Keep the Mac awake for a long job, then put things back:

```bash
tapdeck awake on
./run-the-long-build.sh
tapdeck awake off
```

Run a long job in the dark; the screen wakes when you touch the Mac:

```bash
tapdeck awake on && tapdeck lights out
```

**Raycast script command** (save as `toggle-mic.sh` in your Raycast scripts folder):

```bash
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Mic Mute
# @raycast.mode silent
~/.local/bin/tapdeck mic toggle --json | grep -q '"muted" : true' && echo "Mic muted" || echo "Mic on"
```

**AI coding agents** (Claude Code, Cursor and others) can run `tapdeck status --json` to see the state and `tapdeck mic mute`, `tapdeck awake on` and so on to change it, like any other shell command.

**Shortcuts app:** add a *Run Shell Script* action with `~/.local/bin/tapdeck mic toggle`. Tapdeck's own actions (*Toggle Mic Mute*, *Toggle Camera Lock*, *Toggle Stay Awake*, *Lights Out*) are also there without any script.

---

## Part 2: Chrome and other browsers

### How it works: native messaging, no server

Chrome has a built-in way for extensions to talk to an app on the computer, called **native messaging**:

1. The extension calls `chrome.runtime.sendNativeMessage("com.ibtkrgo.tapdeck", {command: "mic", action: "toggle"})`.
2. Chrome looks up `com.ibtkrgo.tapdeck` in a small file (the *host manifest*) that says which program to start and which extensions are allowed.
3. Chrome starts Tapdeck and passes the extension's ID as the first argument. It sends the message on standard input and reads the reply from standard output.
4. Tapdeck answers with the full state and exits.

No port is opened, so no website can reach Tapdeck, and only the extensions listed in the manifest can.

### Quick start with the sample extension

The repository includes a ready-made extension in [`extensions/chrome`](../extensions/chrome). Its popup shows every tool with its live state. Its toolbar icon shows a red **MUTE** badge while the mic is muted, and **Alt+Shift+M** toggles the mic while Chrome is in front.

1. **Install Tapdeck** in Applications and open it once.
2. **Connect your browsers:**
   ```bash
   /Applications/Tapdeck.app/Contents/MacOS/Tapdeck chrome install
   ```
   This writes the host manifest for every Chromium-based browser you have (Chrome, Brave, Edge, Arc, Vivaldi, Chromium). The sample extension is always allowed.
3. **Load the extension:** download [tapdeck-chrome-extension.zip](https://github.com/Devehab/Tapdeck/releases/latest/download/tapdeck-chrome-extension.zip) and unzip it (or use `extensions/chrome` from this repository). Open `chrome://extensions`, turn on **Developer mode** (top right), click **Load unpacked** and choose the unzipped folder.
4. **Pin it** from the puzzle-piece menu and click it. You should see **Connected**.

The sample extension's manifest carries a fixed public key, so its ID is always `jcpfohebbppapakgjnigbikckpfjinci`, wherever you load it from. That's why step 2 needs no ID.

To change the shortcut, go to `chrome://extensions/shortcuts`.

### Build your own extension

**1. Ask for the permission** in `manifest.json`:

```json
{
  "manifest_version": 3,
  "name": "My Tapdeck panel",
  "version": "1.0",
  "permissions": ["nativeMessaging"],
  "action": { "default_popup": "popup.html" }
}
```

**2. Send a message.** One request, one reply:

```js
const reply = await chrome.runtime.sendNativeMessage("com.ibtkrgo.tapdeck", { command: "status" });
console.log(reply.state.micMute.muted);
```

Or keep a connection open for several requests:

```js
const port = chrome.runtime.connectNative("com.ibtkrgo.tapdeck");
port.onMessage.addListener((reply) => console.log(reply.state));
port.postMessage({ command: "mic", action: "mute" });
port.postMessage({ command: "awake", action: "status" });
```

**3. Allow your extension.** Copy its ID from `chrome://extensions` and run:

```bash
tapdeck chrome install abcdefghijklmnopabcdefghijklmnop
```

IDs you add are kept the next time you run `chrome install`. `tapdeck chrome status` shows what's allowed.

### The protocol

| Request | Meaning |
|---|---|
| `{"command": "status"}` | Everything's state |
| `{"command": "mic", "action": "mute" \| "unmute" \| "toggle" \| "status"}` | Mic Mute |
| `{"command": "camera", "action": "lock" \| "unlock" \| "toggle" \| "status"}` | Camera Lock. Unlocking shows the Touch ID prompt and waits up to a minute for it |
| `{"command": "awake", "action": "on" \| "off" \| "toggle" \| "status"}` | Stay Awake |
| `{"command": "lights", "action": "out" \| "on" \| "status"}` | Lights Out |

Every reply has the same shape as `tapdeck status --json`: `ok`, `state`, and `error` when something didn't happen. A malformed or unknown request gets `"ok": false` with an explanation, never a crash.

Underneath, each message is a 32-bit length (native byte order) followed by that many bytes of UTF-8 JSON. Chrome handles this framing for you; it matters only if you write your own host.

### Other browsers

- **Brave, Edge, Arc, Vivaldi, Chromium:** covered by `tapdeck chrome install` automatically, as long as the browser has been opened once (so its settings folder exists). Load the extension the same way.
- **Firefox:** also supports native messaging, but its host manifest uses a different format (`allowed_extensions`) and folder. It isn't set up automatically yet.
- **Safari:** its extensions talk to apps differently and aren't supported.

---

## Troubleshooting

| What you see | Why | Fix |
|---|---|---|
| `tapdeck: command not found` | The command isn't installed, or `~/.local/bin` isn't on your PATH | Run `…/Tapdeck install-cli` and add the line it prints to `~/.zshrc`, or use the full path `/Applications/Tapdeck.app/Contents/MacOS/Tapdeck` |
| Popup says **Chrome can't find Tapdeck yet** (*Specified native messaging host not found*) | The host manifest isn't installed for this browser | Run `tapdeck chrome install`, then reopen the popup. If the browser was never opened before, open it once first |
| Popup says **Tapdeck doesn't allow this extension yet** (*Access … is forbidden*) | Your extension's ID isn't in the manifest | Run `tapdeck chrome install <your extension ID>` |
| *Native host has exited* | The manifest points to a Tapdeck that was moved or deleted | Put Tapdeck in Applications and run `tapdeck chrome install` again |
| `"ok": false` for `awake on` with `"helper": "needs-approval"` | Stay Awake's one-time approval is missing | Turn Tapdeck on in System Settings › General › Login Items & Extensions › Allow in the Background |
| `"ok": false` for `camera lock` with `"touchID": false` | Camera Lock works only while Touch ID is ready | Add a fingerprint in System Settings › Touch ID & Password, open the MacBook lid, or connect a Magic Keyboard with Touch ID |
| `"ok": false`: *The camera is still locked: Touch ID didn't confirm it* | The Touch ID prompt was cancelled, didn't match, or wasn't answered within a minute | Run `tapdeck camera unlock` again and touch the sensor |
| Camera unlocked, but an app still finds no camera | That app was using the camera when it was locked and doesn't look for it again by itself | Quit it completely (⌘Q; for a browser, the whole browser) and open it again |
| `"ok": false` for `mic mute` with `"canMute": false` | The input in use has no mute control in macOS | Pick another input in System Settings › Sound. Every other mic was muted |
| `"ok": false`: *Tapdeck didn't respond in time* | Tapdeck couldn't be started | Open Tapdeck once from Applications, then try again |

To remove everything: `tapdeck chrome uninstall`, then delete `~/.local/bin/tapdeck` and remove the extension from `chrome://extensions`.
