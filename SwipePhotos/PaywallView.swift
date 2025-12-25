//
//  PaywallView.swift
//  SwipePhotos
//
//  Created by Samik Choudhury on 08/11/25.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Group {
            if let offering = revenueCatManager.currentOffering {
                PaywallView(offering: offering)
                    .onPurchaseCompleted { customerInfo in
                        // Successfully purchased - refresh subscription status and dismiss
                        print("✅ Purchase completed successfully")
                        Task {
                            await revenueCatManager.checkSubscriptionStatus()
                            await revenueCatManager.updateSubscriptionStartDate()
                            // Notify ProfileView to refetch
                            NotificationCenter.default.post(name: .subscriptionDidComplete, object: nil)
                        }
                        dismiss()
                    }
                    .onRestoreCompleted { customerInfo in
                        // Successfully restored - refresh subscription status and dismiss
                        print("✅ Restore completed successfully")
                        Task {
                            await revenueCatManager.checkSubscriptionStatus()
                        }
                        dismiss()
                    }
            } else {
                // Loading state while offerings are being fetched
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading subscription options...")
                        .foregroundColor(.secondary)
                }
                .task {
                    await revenueCatManager.loadOfferings()
                }
            }
        }
    }
}


#Preview {
    SubscriptionPaywallView()
        .environmentObject(RevenueCatManager.shared)
}
