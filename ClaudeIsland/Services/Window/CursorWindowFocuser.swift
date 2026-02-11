//
//  CursorWindowFocuser.swift
//  ClaudeIsland
//
//  Focuses Cursor IDE windows by workspace path using AppleScript.
//

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.claudeisland", category: "CursorWindowFocuser")

/// Focuses Cursor IDE windows by matching workspace folder name in window title.
actor CursorWindowFocuser {
    static let shared = CursorWindowFocuser()

    private init() {}

    /// Focus the Cursor window whose title contains the last path component of workspacePath.
    /// - Parameter workspacePath: e.g. "/Users/dmitry/Dev/cursor-island"
    /// - Returns: true if a matching window was found and focused
    func focusCursorWindow(workspacePath: String) async -> Bool {
        logger.info("focusCursorWindow(workspacePath: \(workspacePath, privacy: .public))")
        let path = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, path != "/" else {
            logger.warning("Invalid path: empty or root")
            return false
        }

        let folderName = (path as NSString).lastPathComponent
        guard !folderName.isEmpty else {
            logger.warning("Empty folder name from path: \(path, privacy: .public)")
            return false
        }
        logger.info("Matching Cursor window by folder name: \(folderName, privacy: .public)")

        let escaped = folderName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "System Events"
            tell process "Cursor"
                set frontmost to true
                repeat with w in windows
                    if name of w contains "\(escaped)" then
                        perform action "AXRaise" of w
                        return "ok"
                    end if
                end repeat
            end tell
        end tell
        return "notfound"
        """

        let result = await runScript(script)
        let success = result == "ok"
        logger.info("AppleScript result: \(result, privacy: .public), success: \(success)")
        return success
    }

    private func runScript(_ source: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)
                if let err = error {
                    logger.error("AppleScript error: \(String(describing: err), privacy: .public)")
                    let code = err["NSAppleScriptErrorNumber"] as? NSNumber
                    if code?.intValue == -1743 {
                        Self.openAutomationPrivacyPane()
                    }
                }
                let output: String
                if let desc = result?.stringValue {
                    output = desc
                } else if error != nil {
                    output = "notfound"
                } else {
                    output = "notfound"
                }
                continuation.resume(returning: output)
            }
        }
    }

    /// Open System Settings → Privacy & Security → Automation so the user can grant this app permission to control System Events.
    private static func openAutomationPrivacyPane() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else { return }
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
        logger.info("Opened Automation privacy pane for permission grant")
    }
}
