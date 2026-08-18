# Unlock Briefing

**English** · [中文](README.zh-CN.md)

Show today’s todos and key-date countdowns when you unlock your Mac. Press **⌘⇧U** to open a window where you can view, edit, and sync `content.json` over Git.

A standard `.app` — no Dock icon. A menu-bar icon is shown by default and can be turned off in Settings. Launch at login is optional.

## Install

1. Download **[UnlockBriefing-0.1.2.zip](https://github.com/uraraneko/unlock-briefing/releases/latest)** and unzip `UnlockBriefing.app`
2. Move it to **Applications**, then open it
3. If macOS says the developer cannot be verified: **System Settings → Privacy & Security → Open Anyway**
4. Open Settings (menu bar or the window), paste your private Git repo URL (the repo should contain `content.json`), and save

Requires macOS 13+ and a local `git` with your existing credentials (SSH or osxkeychain).

Optional: menu bar → **Launch at login**.

## Multi-device Sync (Private Repo)

Todos and countdowns live in your private Git repo, not in this public project:

1. Set the repo URL in Settings. The app clones it to `~/Library/Application Support/UnlockBriefing/data/` and reads `content.json`.
2. Opening the window with **⌘⇧U** runs a background two-way sync (`commit` if dirty, then `git pull --rebase` & `git push`).
3. If the pull brings new data, the window reloads it.

With no repo URL, the window stays empty and points you to Settings.

## Configure

Edit in the main window (**Edit**), or change `content.json` in the data repo:

```json
{
  "todos": [
    { "text": "Draft the report", "priority": "high" },
    { "text": "Reply to email", "priority": "medium" }
  ],
  "archived": [
    { "text": "Ship the launch checklist", "priority": "high" }
  ],
  "countdowns": [{ "title": "Launch", "date": "2026-12-31", "start": "2026-08-01" }]
}
```

Countdowns: **x weeks y days** when 7+ days remain, otherwise **x days y hours**; past dates show **expired**. If both lists are empty: **Nothing special today — stay focused.**

App settings (repo URL, launch at login, menu-bar icon) are stored at `~/Library/Application Support/UnlockBriefing/settings.json`.

Press **⌘⇧U** to toggle the main window (open if hidden, close if already open).
