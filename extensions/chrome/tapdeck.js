// Talks to the Tapdeck app on this Mac through Chrome's native messaging.
// Chrome starts Tapdeck for each message and Tapdeck exits right after
// replying: no server, no port, nothing running in between.
//
// Every reply looks like:
//   { ok: true, state: { micMute: { muted, input, canMute },
//                        stayAwake: { on, helper }, lightsOut: { out } },
//     error: "only when ok is false" }

export const HOST = "com.ibtkrgo.tapdeck";

/** tapdeck("status"), tapdeck("mic", "toggle"), tapdeck("awake", "on"), tapdeck("lights", "out") */
export function tapdeck(command, action) {
  const message = action ? { command, action } : { command };
  return chrome.runtime.sendNativeMessage(HOST, message);
}

/** A small red MUTE badge on the toolbar icon while the microphone is muted. */
export async function showMicBadge(muted) {
  await chrome.action.setBadgeBackgroundColor({ color: "#DC3D43" });
  await chrome.action.setBadgeText({ text: muted ? "MUTE" : "" });
  await chrome.action.setTitle({ title: muted ? "Tapdeck: microphone muted" : "Tapdeck" });
}
