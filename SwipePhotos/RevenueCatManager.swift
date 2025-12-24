import SwiftUI
import RevenueCat
import Combine

@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var isSubscribed = false
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var currentOffering: Offering?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let entitlementID = "OneNada Pro" // Your entitlement ID from dashboard
    
    private override init() {
        super.init()
        // Set as delegate to listen for updates
        Purchases.shared.delegate = self
        // Check initial subscription status for anonymous user
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - Setup with User ID
    /// Call this after user logs in with their Supabase user ID
    func setupWithUserID(_ userID: String) async {
        // Set the user ID so RevenueCat knows who this is
        Purchases.shared.logIn(userID) { customerInfo, _, error in
            if let error = error {
                print("Error setting RevenueCat user: \(error.localizedDescription)")
            }
        }
        
        // Load offerings immediately
        await loadOfferings()
        await checkSubscriptionStatus()
    }
    
    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        isLoading = true
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            
            for (key, entitlement) in customerInfo.entitlements.all {
                print("  - \(key): active=\(entitlement.isActive)")
            }
            
            // Check if user has the premium entitlement
            self.isSubscribed = customerInfo.entitlements[entitlementID]?.isActive == true
            errorMessage = nil
            
        } catch {
            errorMessage = error.localizedDescription
            isSubscribed = false
        }
        isLoading = false
    }
    
    // MARK: - Load Offerings
    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            self.currentOffering = offerings.current

        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Make Purchase
    func purchase(package: Package) async -> Bool {
        isLoading = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                await checkSubscriptionStatus()
                isLoading = false
                return true
            } else {
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[entitlementID]?.isActive == true
            errorMessage = nil
            
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            _ = try await Purchases.shared.logOut()
            self.isSubscribed = false
            self.customerInfo = nil
            self.offerings = nil
            self.currentOffering = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete User
    /// Deletes the user's data from RevenueCat
    /// This anonymizes the user by logging them out
    /// For complete data deletion, you need to call RevenueCat's REST API from your backend
    func deleteUser(appUserID: String) async throws {
        // RevenueCat doesn't expose a deleteCustomer() method in the SDK
        // For security reasons, customer deletion should be done via:
        // 1. Your backend calling RevenueCat's REST API with your Secret API Key
        // 2. Or manually through the RevenueCat dashboard

        // For now, we log out the user which anonymizes them
        do {
            // Log out the user (this anonymizes them in RevenueCat)
            _ = try await Purchases.shared.logOut()

            // Clear local state
            self.isSubscribed = false
            self.customerInfo = nil
            self.offerings = nil
            self.currentOffering = nil

            print("✓ User logged out from RevenueCat (anonymized)")
            print("ℹ️ For complete GDPR deletion, call RevenueCat REST API: DELETE /v1/subscribers/\(appUserID)")

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    /// Called when subscription status changes
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[self.entitlementID]?.isActive == true
        }
    }
}
