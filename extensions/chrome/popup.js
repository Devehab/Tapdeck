import { tapdeck, showMicBadge } from "./tapdeck.js";

const $ = (id) => document.getElementById(id);
const SAMPLE_EXTENSION_ID = "jcpfohebbppapakgjnigbikckpfjinci";

function render(response) {
  const { micMute, cameraLock, stayAwake, lightsOut } = response.state;
  $("setup").hidden = true;
  $("tools").hidden = false;
  $("connection").textContent = "Connected";
  $("connection").classList.add("ok");

  $("mic").setAttribute("aria-checked", String(micMute.muted));
  $("mic-state").textContent = (micMute.muted ? "Muted" : "On") + (micMute.input ? ` · ${micMute.input}` : "");

  $("camera").setAttribute("aria-checked", String(cameraLock.locked));
  $("camera-state").textContent = cameraLock.locked
    ? "Locked. Touch ID turns it back on."
    : cameraLock.touchID ? "On" : "On · needs Touch ID to lock";

  $("awake").setAttribute("aria-checked", String(stayAwake.on));
  $("awake-state").textContent = stayAwake.on ? "Won't Sleep" : "Sleeps Normally";

  $("lights-state").textContent = lightsOut.out ? "Out. Touch the trackpad to wake." : "Screen and keyboard off";

  $("note").hidden = !response.error;
  $("note").textContent = response.error ?? "";
  showMicBadge(micMute.muted);
}

function showSetup(error) {
  const message = error?.message ?? String(error);
  $("tools").hidden = true;
  $("setup").hidden = false;
  $("connection").textContent = "Not connected";
  $("connection").classList.remove("ok");
  if (/not found/i.test(message)) {
    $("setup-reason").textContent = "Chrome can't find Tapdeck yet.";
  } else if (/forbidden/i.test(message)) {
    $("setup-reason").textContent = "Tapdeck doesn't allow this extension yet.";
  } else {
    $("setup-reason").textContent = `Chrome said: ${message}`;
  }
  // The full path works even before `tapdeck install-cli`.
  const id = chrome.runtime.id === SAMPLE_EXTENSION_ID ? "" : ` ${chrome.runtime.id}`;
  $("setup-command").textContent = `/Applications/Tapdeck.app/Contents/MacOS/Tapdeck chrome install${id}`;
}

async function run(command, action) {
  if (document.body.classList.contains("busy")) return;
  document.body.classList.add("busy");
  try {
    render(await tapdeck(command, action));
  } catch (error) {
    showSetup(error);
  } finally {
    document.body.classList.remove("busy");
  }
}

$("mic").addEventListener("click", () => run("mic", "toggle"));
// Locking finishes in System Settings and unlocking asks for Touch ID; both
// take focus away, which closes this popup. Tapdeck carries on regardless.
$("camera").addEventListener("click", () => run("camera", "toggle"));
$("awake").addEventListener("click", () => run("awake", "toggle"));
$("lights").addEventListener("click", async () => {
  await run("lights", "out");
  window.close();
});
$("copy").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText($("setup-command").textContent);
    $("copy").textContent = "Copied";
  } catch {
    getSelection().selectAllChildren($("setup-command"));
  }
});

run("status");
