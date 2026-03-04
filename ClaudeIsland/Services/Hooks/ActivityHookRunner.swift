//
//  ActivityHookRunner.swift
//  ClaudeIsland
//
//  Fires shell scripts when aggregate session activity changes:
//  idle → active triggers active.sh, active → idle triggers idle.sh.
//

import Combine
import Foundation
import os.log

private let logger = Logger(subsystem: "com.claudeisland", category: "ActivityHooks")

class ActivityHookRunner {
    static let shared = ActivityHookRunner()

    private static let idleScript = "/Users/dmitry/Dev/osx/configs/cursor/hooks/idle.sh"
    private static let activeScript = "/Users/dmitry/Dev/osx/configs/cursor/hooks/active.sh"

    private var wasActive: Bool?
    private var cancellable: AnyCancellable?
    private let queue = DispatchQueue(label: "com.claudeisland.activity-hooks")

    private init() {}

    func start() {
        cancellable = SessionStore.shared.sessionsPublisher
            .map { sessions in sessions.contains { $0.phase.isActive } }
            .removeDuplicates()
            .receive(on: queue)
            .sink { [weak self] isActive in
                self?.handleActivityChange(isActive: isActive)
            }
    }

    private func handleActivityChange(isActive: Bool) {
        guard let previouslyActive = wasActive else {
            wasActive = isActive
            return
        }

        wasActive = isActive

        if previouslyActive && !isActive {
            logger.info("All sessions idle, running idle hook")
            runScript(Self.idleScript)
        } else if !previouslyActive && isActive {
            logger.info("Session became active, running active hook")
            runScript(Self.activeScript)
        }
    }

    private func runScript(_ path: String) {
        Task {
            let result = await ProcessExecutor.shared.runWithResult("/bin/sh", arguments: [path])
            switch result {
            case .success:
                logger.debug("Hook script succeeded: \(path, privacy: .public)")
            case .failure(let error):
                logger.warning("Hook script failed: \(path, privacy: .public) - \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
