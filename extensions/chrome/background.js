import { tapdeck, showMicBadge } from "./tapdeck.js";

// Alt+Shift+M toggles Mic Mute while Chrome is in front.
// Change the keys in chrome://extensions/shortcuts.
chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "toggle-mic") return;
  try {
    const response = await tapdeck("mic", "toggle");
    await showMicBadge(response.state.micMute.muted);
  } catch (error) {
    await chrome.action.setBadgeText({ text: "!" });
    await chrome.action.setTitle({ title: `Tapdeck: ${error.message}` });
  }
});

// Show the mic state on the toolbar icon as soon as Chrome starts.
async function syncBadge() {
  try {
    const response = await tapdeck("status");
    await showMicBadge(response.state.micMute.muted);
  } catch {
    // Not connected yet; the popup explains how to connect.
  }
}
chrome.runtime.onStartup.addListener(syncBadge);
chrome.runtime.onInstalled.addListener(syncBadge);
