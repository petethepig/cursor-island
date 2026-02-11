<div align="center">
  <img src="ClaudeIsland/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">Claude Island</h3>
  <p align="center">
    A macOS menu bar app that brings Dynamic Island-style notifications to Claude Code CLI and Cursor IDE sessions.
    <br />
    <br />
    <a href="https://github.com/farouqaldori/claude-island/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/farouqaldori/claude-island?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
    <a href="#" target="_blank" rel="noopener noreferrer">
      <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/farouqaldori/claude-island/total?style=rounded&color=white&labelColor=000000">
    </a>
  </p>
</div>

## Features

- **Notch UI** — Animated overlay that expands from the MacBook notch
- **Live Session Monitoring** — Track multiple Claude Code and Cursor sessions in real-time
- **Chat History** — View full conversation history with markdown rendering
- **Auto-Setup** — Hooks install automatically on first launch

## Requirements

- macOS 15.6+
- Claude Code CLI and/or Cursor IDE

## Install

Download the latest release or build from source:

```bash
xcodebuild -scheme ClaudeIsland -configuration Release build
```

## How It Works

Claude Island installs hooks for both tools:

- **Claude Code CLI** — hooks in `~/.claude/settings.json`, script: `~/.claude/hooks/claude-island-state.py`
- **Cursor IDE** — hooks in `~/.claude/hooks.json`, script: `~/.claude/hooks/cursor-island-state.py`

Both scripts communicate session state via a Unix socket (`/tmp/claude-island.sock`). The app listens for events and displays them in the notch overlay. Sessions from both tools appear in the same UI with agent type badges.

Session and transcript data are read from `~/.claude/projects/{project}/` (Claude Code) or `~/.claude/projects/{project}/agent-transcripts/` (Cursor).

## License

Apache 2.0
