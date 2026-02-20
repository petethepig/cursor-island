//
//  HookInstaller.swift
//  ClaudeIsland
//
//  Auto-installs hooks for both Claude Code CLI and Cursor IDE on app launch
//

import Foundation

struct HookInstaller {

    private static let claudeDirName = ".claude"
    private static let hooksDirName = "hooks"

    // Claude Code CLI uses settings.json with PascalCase event names
    private static let claudeScriptName = "claude-island-state.py"
    private static let settingsJSONName = "settings.json"

    // Cursor IDE uses hooks.json with camelCase event names
    private static let cursorScriptName = "cursor-island-state.py"
    private static let hooksJSONName = "hooks.json"

    // Pi Coding Agent uses hooks.json with camelCase event names (at ~/.pi/agent/)
    private static let piDirName = ".pi"
    private static let piAgentDirName = "agent"
    private static let piScriptName = "pi-island-state.py"

    /// Install hook scripts and update both config files on app launch
    static func installIfNeeded() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(claudeDirName)
        let hooksDir = claudeDir.appendingPathComponent(hooksDirName)
        let claudeScript = hooksDir.appendingPathComponent(claudeScriptName)
        let cursorScript = hooksDir.appendingPathComponent(cursorScriptName)
        let settingsJSON = claudeDir.appendingPathComponent(settingsJSONName)
        let hooksJSON = claudeDir.appendingPathComponent(hooksJSONName)

        try? FileManager.default.createDirectory(
            at: hooksDir,
            withIntermediateDirectories: true
        )

