//
//  AppUpdaterController.swift
//  Argo
//
//  Author: krystal
//

import Foundation
import Sparkle

@MainActor
private final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var updateChannel: ReleaseChannel = .stable

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        AppUpdaterController.resolveFeedURLString(infoDictionary: Bundle.main.infoDictionary)
    }

    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        MainActor.assumeIsolated {
            switch updateChannel {
            case .stable:
                return []
            case .preview:
                return ["preview"]
            }
        }
    }
}

@MainActor
final class AppUpdaterController {
    static let shared = AppUpdaterController()

    nonisolated static let gitLabHost = "code.devops.xiaohongshu.com"
    nonisolated static let repositoryPath = "huying/Argo"
    nonisolated static let repositoryURL = URL(string: "https://\(gitLabHost)/\(repositoryPath)")!
    nonisolated static let releasesURL = URL(string: "\(repositoryURL.absoluteString)/-/releases")!
    nonisolated static let feedURLInfoPlistKey = "SUFeedURL"
    nonisolated static let defaultFeedURLString = "\(repositoryURL.absoluteString)/-/raw/stable/appcast.xml"
    static let sparkleKeyAccount = "argo"
    static let defaultPrivateKeyPath: String = {
        let releaseHome = ProcessInfo.processInfo.environment["ARGO_RELEASE_HOME"] ?? "\(NSHomeDirectory())/.argo_release"
        return "\(releaseHome)/sparkle_private_key"
    }()

    private let delegate = SparkleUpdaterDelegate()
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: delegate,
        userDriverDelegate: nil
    )

    func configure(
        updateChannel: ReleaseChannel,
        automaticallyChecks: Bool,
        automaticallyDownloads: Bool,
        checkInBackground: Bool
    ) {
        let updater = controller.updater
        delegate.updateChannel = updateChannel
        updater.automaticallyChecksForUpdates = automaticallyChecks
        updater.automaticallyDownloadsUpdates = automaticallyDownloads
        updater.updateCheckInterval = updateChannel == .preview ? 21600 : 86400

        if checkInBackground, automaticallyChecks {
            updater.checkForUpdatesInBackground()
        }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    nonisolated static func resolveFeedURLString(infoDictionary: [String: Any]?) -> String {
        guard
            let value = infoDictionary?[feedURLInfoPlistKey] as? String,
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return defaultFeedURLString
        }
        return value
    }
}
