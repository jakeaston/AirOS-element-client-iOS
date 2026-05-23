//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// JSON returned by `GET /{organisation}/communications/matrix/session`.
struct AirOSMatrixSessionResponse: Decodable {
    let success: Bool
    let configured: Bool?
    let matrixUserId: String?
    let accessToken: String?
    let homeserverUrl: String?
    /// Optional; Synapse admin login returns this and Element X needs it for `Session`. Extend the Node response to include it when possible.
    let deviceId: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case configured
        case matrixUserId
        case accessToken
        case homeserverUrl
        case deviceId
        case message
    }
}

enum AirOSMatrixSessionClientError: Error {
    case notAuthenticated
    case serverError(statusCode: Int, message: String?)
    case invalidResponse
    case decodingFailed
}
