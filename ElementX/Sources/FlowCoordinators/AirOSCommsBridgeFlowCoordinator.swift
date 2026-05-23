//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Observation
import SwiftUI
import WebKit

@MainActor
protocol AirOSCommsBridgeFlowCoordinatorDelegate: AnyObject {
    func airOSCommsBridgeFlowCoordinator(didCompleteWith userSession: UserSessionProtocol)
}

/// Replaces the stock Matrix authentication flow when AirOS Comms is enabled: web sign-in to AirOS, then `GET …/matrix/session`, then Matrix SDK restore.
@MainActor
final class AirOSCommsBridgeFlowCoordinator {
    weak var delegate: AirOSCommsBridgeFlowCoordinatorDelegate?
    
    private let navigationRootCoordinator: NavigationRootCoordinator
    private let navigationStackCoordinator = NavigationStackCoordinator()
    private let configuration: AirOSCommsValidatedConfiguration
    private let userSessionStore: UserSessionStoreProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks
    private let loginService: AirOSCommsMatrixLoginService
    private let matrixSessionClient: AirOSMatrixSessionClient
    private let encryptionKeyProvider: EncryptionKeyProviderProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(navigationRootCoordinator: NavigationRootCoordinator,
         configuration: AirOSCommsValidatedConfiguration,
         userSessionStore: UserSessionStoreProtocol,
         appSettings: AppSettings,
         appHooks: AppHooks,
         encryptionKeyProvider: EncryptionKeyProviderProtocol = EncryptionKeyProvider()) {
        self.navigationRootCoordinator = navigationRootCoordinator
        self.configuration = configuration
        self.userSessionStore = userSessionStore
        self.appSettings = appSettings
        self.appHooks = appHooks
        self.encryptionKeyProvider = encryptionKeyProvider
        loginService = AirOSCommsMatrixLoginService(userSessionStore: userSessionStore,
                                                    appSettings: appSettings,
                                                    appHooks: appHooks)
        matrixSessionClient = AirOSMatrixSessionClient()
    }
    
    func start() {
        let viewModel = AirOSCommsBridgeViewModel(configuration: configuration,
                                                  matrixSessionClient: matrixSessionClient,
                                                  loginService: loginService,
                                                  encryptionKeyProvider: encryptionKeyProvider)
        
        viewModel.actions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userSession in
                self?.delegate?.airOSCommsBridgeFlowCoordinator(didCompleteWith: userSession)
            }
            .store(in: &cancellables)
        
        let screenCoordinator = AirOSCommsBridgeScreenCoordinator(viewModel: viewModel)
        navigationStackCoordinator.setRootCoordinator(screenCoordinator)
        navigationRootCoordinator.setRootCoordinator(navigationStackCoordinator)
    }
}

// MARK: - Screen coordinator

private final class AirOSCommsBridgeScreenCoordinator: CoordinatorProtocol {
    private let viewModel: AirOSCommsBridgeViewModel
    
    init(viewModel: AirOSCommsBridgeViewModel) {
        self.viewModel = viewModel
    }
    
    func toPresentable() -> AnyView {
        AnyView(AirOSCommsBridgeScreen(viewModel: viewModel))
    }
}

// MARK: - View model

@MainActor
@Observable
final class AirOSCommsBridgeViewModel {
    private let configuration: AirOSCommsValidatedConfiguration
    private let matrixSessionClient: AirOSMatrixSessionClient
    private let loginService: AirOSCommsMatrixLoginService
    private let encryptionKeyProvider: EncryptionKeyProviderProtocol
    
    private let actionsSubject = PassthroughSubject<UserSessionProtocol, Never>()
    var actions: AnyPublisher<UserSessionProtocol, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    var phase: Phase = .idle
    var footerMessage: String?
    var webSignInURL: URL { configuration.webSignInURL }
    
    enum Phase: Equatable {
        case idle
        case loading
    }
    
    init(configuration: AirOSCommsValidatedConfiguration,
         matrixSessionClient: AirOSMatrixSessionClient,
         loginService: AirOSCommsMatrixLoginService,
         encryptionKeyProvider: EncryptionKeyProviderProtocol) {
        self.configuration = configuration
        self.matrixSessionClient = matrixSessionClient
        self.loginService = loginService
        self.encryptionKeyProvider = encryptionKeyProvider
    }
    
