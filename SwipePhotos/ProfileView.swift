import SwiftUI
import Supabase
import StoreKit
import LocalAuthentication

struct ProfileView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State var isLoading = false
    @State var profile: UserProfile?
    @State var errorMessage: String?
    @AppStorage("hasUserReviewedApp") private var hasUserReviewedApp: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var pinManager = PINManager()
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled: Bool = false
    @State private var showPINSetup = false
    @State private var showPINVerification = false
    @State private var showSecurityAlert = false
    @State private var securityAlertMessage = ""
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var subscriptionTimer: Timer?
    @State private var elapsedTime: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        // Profile Icon
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .frame(width: 120, height: 120)

                        // Email
                        if let email = profile?.email {
                            Text(email)
                                .font(.title3)
                                .fontWeight(.medium)
                        }

                        // Subscription Status & Timer
                        if let subscriptionDate = profile?.subscriptionStartedAt {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    Text("Subscribed since \(subscriptionDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Live timer showing subscription duration
                                Text(elapsedTime)
                                    .font(.system(.title2, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .onAppear {
                                startSubscriptionTimer(from: subscriptionDate)
                            }
                            .onDisappear {
                                subscriptionTimer?.invalidate()
                            }
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                        }

                        // Theme Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Theme")
                                .font(.headline)
                                .padding(.top)
                            
                            HStack(spacing: 20) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(themeManager.currentTheme == theme ? Color.blue.opacity(0.2) : Color(.systemGray5))
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: theme.iconName)
                                                .font(.system(size: 24))
                                                .foregroundColor(themeManager.currentTheme == theme ? .blue : .primary)
                                        }
                                        
                                        Text(theme.displayName)
                                            .font(.caption)
                                            .fontWeight(themeManager.currentTheme == theme ? .semibold : .regular)
                                            .foregroundColor(themeManager.currentTheme == theme ? .blue : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            themeManager.currentTheme = theme
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        // Security Settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Security")
                                .font(.headline)
                                .padding(.top)
                            
                            VStack(spacing: 12) {
                                // Biometric Authentication Toggle
                                if biometricAuthManager.canUseBiometrics() {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: biometricAuthManager.getBiometricType() == "Face ID" ? "faceid" : "touchid")
                                                    .foregroundColor(.blue)
                                                Text("\(biometricAuthManager.getBiometricType()) Authentication")
                                                    .font(.body)
                                            }
                                            Text("Use biometric authentication with device passcode fallback")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $isBiometricEnabled)
                                            .onChange(of: isBiometricEnabled) { oldValue, newValue in
                                                if newValue {
                                                    enableBiometricAuth()
                                                }
                                            }
                                    }
                                    .padding(.vertical, 8)
                                    
                                    Divider()
                                }
                                
                                // PIN Authentication Toggle
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "key.fill")
                                                .foregroundColor(.green)
                                            Text("App PIN")
                                                .font(.body)
                                        }
                                        Text("Set a 4-digit PIN for app-specific authentication")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: .init(
                                        get: { pinManager.isPINEnabled },
                                        set: { newValue in
                                            if newValue {
                                                showPINSetup = true
                                            } else {
                                                disablePIN()
                                            }
                                        }
                                    ))
                                }
                                .padding(.vertical, 8)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        Spacer()

                        // App Store Review Button
                        VStack {
                            Button(hasUserReviewedApp ? "Thank you for reviewing!" : "Rate App on App Store") {
                                if !hasUserReviewedApp {
                                    openAppStoreReview()
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(hasUserReviewedApp ? .green : .blue)
                            .disabled(hasUserReviewedApp)
                            .onLongPressGesture {
                                if hasUserReviewedApp {
                                    // Reset review status (for testing)
                                    hasUserReviewedApp = false
                                }
                            }
                            
                            if hasUserReviewedApp {
                                Text("Long press to reset")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Button("Sign out", role: .destructive) {
                            Task {
                                try? await supabase.auth.signOut()
                                await revenueCatManager.signOut()
                                // Post notification to update the UI
                                NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        // Delete Account Button
                        Button("Delete Account") {
                            showDeleteAccountAlert = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(isDeletingAccount)

                        if isDeletingAccount {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Deleting account...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Profile")
            .task {
                await fetchProfile()
            }
            .refreshable {
                await fetchProfile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidComplete)) { _ in
                // Refetch profile to get updated subscription_started_at
                Task {
                    await fetchProfile()
                }
            }
            .sheet(isPresented: $showPINSetup) {
                PINSetupView(pinManager: pinManager)
            }
            .sheet(isPresented: $showPINVerification) {
                PINVerificationView(pinManager: pinManager) {
                    // Success action - disable PIN after verification
                    disablePINAfterVerification()
                }
            }
            .alert("Security", isPresented: $showSecurityAlert) {
                Button("OK") { }
            } message: {
                Text(securityAlertMessage)
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This will permanently delete all your data and settings. This action cannot be undone.")
            }
        }
    }

    func fetchProfile() async {
        // Only show loading indicator if no profile is loaded yet
        if profile == nil {
            isLoading = true
        }
        errorMessage = nil

        do {
            // Get the current user - this will throw if no session exists
            let user = try await supabase.auth.user()

            // Fetch profile from Supabase
            let response: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value

            if let existingProfile = response.first {
                profile = existingProfile
            } else {
                // Profile should be created by database trigger, wait and retry once
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                
                let retryResponse: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .execute()
                    .value
                
                profile = retryResponse.first
                
                if profile == nil {
                    errorMessage = "Profile not found. Please try again."
                }
            }
        } catch is CancellationError {
            // Task was cancelled (common with pull-to-refresh), ignore silently
            // Don't clear profile - keep existing data visible
        } catch {
            // Don't show error message for session missing - it's expected after sign out
            if error.localizedDescription.contains("sessionMissing") || error.localizedDescription.contains("Auth session is missing") {
                profile = nil
            }
            // For other errors, don't clear profile or show error on refresh
        }

        isLoading = false
    }
    
    private func openAppStoreReview() {
        // Mark that user has reviewed the app (they clicked the review button)
        hasUserReviewedApp = true
        
        // TODO: Replace YOUR_APP_ID with your actual App Store ID when available
        guard let url = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review") else { 
            // Fallback to main App Store if review URL fails
            if let fallbackURL = URL(string: "https://apps.apple.com/") {
                UIApplication.shared.open(fallbackURL)
            }
            return 
        }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Security Functions
    
    private func enableBiometricAuth() {
        biometricAuthManager.authenticateWithDeviceOwner { success, error in
            if success {
                securityAlertMessage = "\(biometricAuthManager.getBiometricType()) authentication enabled successfully!"
                showSecurityAlert = true
            } else {
                isBiometricEnabled = false
                securityAlertMessage = "Failed to enable biometric authentication: \(error?.localizedDescription ?? "Unknown error")"
                showSecurityAlert = true
            }
        }
    }
    
    private func disablePIN() {
        if pinManager.hasPIN() {
            // Verify current PIN before disabling
            showPINVerification = true
        } else {
            let success = pinManager.deletePIN()
            securityAlertMessage = success ? "PIN disabled successfully!" : "Failed to disable PIN"
            showSecurityAlert = true
        }
    }
    
    private func disablePINAfterVerification() {
        let success = pinManager.deletePIN()
        securityAlertMessage = success ? "PIN disabled successfully!" : "Failed to disable PIN"
        showSecurityAlert = true
    }

    // MARK: - Account Deletion

    /// Deletes the user's account by calling the backend RPC function
    func deleteAccount() async {
        isDeletingAccount = true
        errorMessage = nil

        do {
            // Call the delete_user RPC function - cascade will handle cleanup
            try await supabase.rpc("delete_user").execute()

            // Sign out the user
            try? await supabase.auth.signOut()
            await revenueCatManager.signOut()

            // Clear local state
            profile = nil

            // Post notification to update the UI
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)

        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            isDeletingAccount = false
            return
        }

        isDeletingAccount = false
    }
    
    // MARK: - Subscription Timer
    
    private func startSubscriptionTimer(from startDate: Date) {
        // Update immediately
        updateElapsedTime(from: startDate)
        
        // Then update every second
        subscriptionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateElapsedTime(from: startDate)
        }
    }
    
    private func updateElapsedTime(from startDate: Date) {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: startDate, to: now)
        
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        
        if days > 0 {
            elapsedTime = String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        } else {
            elapsedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(RevenueCatManager.shared)
}
