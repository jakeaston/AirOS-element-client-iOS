//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Locks the app to the AirOS Matrix deployment and hides arbitrary homeserver entry when the AirOS bridge is enabled.
struct AirOSAppSettingsHook: AppSettingsHookProtocol {
    func configure(_ appSettings: AppSettings) -> AppSettings {
        guard let configuration = AirOSCommsConfiguration.loadValidated() else {
            return appSettings
        }
        appSettings.override(accountProviders: [configuration.matrixServerName],
                             allowOtherAccountProviders: false,
                             hideBrandChrome: appSettings.hideBrandChrome,
                             pushGatewayBaseURL: appSettings.pushGatewayBaseURL,
                             oidcRedirectURL: appSettings.oidcRedirectURL,
                             websiteURL: appSettings.websiteURL,
                             logoURL: appSettings.logoURL,
                             copyrightURL: appSettings.copyrightURL,
                             acceptableUseURL: appSettings.acceptableUseURL,
                             privacyURL: appSettings.privacyURL,
                             encryptionURL: appSettings.encryptionURL,
                             deviceVerificationURL: appSettings.deviceVerificationURL,
                             chatBackupDetailsURL: appSettings.chatBackupDetailsURL,
                             identityPinningViolationDetailsURL: appSettings.identityPinningViolationDetailsURL,
                             historySharingDetailsURL: appSettings.historySharingDetailsURL,
                             elementWebHosts: appSettings.elementWebHosts,
                             accountProvisioningHost: appSettings.accountProvisioningHost,
                             bugReportApplicationID: appSettings.bugReportApplicationID,
                             analyticsTermsURL: appSettings.analyticsTermsURL,
                             mapTilerConfiguration: appSettings.mapTilerConfiguration)
        return appSettings
    }
}
