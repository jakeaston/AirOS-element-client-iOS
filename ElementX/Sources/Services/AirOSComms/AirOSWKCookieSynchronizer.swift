//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import WebKit

enum AirOSWKCookieSynchronizer {
    /// Copies cookies from the default WK data store into `HTTPCookieStorage.shared` so `URLSession` can send the AirOS session cookie.
    static func copyWebKitCookiesToSharedStorage() async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        await withCheckedContinuation { continuation in
            store.getAllCookies { cookies in
                for cookie in cookies {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                continuation.resume()
            }
        }
    }
}
