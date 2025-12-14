import SwiftUI
import Supabase
import StoreKit
import LocalAuthentication
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State var isLoading = false
    @State var profile: UserProfile?
    @State var errorMessage: String?
    @State var isEditingName = false
    @State var editedName = ""
    @State var isSaving = false
    @AppStorage("hasUserReviewedApp") private var hasUserReviewedApp: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var pinManager = PINManager()
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled: Bool = false
    @State private var showPINSetup = false
    @State private var showPINVerification = false
    @State private var showSecurityAlert = false
    @State private var securityAlertMessage = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var profileImageURL: URL?
    @State private var selectedImage: UIImage?
    @State private var showImageCropper = false
    @State private var isLoadingImage = false
    @State private var showFullScreenImage = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    // Profile Image
                    ZStack(alignment: .bottomTrailing) {
                        if let url = profileImageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                case .success(let image):
                                    ZStack {
                                        Circle()
                                            .fill(Color(.systemGray6))
                                            .frame(width: 120, height: 120)

                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    }
                                    .onTapGesture {
                                        showFullScreenImage = true
                                    }
                                case .failure(let error):
                                    VStack(spacing: 4) {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray)
                                            .frame(width: 120, height: 120)
                                        Text("Tap to retry")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    .onTapGesture {
                                        // Force refresh profile
                                        Task {
                                            print("Image load failed for URL: \(url)")
                                            print("Error: \(error)")
                                            await loadProfileImage()
                                        }
                                    }
                                @unknown default:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                        .frame(width: 120, height: 120)
                                }
                            }
                            .id(url) // Force reload when URL changes
                        } else {
                            // Placeholder for profile image
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .frame(width: 120, height: 120)
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "pencil")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .disabled(isUploadingPhoto || isLoadingImage)
                        .offset(x: -5, y: -5)

                        if isUploadingPhoto || isLoadingImage {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 36, height: 36)

                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            }
                            .offset(x: -5, y: -5)
                        }
                    }
                    .onChange(of: selectedPhotoItem) { oldValue, newValue in
                        Task {
                            await loadSelectedImage()
                        }
                    }

                    // Name editing section
                    VStack {
                        if isEditingName {
                            HStack {
                                TextField("Enter your name", text: $editedName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(isSaving)
                                
                                Button("Save") {
                                    Task {
                                        await saveName()
                                    }
                                }
                                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                                
                                Button("Cancel") {
                                    isEditingName = false
                                    editedName = profile?.name ?? ""
                                }
                                .disabled(isSaving)
                            }
                            
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        } else {
                            HStack {
                                if let name = profile?.name, !name.isEmpty {
                                    Text(name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                } else {
                                    Text("No Name Set")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                }
                                
                                Button(action: {
                                    editedName = profile?.name ?? ""
                                    isEditingName = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    // Email
                    if let email = profile?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                await loadProfileImage()
            }
            .refreshable {
                await fetchProfile()
                await loadProfileImage()
            }
            .onAppear {
                Task {
                    await fetchProfile()
                    await loadProfileImage()
                }
            }
            .onChange(of: profile?.profileImageUrl) { oldValue, newValue in
                Task {
                    await loadProfileImage()
                }
            }
            .fullScreenCover(isPresented: $showFullScreenImage) {
                if let url = profileImageURL {
                    FullScreenImageView(imageURL: url)
                }
            }
            .sheet(isPresented: $showImageCropper) {
                if let image = selectedImage {
                    ImageCropperView(image: image) { croppedImage in
                        Task {
                            await uploadProfilePhoto(image: croppedImage)
                        }
                        showImageCropper = false
                    } onCancel: {
                        selectedPhotoItem = nil
                        selectedImage = nil
                        showImageCropper = false
                    }
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
                Text("Are you sure you want to delete your account? This will permanently delete all your data including photos, profile information, and settings. This action cannot be undone.")
            }
        }
    }

    func saveName() async {
        isSaving = true
        errorMessage = nil
        
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let user = try await supabase.auth.user()
            
            // Update profile in Supabase
            try await supabase
                .from("profiles")
                .update(["name": trimmedName])
                .eq("id", value: user.id.uuidString)
                .execute()
            
            // Update local profile only if save was successful
            var updatedProfile = profile
            updatedProfile?.name = trimmedName
            profile = updatedProfile
            
            isEditingName = false
        } catch {
            errorMessage = "Failed to update name: \(error.localizedDescription)"
        }
        
        isSaving = false
    }

    func fetchProfile() async {
        isLoading = true
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
                // Profile exists, use it
                profile = existingProfile
            } else {
                // Profile should be created by database trigger, wait a bit and retry
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                
                let retryResponse: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .execute()
                    .value
                
                profile = retryResponse.first
            }
        } catch {
            // Don't show error message for session missing - it's expected after sign out
            if error.localizedDescription.contains("sessionMissing") || error.localizedDescription.contains("Auth session is missing") {
                profile = nil
            } else {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }
    
    private func openAppStoreReview() {
        // Mark that user has reviewed the app (they clicked the review button)
        hasUserReviewedApp = true
        
        // TODO: Replace YOUR_APP_ID with your actual App Store ID when available
        // For now, this will open the App Store app directly
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
    
    // For testing biometric authentication
    private func testBiometricAuth() {
        biometricAuthManager.authenticateWithDeviceOwner { success, error in
            if success {
                securityAlertMessage = "Biometric authentication successful!"
            } else {
                securityAlertMessage = "Biometric authentication failed: \(error?.localizedDescription ?? "Unknown error")"
            }
            showSecurityAlert = true
        }
    }
    
    // For testing PIN verification
    private func testPINVerification() {
        if pinManager.isPINEnabled {
            showPINVerification = true
        } else {
            securityAlertMessage = "No PIN is set. Please set up a PIN first."
            showSecurityAlert = true
        }
    }

    // MARK: - Profile Photo Upload

    func uploadProfilePhoto(image: UIImage) async {
        isUploadingPhoto = true
        errorMessage = nil

        do {
            // Get the current user
            let user = try await supabase.auth.user()

            // Check if there's an old Supabase image to delete later
            var oldImagePath: String?
            if let currentImageUrl = profile?.profileImageUrl {
                oldImagePath = extractStoragePath(from: currentImageUrl)
            }

            // Compress the image to approximately 300KB
            guard let compressedData = compressImage(image, maxSizeKB: 300) else {
                errorMessage = "Failed to compress image"
                isUploadingPhoto = false
                return
            }

            // Create a unique filename
            let fileName = "\(user.id.uuidString)/profile_\(UUID().uuidString).jpg"

            // Upload to Supabase Storage
            try await supabase.storage
                .from("profile-images")
                .upload(
                    fileName,
                    data: compressedData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )

            // Get the public URL structure (we'll use this to store in DB)
            let publicURL = try supabase.storage
                .from("profile-images")
                .getPublicURL(path: fileName)

            // Store the URL in database (will be converted to signed URL on load)
            try await supabase
                .from("profiles")
                .update(["profile_image_url": publicURL.absoluteString])
                .eq("id", value: user.id.uuidString)
                .execute()

            // Update local profile
            var updatedProfile = profile
            updatedProfile?.profileImageUrl = publicURL.absoluteString
            profile = updatedProfile

            // Delete old image from storage if it was a Supabase image
            if let oldPath = oldImagePath {
                do {
                    try await supabase.storage
                        .from("profile-images")
                        .remove(paths: [oldPath])
                } catch {
                }
            }

            // This will trigger loadProfileImage via onChange
            // which will generate a fresh signed URL

            selectedPhotoItem = nil

        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
        }

        isUploadingPhoto = false
    }

    // MARK: - Helper Functions

    /// Load the selected image from PhotosPicker
    func loadSelectedImage() async {
        guard let photoItem = selectedPhotoItem else { return }

        isLoadingImage = true

        do {
            guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                errorMessage = "Failed to load image"
                isLoadingImage = false
                return
            }

            selectedImage = image
            isLoadingImage = false
            showImageCropper = true
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
            isLoadingImage = false
        }
    }

    /// Compress image to approximately maxSizeKB
    func compressImage(_ image: UIImage, maxSizeKB: Int) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 0.9
        var imageData = image.jpegData(compressionQuality: compression)

        // Iteratively reduce quality until we're under the target size
        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }

        // If still too large, resize the image
        if let data = imageData, data.count > maxBytes {
            let ratio = sqrt(CGFloat(maxBytes) / CGFloat(data.count))
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            imageData = resizedImage?.jpegData(compressionQuality: 0.9)
        }

        return imageData
    }

    /// Extracts the storage path from a Supabase storage URL
    /// Example: "https://mkdbuzyxlvwofvgzhvpj.supabase.co/storage/v1/object/public/profile-images/user-id/file.jpg"
    /// Returns: "user-id/file.jpg"
    func extractStoragePath(from urlString: String) -> String? {
        // Check if it's a Supabase storage URL
        guard urlString.contains("supabase.co/storage/v1/object") else {
            return nil
        }

        // Extract the path after /profile-images/
        if let range = urlString.range(of: "/profile-images/") {
            let pathStart = range.upperBound
            let remainingString = String(urlString[pathStart...])

            // Remove query parameters if any
            if let queryIndex = remainingString.firstIndex(of: "?") {
                return String(remainingString[..<queryIndex])
            }

            return remainingString
        }

        return nil
    }

    /// Loads the profile image, generating a signed URL if it's a Supabase storage URL
    func loadProfileImage() async {
        guard let imageUrlString = profile?.profileImageUrl, !imageUrlString.isEmpty else {
            profileImageURL = nil
            return
        }

        // Check if it's a Supabase storage URL
        if let storagePath = extractStoragePath(from: imageUrlString) {
            // It's a Supabase URL - generate a fresh signed URL
            do {
                let signedURL = try await supabase.storage
                    .from("profile-images")
                    .createSignedURL(path: storagePath, expiresIn: 3600) // 1 hour

                profileImageURL = signedURL
            } catch {
                profileImageURL = nil
            }
        } else {
            // It's a regular public URL - use it directly
            profileImageURL = URL(string: imageUrlString)
        }
    }

    // MARK: - Account Deletion

    /// Deletes the user's account and all associated data
    func deleteAccount() async {
        isDeletingAccount = true
        errorMessage = nil

        do {
            // Get the current user
            let user = try await supabase.auth.user()

            // 1. Delete profile image from storage if it exists
            if let imageUrlString = profile?.profileImageUrl,
               let storagePath = extractStoragePath(from: imageUrlString) {
                do {
                    try await supabase.storage
                        .from("profile-images")
                        .remove(paths: [storagePath])
                } catch {
                    // Continue even if image deletion fails
                    print("Failed to delete profile image: \(error.localizedDescription)")
                }
            }

            // 2. Delete profile from database
            // Note: If you have CASCADE delete configured in your database,
            // this might automatically delete related records
            do {
                try await supabase
                    .from("profiles")
                    .delete()
                    .eq("id", value: user.id.uuidString)
                    .execute()
            } catch {
                print("Failed to delete profile: \(error.localizedDescription)")
                // Continue to delete auth account anyway
            }

            // 3. Delete user data from RevenueCat
            do {
                try await revenueCatManager.deleteUser(appUserID: user.id.uuidString)
            } catch {
                print("Failed to delete RevenueCat data: \(error.localizedDescription)")
                // Continue even if RevenueCat deletion fails
            }

            // 4. Delete the user's auth account
            // This is typically done via an admin API call or RPC function
            // as regular users cannot delete their own auth account directly.
            // You'll need to set up an RPC function in Supabase for this.
            do {
                try await supabase.rpc("delete_user").execute()
            } catch {
                print("Failed to delete auth account via RPC: \(error.localizedDescription)")
                // If RPC fails, we still sign out the user
            }

            // 5. Sign out the user
            try? await supabase.auth.signOut()
            await revenueCatManager.signOut()

            // 6. Clear local state
            profile = nil
            profileImageURL = nil

            // 7. Post notification to update the UI
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)

        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            isDeletingAccount = false
            return
        }

        isDeletingAccount = false
    }
}
