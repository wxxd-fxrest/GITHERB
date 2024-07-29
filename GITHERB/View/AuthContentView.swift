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

    @AppStorage("isSignedIn") private var isSignedIn = UserDefaultsManager.shared.isSignedIn
    @AppStorage("isGitHubLoggedIn") private var isGitHubLoggedIn = UserDefaultsManager.shared.isGitHubLoggedIn

    @State private var isPresented = false
    @State private var isLoading = false

    var body: some View {
        VStack {
            if isSignedIn {
                Text("Signed In!")
                if isGitHubLoggedIn {
                    Text("GitHub Logged In!")
                }
                
                Button(action: logout) {
                    Text("Logout")
                        .foregroundColor(.red)
                }
            } else {
                VStack(spacing: 24) {
                    VStack {
                        // MARK: - GitHub
                        Button(action: { isPresented = true }) {
                            Text("Sign In with GitHub")
                        }
                        .fullScreenCover(isPresented: $isPresented) {
                            SignInWithGitHubViewModel(
                                isGitHubLoggedIn: $isGitHubLoggedIn,
                                isPresented: $isPresented,
                                isLoading: $isLoading
                            )
                                .overlay(
                                    Group {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .background(Color.red.opacity(0.8))
                                                .edgesIgnoringSafeArea(.all)
                                        }
                                    }
                                )
                        }
                        .padding()
                        .frame(width: 240)
                        .background(.clear)
                        .foregroundColor(.black)
                        .overlay(
                             RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1.4)
                         )
                    }
                    .padding(.top, 300)
                    
                    HStack(spacing: 40) {
                        // MARK: - Google
                        Button(action: { googleSignInVM.signIn() }) {
                            Text("Sign In Google")
                        }
                        .padding()
                        .frame(width: 80, height: 80)
                        .background(.gray)
                        .foregroundColor(.black)
                        .cornerRadius(100)
                        
                        // MARK: - Apple
                        Button(action: {
                            appleSignInVM.startSignInWithAppleFlow()
                        }) {
                            Text("Sign in Apple")
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
    }

    private func checkLoginStatus() {
        googleSignInVM.checkAutoLogin()
        appleSignInVM.checkAutoLogin()
        checkGitHubAutoLogin()
        printUserDefaultsValues()
    }
    
    // 깃허브 로그인 ViewModel로 이동 시켜야 함
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
                // 로그인 성공
                UserDefaultsManager.shared.isSignedIn = true
                UserDefaultsManager.shared.isGitHubLoggedIn = true
                printUserDefaultsValues()
            }
        } else {
            print("GitHub 토큰 없음")
        }
    }
    
    private func printUserDefaultsValues() {
        print("UserDefaults - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("UserDefaults - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
        print("UserDefaults - appleUserId: \(UserDefaultsManager.shared.appleUserId ?? "nil")")
    }
    
    private func logout() {
        // Firebase logout
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }

        // Google logout
        GIDSignIn.sharedInstance.signOut()

        // UserDefaults reset
        UserDefaultsManager.shared.clearAll()
        isSignedIn = false
        isGitHubLoggedIn = false

        // Print UserDefaults
        printUserDefaultsValues()
    }
}