    func send(viewAction: AirOSCommsBridgeViewAction) {
        switch viewAction {
        case .continueTapped:
            Task { await continueAfterWebSignIn() }
        }
    }
    
    private func continueAfterWebSignIn() async {
        phase = .loading
        footerMessage = nil
        
        await AirOSWKCookieSynchronizer.copyWebKitCookiesToSharedStorage()
        
        let matrixSession: AirOSMatrixSessionResponse
        do {
            matrixSession = try await matrixSessionClient.fetchMatrixSession(configuration: configuration)
        } catch AirOSMatrixSessionClientError.notAuthenticated {
            phase = .idle
            footerMessage = UntranslatedL10n.screenAirosCommsBridgeErrorNotSignedIn
            return
        } catch AirOSMatrixSessionClientError.serverError(_, let message) {
            phase = .idle
            footerMessage = message ?? UntranslatedL10n.screenAirosCommsBridgeErrorGeneric
            return
        } catch {
            phase = .idle
            footerMessage = UntranslatedL10n.screenAirosCommsBridgeErrorGeneric
            return
        }
        
        guard matrixSession.configured != false else {
            phase = .idle
            footerMessage = UntranslatedL10n.screenAirosCommsBridgeErrorMatrixDisabled
            return
        }
        
        let sessionDirectories = SessionDirectories()
        let passphrase = encryptionKeyProvider.generateKey().base64EncodedString()
        
        switch await loginService.establishUserSession(matrixSession: matrixSession,
                                                       sessionDirectories: sessionDirectories,
                                                       passphrase: passphrase) {
        case .success(let userSession):
            actionsSubject.send(userSession)
        case .failure(let error):
            phase = .idle
            footerMessage = message(for: error)
        }
    }
    
    private func message(for error: AirOSCommsMatrixLoginServiceError) -> String {
        switch error {
        case .matrixNotConfigured:
            UntranslatedL10n.screenAirosCommsBridgeErrorMatrixDisabled
        case .missingCredentials:
            UntranslatedL10n.screenAirosCommsBridgeErrorNotSignedIn
        case .elementProRequired, .whoamiFailed, .clientBuildFailed, .restoreSessionFailed, .userSessionPersistenceFailed:
            UntranslatedL10n.screenAirosCommsBridgeErrorGeneric
        }
    }
}

enum AirOSCommsBridgeViewAction: Equatable {
    case continueTapped
}

// MARK: - View

struct AirOSCommsBridgeScreen: View {
    @Bindable var viewModel: AirOSCommsBridgeViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(UntranslatedL10n.screenAirosCommsBridgeSubtitle)
                    .font(.compound.bodyMD)
                    .foregroundStyle(Color.compound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                AirOSCommsWebView(url: viewModel.webSignInURL)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.compound.borderInteractiveSecondary, lineWidth: 1)
                    }
                    .padding(.horizontal)
                
                if let footer = viewModel.footerMessage {
                    Text(footer)
                        .font(.compound.bodySM)
                        .foregroundStyle(Color.compound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button {
                    viewModel.send(viewAction: .continueTapped)
                } label: {
                    Text(UntranslatedL10n.screenAirosCommsBridgeContinue)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.primary, size: .large))
                .padding(.horizontal)
                .disabled(viewModel.phase == .loading)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(UntranslatedL10n.screenAirosCommsBridgeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .overlay {
                if viewModel.phase == .loading {
                    ProgressView()
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct AirOSCommsWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }
}

// MARK: - Previews

struct AirOSCommsBridgeScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        let configuration = AirOSCommsValidatedConfiguration(apiBaseURL: URL(string: "https://example.com")!,
                                                           webSignInURL: URL(string: "https://example.com/login")!,
                                                           organisationSlug: "demo",
                                                           matrixServerName: "example.com")
        let vm = AirOSCommsBridgeViewModel(configuration: configuration,
                                           matrixSessionClient: AirOSMatrixSessionClient(),
                                           loginService: AirOSCommsMatrixLoginService(userSessionStore: UserSessionStoreMock(configuration: .init()),
                                                                                      appSettings: AppSettings(),
                                                                                      appHooks: AppHooks()),
                                           encryptionKeyProvider: EncryptionKeyProvider())
        AirOSCommsBridgeScreen(viewModel: vm)
    }
}
