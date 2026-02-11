//
//  SessionPhase.swift
//  ClaudeIsland
//
//  Explicit state machine for Claude session lifecycle.
//

import Foundation

/// Explicit session phases - the state machine
enum SessionPhase: Sendable {
    /// Session is idle, waiting for user input or new activity
    case idle

    /// Claude is actively processing (running tools, generating response)
    case processing

    /// Claude has finished and is waiting for user input
    case waitingForInput

    /// Context is being compacted (auto or manual)
    case compacting

    /// Session has ended
    case ended

    // MARK: - State Machine Transitions

    nonisolated func canTransition(to next: SessionPhase) -> Bool {
        switch (self, next) {
        case (.ended, _):
            return false
        case (_, .ended):
            return true
        case (.idle, .processing), (.idle, .compacting):
            return true
        case (.processing, .waitingForInput), (.processing, .compacting), (.processing, .idle):
            return true
        case (.waitingForInput, .processing), (.waitingForInput, .idle), (.waitingForInput, .compacting):
            return true
        case (.compacting, .processing), (.compacting, .idle), (.compacting, .waitingForInput):
            return true
        default:
            return self == next
        }
    }

    nonisolated func transition(to next: SessionPhase) -> SessionPhase? {
        canTransition(to: next) ? next : nil
    }

    /// Whether this phase indicates the session needs user attention
    var needsAttention: Bool {
        if case .waitingForInput = self { return true }
        return false
    }

    /// Whether this phase indicates active processing
    var isActive: Bool {
        switch self {
        case .processing, .compacting:
            return true
        default:
            return false
        }
    }
}

// MARK: - Equatable

extension SessionPhase: Equatable {}

// MARK: - Debug Description

extension SessionPhase: CustomStringConvertible {
    nonisolated var description: String {
        switch self {
        case .idle: return "idle"
        case .processing: return "processing"
        case .waitingForInput: return "waitingForInput"
        case .compacting: return "compacting"
        case .ended: return "ended"
        }
    }
}
