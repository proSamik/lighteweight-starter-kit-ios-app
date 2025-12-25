import SwiftUI
import AuthenticationServices
import Supabase
import RevenueCat

struct AuthView: View {
    @State var isSignedIn = false
    @State var user: User?
    @State var errorMessage: String?
    @State var isLoading = false
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to SwipePhotos")
                .font(.title)
                .fontWeight(.bold)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Apple Sign In Button
            SignInWithAppleButton { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task {
                    await handleAppleSignIn(result)
                }
            }
            .frame(height: 50)
            .signInWithAppleButtonStyle(.black)
            
            if isLoading {
                ProgressView()
            }
            
            if isSignedIn {
                VStack(spacing: 12) {
                    Text("Signed in!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text(user?.email ?? "User")
                        .font(.caption)
                    
                    Button(action: {
                        Task {
                            do {
                                try await supabase.auth.signOut()
                                isSignedIn = false
                                user = nil
                                errorMessage = nil
                                // Sign out from RevenueCat too
                                await revenueCatManager.signOut()
                                // Post sign-out notification
                                NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                            } catch {
                                errorMessage = "Sign out failed: \(error.localizedDescription)"
                            }
                        }
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Apple Sign In
    @MainActor
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Failed to get Apple ID credential"
                return
            }
            
            guard let idToken = credential.identityToken
                .flatMap({ String(data: $0, encoding: .utf8) })
            else {
                errorMessage = "Unable to extract identity token"
                return
            }
            
            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            
            // Profile is auto-created by database trigger, just handle post sign-in
            await handlePostSignIn()
            
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func handlePostSignIn() async {
        do {
            let currentUser = try await supabase.auth.user()
            user = currentUser
            isSignedIn = true
            errorMessage = nil
            
            // Post notification with user ID for ContentView to handle
            NotificationCenter.default.post(
                name: .userDidSignIn,
                object: currentUser.id.uuidString
            )
            
        } catch {
            errorMessage = "Failed to get user: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AuthView()
}