        // Copy Claude Code hook script
        if let bundled = Bundle.main.url(forResource: "claude-island-state", withExtension: "py") {
            try? FileManager.default.removeItem(at: claudeScript)
            try? FileManager.default.copyItem(at: bundled, to: claudeScript)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: claudeScript.path
            )
        }

        // Copy Cursor hook script
        if let bundled = Bundle.main.url(forResource: "cursor-island-state", withExtension: "py") {
            try? FileManager.default.removeItem(at: cursorScript)
            try? FileManager.default.copyItem(at: bundled, to: cursorScript)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: cursorScript.path
            )
        }

        // Copy Pi hook script
        let piAgentDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(piDirName)
            .appendingPathComponent(piAgentDirName)
        let piHooksDir = piAgentDir.appendingPathComponent(hooksDirName)
        let piScript = piHooksDir.appendingPathComponent(piScriptName)
        let piHooksJSON = piAgentDir.appendingPathComponent(hooksJSONName)

        if FileManager.default.fileExists(atPath: piAgentDir.path) {
            try? FileManager.default.createDirectory(
                at: piHooksDir,
                withIntermediateDirectories: true
            )

            if let bundled = Bundle.main.url(forResource: "pi-island-state", withExtension: "py") {
                try? FileManager.default.removeItem(at: piScript)
                try? FileManager.default.copyItem(at: bundled, to: piScript)
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: piScript.path
                )
            }

            updatePiHooksJSON(at: piHooksJSON)
        }

        updateClaudeSettings(at: settingsJSON)
        updateCursorHooksJSON(at: hooksJSON)
    }

    // MARK: - Claude Code CLI: settings.json (PascalCase, nested format)

    private static func updateClaudeSettings(at settingsURL: URL) {
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let python = detectPython()
        let command = "\(python) ~/.claude/hooks/\(claudeScriptName)"
        let hookEntry: [[String: Any]] = [["type": "command", "command": command]]
        let withMatcher: [[String: Any]] = [["matcher": "*", "hooks": hookEntry]]
        let withoutMatcher: [[String: Any]] = [["hooks": hookEntry]]
        let preCompactConfig: [[String: Any]] = [
            ["matcher": "auto", "hooks": hookEntry],
            ["matcher": "manual", "hooks": hookEntry]
        ]

        var hooks = json["hooks"] as? [String: Any] ?? [:]

        let hookEvents: [(String, [[String: Any]])] = [
            ("UserPromptSubmit", withoutMatcher),
            ("PreToolUse", withMatcher),
            ("PostToolUse", withMatcher),
            ("Notification", withMatcher),
            ("Stop", withoutMatcher),
            ("SubagentStop", withoutMatcher),
            ("SessionStart", withoutMatcher),
            ("SessionEnd", withoutMatcher),
            ("PreCompact", preCompactConfig),
        ]

        for (event, config) in hookEvents {
            if var existingEvent = hooks[event] as? [[String: Any]] {
                let hasOurHook = existingEvent.contains { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { h in
                            let cmd = h["command"] as? String ?? ""
                            return cmd.contains("claude-island-state.py")
                        }
                    }
                    return false
                }
                if !hasOurHook {
                    existingEvent.append(contentsOf: config)
                    hooks[event] = existingEvent
                }
            } else {
                hooks[event] = config
            }
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: settingsURL)
        }
    }

    // MARK: - Cursor IDE: hooks.json (camelCase, flat format)

    private static func updateCursorHooksJSON(at hooksURL: URL) {
        var json: [String: Any] = ["version": 1]
        var hooks: [String: Any] = [:]

        if let data = try? Data(contentsOf: hooksURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let existingHooks = existing["hooks"] as? [String: Any] {
            hooks = existingHooks
        }

        let python = detectPython()
        let command = "\(python) ~/.claude/hooks/\(cursorScriptName)"

        let hookEvents = [
            "beforeSubmitPrompt",
            "preToolUse",
            "postToolUse",
            "stop",
            "subagentStop",
            "sessionStart",
            "sessionEnd",
            "preCompact",
        ]

        for event in hookEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            let hasOurHook = entries.contains { entry in
                (entry["command"] as? String)?.contains("cursor-island-state.py") == true
            }
            if !hasOurHook {
                entries.append(["command": command])
                hooks[event] = entries
            }
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: hooksURL)
        }
    }

    // MARK: - Pi Coding Agent: hooks.json (camelCase, flat format, at ~/.pi/agent/)

    private static func updatePiHooksJSON(at hooksURL: URL) {
        var json: [String: Any] = ["version": 1]
        var hooks: [String: Any] = [:]

        if let data = try? Data(contentsOf: hooksURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let existingHooks = existing["hooks"] as? [String: Any] {
            hooks = existingHooks
        }

        let python = detectPython()
        let command = "\(python) ~/.pi/agent/hooks/\(piScriptName)"

        let hookEvents = [
            "beforeSubmitPrompt",
            "preToolUse",
            "postToolUse",
            "stop",
            "subagentStop",
            "sessionStart",
            "sessionEnd",
            "preCompact",
        ]

        for event in hookEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            // Remove stale cursor-island-state entries from pi config
            entries.removeAll { entry in
                (entry["command"] as? String)?.contains("cursor-island-state.py") == true
            }
            let hasOurHook = entries.contains { entry in
                (entry["command"] as? String)?.contains("pi-island-state.py") == true
            }
            if !hasOurHook {
                entries.append(["command": command])
                hooks[event] = entries
            } else {
                hooks[event] = entries
            }
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: hooksURL)
        }
    }

    // MARK: - Status

    /// Check if hooks are currently installed (checks any config)
    static func isInstalled() -> Bool {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(claudeDirName)

        // Check hooks.json (Cursor)
        let hooksJSON = claudeDir.appendingPathComponent(hooksJSONName)
        if checkHooksJSON(at: hooksJSON, scriptName: cursorScriptName) {
            return true
        }

        // Check settings.json (Claude Code)
        let settingsJSON = claudeDir.appendingPathComponent(settingsJSONName)
        if checkSettingsJSON(at: settingsJSON, scriptName: claudeScriptName) {
            return true
        }

        // Check hooks.json (Pi)
        let piHooksJSON = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(piDirName)
            .appendingPathComponent(piAgentDirName)
            .appendingPathComponent(hooksJSONName)
        if checkHooksJSON(at: piHooksJSON, scriptName: piScriptName) {
            return true
        }

        return false
    }

    private static func checkHooksJSON(at url: URL, scriptName: String) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, value) in hooks {
            if let entries = value as? [[String: Any]] {
                for entry in entries {
                    if let cmd = entry["command"] as? String,
                       cmd.contains(scriptName) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func checkSettingsJSON(at url: URL, scriptName: String) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, value) in hooks {
            if let entries = value as? [[String: Any]] {
                for entry in entries {
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        for hook in entryHooks {
                            if let cmd = hook["command"] as? String,
                               cmd.contains(scriptName) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    // MARK: - Uninstall

    /// Uninstall hooks from all config files and remove scripts
    static func uninstall() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(claudeDirName)
        let hooksDir = claudeDir.appendingPathComponent(hooksDirName)

        // Remove scripts
        let claudeScript = hooksDir.appendingPathComponent(claudeScriptName)
        let cursorScript = hooksDir.appendingPathComponent(cursorScriptName)
        try? FileManager.default.removeItem(at: claudeScript)
        try? FileManager.default.removeItem(at: cursorScript)

        // Clean hooks.json (Cursor)
        let hooksJSON = claudeDir.appendingPathComponent(hooksJSONName)
        cleanHooksJSON(at: hooksJSON, scriptName: cursorScriptName)

        // Clean settings.json (Claude Code)
        let settingsJSON = claudeDir.appendingPathComponent(settingsJSONName)
        cleanSettingsJSON(at: settingsJSON, scriptName: claudeScriptName)

        // Remove Pi script and clean Pi hooks.json
        let piAgentDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(piDirName)
            .appendingPathComponent(piAgentDirName)
        let piHooksDir = piAgentDir.appendingPathComponent(hooksDirName)
        let piScript = piHooksDir.appendingPathComponent(piScriptName)
        try? FileManager.default.removeItem(at: piScript)

        let piHooksJSON = piAgentDir.appendingPathComponent(hooksJSONName)
        cleanHooksJSON(at: piHooksJSON, scriptName: piScriptName)
    }

    private static func cleanHooksJSON(at url: URL, scriptName: String) {
        guard let data = try? Data(contentsOf: url),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return
        }

        for (event, value) in hooks {
            if var entries = value as? [[String: Any]] {
                entries.removeAll { entry in
                    (entry["command"] as? String)?.contains(scriptName) == true
                }
                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }
        }

        json["hooks"] = hooks
        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: url)
        }
    }

    private static func cleanSettingsJSON(at url: URL, scriptName: String) {
        guard let data = try? Data(contentsOf: url),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return
        }

        for (event, value) in hooks {
            if var entries = value as? [[String: Any]] {
                entries.removeAll { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { hook in
                            let cmd = hook["command"] as? String ?? ""
                            return cmd.contains(scriptName)
                        }
                    }
                    return false
                }
                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }
        }

        if hooks.isEmpty {
            json.removeValue(forKey: "hooks")
        } else {
            json["hooks"] = hooks
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: url)
        }
    }

    private static func detectPython() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return "python3"
            }
        } catch {}

        return "python"
    }
}
