//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

enum AirOSCommsMatrixLoginServiceError: Error {
    case matrixNotConfigured
    case missingCredentials
    case elementProRequired
    case whoamiFailed
    case clientBuildFailed
    case restoreSessionFailed
    case userSessionPersistenceFailed
}

/// Builds a Matrix Rust `Client` from an AirOS-minted Synapse access token and persists it like a normal Element X login.
final class AirOSCommsMatrixLoginService {
    private let userSessionStore: UserSessionStoreProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks
    private let clientFactory: AuthenticationClientFactoryProtocol
    private let urlSession: URLSession
    
    init(userSessionStore: UserSessionStoreProtocol,
         appSettings: AppSettings,
         appHooks: AppHooks,
         clientFactory: AuthenticationClientFactoryProtocol = AuthenticationClientFactory(),
         urlSession: URLSession = .shared) {
        self.userSessionStore = userSessionStore
        self.appSettings = appSettings
        self.appHooks = appHooks
        self.clientFactory = clientFactory
        self.urlSession = urlSession
    }
    
    func establishUserSession(matrixSession: AirOSMatrixSessionResponse,
                                sessionDirectories: SessionDirectories,
                                passphrase: String) async -> Result<UserSessionProtocol, AirOSCommsMatrixLoginServiceError> {
        guard matrixSession.success else {
            return .failure(.missingCredentials)
        }
        guard matrixSession.configured != false else {
            return .failure(.matrixNotConfigured)
        }
        guard let accessToken = matrixSession.accessToken,
              let matrixUserId = matrixSession.matrixUserId,
              let homeserverUrl = matrixSession.homeserverUrl else {
            return .failure(.missingCredentials)
        }
        
        let deviceId: String
        if let knownDeviceId = matrixSession.deviceId, !knownDeviceId.isEmpty {
            deviceId = knownDeviceId
        } else {
            switch await fetchDeviceId(accessToken: accessToken, homeserverURLString: homeserverUrl) {
            case .success(let id):
                deviceId = id
            case .failure(let error):
                MXLog.error("Failed resolving device id for AirOS Matrix session: \(error)")
                return .failure(.whoamiFailed)
            }
        }
        
        let session = Session(accessToken: accessToken,
                              refreshToken: nil,
                              userId: matrixUserId,
                              deviceId: deviceId,
                              homeserverUrl: homeserverUrl,
                              oauthData: nil,
                              slidingSyncVersion: .native)
        
        let client: ClientProtocol
        do {
            client = try await clientFactory.makeClient(homeserverAddress: homeserverUrl,
                                                        sessionDirectories: sessionDirectories,
                                                        passphrase: passphrase,
                                                        clientSessionDelegate: userSessionStore.clientSessionDelegate,
                                                        appSettings: appSettings,
                                                        appHooks: appHooks)
        } catch {
            MXLog.error("Failed building Matrix client for AirOS session: \(error)")
            return .failure(.clientBuildFailed)
        }
        
        do {
            try await appHooks.remoteSettingsHook.initializeCache(using: client, applyingTo: appSettings).get()
        } catch RemoteSettingsError.elementProRequired {
            return .failure(.elementProRequired)
        } catch {
            MXLog.error("Failed remote settings check for AirOS session: \(error)")
            return .failure(.clientBuildFailed)
        }
        
        do {
            try await client.restoreSession(session: session)
        } catch {
            MXLog.error("Failed restoring Matrix session from AirOS token: \(error)")
            return .failure(.restoreSessionFailed)
        }
        
        switch await userSessionStore.userSession(for: client, sessionDirectories: sessionDirectories, passphrase: passphrase) {
        case .success(let userSession):
            return .success(userSession)
        case .failure:
            return .failure(.userSessionPersistenceFailed)
        }
    }
    
    // MARK: - Whoami
    
    private struct MatrixWhoamiResponse: Decodable {
        let deviceId: String
        
        enum CodingKeys: String, CodingKey {
            case deviceId = "device_id"
        }
    }
    
    private func fetchDeviceId(accessToken: String, homeserverURLString: String) async -> Result<String, Error> {
        guard let homeserverURL = URL(string: homeserverURLString),
              let whoamiURL = URL(string: "_matrix/client/v3/account/whoami", relativeTo: homeserverURL) else {
            return .failure(AirOSCommsMatrixLoginServiceError.whoamiFailed)
        }
        
        var request = URLRequest(url: whoamiURL.absoluteURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .failure(AirOSCommsMatrixLoginServiceError.whoamiFailed)
            }
            let whoami = try JSONDecoder().decode(MatrixWhoamiResponse.self, from: data)
            return .success(whoami.deviceId)
        } catch {
            return .failure(error)
        }
    }
}
