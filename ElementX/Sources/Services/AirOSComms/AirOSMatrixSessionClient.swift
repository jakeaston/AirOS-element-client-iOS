//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Fetches a Synapse access token from the AirOS Node API using the same session cookie model as the web app.
final class AirOSMatrixSessionClient {
    private let urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    func fetchMatrixSession(configuration: AirOSCommsValidatedConfiguration) async throws -> AirOSMatrixSessionResponse {
        let url = configuration.matrixSessionURL()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AirOSMatrixSessionClientError.invalidResponse
        }
        
        switch http.statusCode {
        case 200:
            break
        case 403:
            throw AirOSMatrixSessionClientError.notAuthenticated
        case 500...599:
            let message = (try? JSONDecoder().decode(AirOSMatrixSessionResponse.self, from: data)).flatMap(\.message)
            throw AirOSMatrixSessionClientError.serverError(statusCode: http.statusCode, message: message)
        default:
            throw AirOSMatrixSessionClientError.serverError(statusCode: http.statusCode, message: nil)
        }
        
        do {
            let decoded = try JSONDecoder().decode(AirOSMatrixSessionResponse.self, from: data)
            guard decoded.success else {
                throw AirOSMatrixSessionClientError.serverError(statusCode: http.statusCode, message: decoded.message)
            }
            return decoded
        } catch let error as AirOSMatrixSessionClientError {
            throw error
        } catch {
            MXLog.error("Failed decoding AirOS matrix session response.")
            throw AirOSMatrixSessionClientError.decodingFailed
        }
    }
}
