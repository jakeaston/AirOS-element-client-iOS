//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

extension AppHooks {
    /// Registers AirOS-specific hooks when Info.plist contains a valid AirOS Comms configuration.
    func configureAirOSCommsIfNeeded() {
        guard AirOSCommsConfiguration.shouldUseAirOSCommsBridge else {
            return
        }
        registerAppSettingsHook(AirOSAppSettingsHook())
    }
}
