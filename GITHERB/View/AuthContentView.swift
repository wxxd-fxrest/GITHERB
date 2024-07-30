//
//  ContentView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

struct AuthContentView: View {
    @StateObject private var googleSignInVM = SignInWithGoogleViewModel()
    @StateObject private var appleSignInVM = SignInWithAppleViewModel()
    @StateObject private var gitHubSignInVM = SignInWithGitHubViewModel()
    @StateObject private var socialLogInVM = SocialGithubLoginViewModel()

    @AppStorage("isSignedIn") private var isSignedIn: Bool = UserDefaultsManager.shared.isSignedIn
    @AppStorage("isGitHubLoggedIn") private var isGitHubLoggedIn: Bool = UserDefaultsManager.shared.isGitHubLoggedIn

    @State private var isLoading = false

    var body: some View {
        VStack {
            if isSignedIn {
                Text("Signed In!")
                if isGitHubLoggedIn {
                    Text("GitHub Logged In!")
                } else {
                    Text("Please complete GitHub sign-in.")
                    
                    SocialGithubLoginView(viewModel: socialLogInVM)
                        .padding(.top, 300)
                }
                
                Button(action: logout) {
                    Text("Logout")
                        .foregroundColor(.red)
                }
            } else {
                VStack(spacing: 24) {
                    SignInWithGitHubView(viewModel: gitHubSignInVM)
                        .padding(.top, 300)
                    
                    HStack(spacing: 40) {
                        // Google Sign-In
                        Button(action: { googleSignInVM.signIn() }) {
                            Text("Sign In with Google")
                        }
                        .padding()
                        .frame(width: 80, height: 80)
                        .background(.gray)
                        .foregroundColor(.black)
                        .cornerRadius(100)
                        
                        // Apple Sign-In
                        Button(action: {
                            appleSignInVM.startSignInWithAppleFlow()
                        }) {
                            Text("Sign In with Apple")
                                .padding()
                                .frame(width: 80, height: 80)
                                .background(.black)
                                .foregroundColor(.white)
                                .cornerRadius(100)
                        }
                    }
                }
            }
        }
        .onAppear {
            checkLoginStatus()
        }
        .onReceive(googleSignInVM.$isSignedIn) { newValue in
            isSignedIn = newValue
        }
        .onReceive(appleSignInVM.$isSignedIn) { newValue in
            isSignedIn = newValue
        }
        .onReceive(gitHubSignInVM.$isGitHubLoggedIn) { newValue in
            isGitHubLoggedIn = newValue
        }
    }

    private func checkLoginStatus() {
        googleSignInVM.checkAutoLogin()
        appleSignInVM.checkAutoLogin()
        checkGitHubAutoLogin()
        printUserDefaultsValues()
    }
    
    private func checkGitHubAutoLogin() {
        if let accessToken = UserDefaultsManager.shared.githubAccessToken {
            let credential = OAuthProvider.credential(withProviderID: "github.com", accessToken: accessToken)
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Error GitHub token: \(error.localizedDescription)")
                    UserDefaultsManager.shared.githubAccessToken = nil
                    UserDefaultsManager.shared.isSignedIn = false
                    UserDefaultsManager.shared.isGitHubLoggedIn = false
                    return
                }
                // Successful login
                UserDefaultsManager.shared.isSignedIn = true
                UserDefaultsManager.shared.isGitHubLoggedIn = true
                printUserDefaultsValues()
            }
        } else {
            print("No GitHub token found")
        }
    }
    
    private func printUserDefaultsValues() {
        print("UserDefaults - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("UserDefaults - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
        print("UserDefaults - appleUserId: \(UserDefaultsManager.shared.appleUserId ?? "nil")")
    }
    
    private func logout() {
        // Firebase sign out
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }

        // Google sign out
        GIDSignIn.sharedInstance.signOut()

        // Clear UserDefaults
        UserDefaultsManager.shared.clearAll()
        isSignedIn = false
        isGitHubLoggedIn = false

        // Print UserDefaults
        printUserDefaultsValues()
    }
}
