//
//  IslandSessionEvent.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated struct IslandSessionStarted: Equatable, Codable, Sendable {
    var sessionID: String
    var identity: IslandSessionIdentity
    var title: String
    var tool: IslandAgentTool
    var initialPhase: IslandSessionPhase
    var summary: String
    var timestamp: Date
    var currentTool: String?
    var commandPreview: String?
    var initialPrompt: String?
    var latestPrompt: String?
    var lastAssistantMessage: String?
    var terminalTag: String?
    var lastError: String?
}

nonisolated struct IslandSessionActivityUpdated: Equatable, Codable, Sendable {
    var sessionID: String
    var summary: String
    var phase: IslandSessionPhase
    var timestamp: Date
    var currentTool: String?
    var commandPreview: String?
    var latestPrompt: String?
    var lastAssistantMessage: String?
    var lastError: String?
}

nonisolated struct IslandPermissionRequested: Equatable, Codable, Sendable {
    var sessionID: String
    var request: IslandPermissionRequest
    var timestamp: Date
}

nonisolated struct IslandQuestionAsked: Equatable, Codable, Sendable {
    var sessionID: String
    var prompt: IslandQuestionPrompt
    var timestamp: Date
}

nonisolated struct IslandSessionCompleted: Equatable, Codable, Sendable {
    var sessionID: String
    var summary: String
    var timestamp: Date
    var failed: Bool
    var lastAssistantMessage: String?
}

nonisolated struct IslandActionableStateResolved: Equatable, Codable, Sendable {
    var sessionID: String
    var summary: String
    var timestamp: Date
}

nonisolated enum IslandSessionEvent: Equatable, Codable, Sendable {
    case sessionStarted(IslandSessionStarted)
    case activityUpdated(IslandSessionActivityUpdated)
    case permissionRequested(IslandPermissionRequested)
    case questionAsked(IslandQuestionAsked)
    case sessionCompleted(IslandSessionCompleted)
    case actionableStateResolved(IslandActionableStateResolved)
}
