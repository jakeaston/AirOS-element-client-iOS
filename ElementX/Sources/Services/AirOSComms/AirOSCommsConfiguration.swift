//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Runtime configuration for the AirOS Comms Matrix session bridge (native AirOS session → Synapse access token).
enum AirOSCommsConfiguration {
    /// When `true` in Info.plist, the app attempts to use the AirOS bridge instead of the stock Matrix login flow.
    static var isFeatureFlagEnabled: Bool {
        InfoPlistReader.main.airOSCommsEnabled ?? false
    }
    
    /// Validated settings required for the bridge; `nil` when the feature is off or the plist is incomplete.
    static func loadValidated() -> AirOSCommsValidatedConfiguration? {
        guard isFeatureFlagEnabled else {
            return nil
        }
        guard let apiBaseURLString = InfoPlistReader.main.airOSCommsAPIBaseURL,
              let apiBaseURL = URL(string: apiBaseURLString),
              let webSignInURLString = InfoPlistReader.main.airOSCommsWebSignInURL,
              let webSignInURL = URL(string: webSignInURLString) else {
            MXLog.error("AirOS Comms is enabled but API or web sign-in URL is missing from Info.plist.")
            return nil
        }
        guard let organisationSlug = InfoPlistReader.main.airOSCommsOrganisationSlug,
              !organisationSlug.isEmpty else {
            MXLog.error("AirOS Comms is enabled but organisation slug is missing from Info.plist.")
            return nil
        }
        guard let matrixServerName = InfoPlistReader.main.airOSCommsMatrixServerName,
              !matrixServerName.isEmpty else {
            MXLog.error("AirOS Comms is enabled but matrix server name is missing from Info.plist.")
            return nil
        }
        return AirOSCommsValidatedConfiguration(apiBaseURL: apiBaseURL,
                                                webSignInURL: webSignInURL,
                                                organisationSlug: organisationSlug,
                                                matrixServerName: matrixServerName)
    }
    
    /// Whether the AirOS bridge flow should replace the authentication stack on launch.
    static var shouldUseAirOSCommsBridge: Bool {
        loadValidated() != nil
    }
}

struct AirOSCommsValidatedConfiguration: Equatable {
    let apiBaseURL: URL
    let webSignInURL: URL
    let organisationSlug: String
    /// Server name segment of MXIDs (e.g. `comms.example.com`), used for `AppSettings.accountProviders`.
    let matrixServerName: String
    
    func matrixSessionURL() -> URL {
        apiBaseURL.appending(path: organisationSlug, directoryHint: .isDirectory)
            .appending(path: "communications", directoryHint: .isDirectory)
            .appending(path: "matrix", directoryHint: .isDirectory)
            .appending(path: "session", directoryHint: .notDirectory)
    }
}
