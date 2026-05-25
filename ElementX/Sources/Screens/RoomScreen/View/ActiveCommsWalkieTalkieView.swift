//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI
import UIKit

/// Push-to-talk surface for active comms walkie-talkie mode.
struct ActiveCommsWalkieTalkieView: View {
    let isHolding: Bool
    let onPressingChanged: (Bool) -> Void
    
    @State private var isGesturePressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text(UntranslatedL10n.screenRoomActiveCommsWalkieBanner)
                .font(.compound.bodySM)
                .foregroundStyle(Color.compound.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            ZStack {
                Capsule()
                    .fill(isHolding ? Color.compound.bgAccentRest : Color.compound.bgSubtleSecondary)
                    .overlay {
                        Capsule()
                            .stroke(Color.compound.borderInteractiveSecondary, lineWidth: 1)
                    }
                
                Text(isHolding ? UntranslatedL10n.screenRoomActiveCommsWalkieTransmitting : UntranslatedL10n.screenRoomActiveCommsWalkieHold)
                    .font(.compound.headingMDBold)
                    .foregroundStyle(Color.compound.textPrimary)
                    .animation(.easeInOut(duration: 0.15), value: isHolding)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isGesturePressed else { return }
                        isGesturePressed = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onPressingChanged(true)
                    }
                    .onEnded { _ in
                        guard isGesturePressed else { return }
                        isGesturePressed = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onPressingChanged(false)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(UntranslatedL10n.a11yScreenRoomActiveCommsWalkiePtt)
            .accessibilityHint(UntranslatedL10n.screenRoomActiveCommsWalkieBanner)
            .accessibilityAddTraits(.allowsDirectInteraction)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
