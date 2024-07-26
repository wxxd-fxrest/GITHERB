//
//  ContentView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct AuthContentView: View {
    @State private var isSignedIn = UserDefaultsManager.shared.isSignedIn
    @State private var isGitHubLoggedIn = UserDefaultsManager.shared.isGitHubLoggedIn
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
                        // MARK: - Github
                        Button(action: { isPresented = true }) {
                            Text("Sign In with GitHub")
                        }
                        .fullScreenCover(isPresented: $isPresented) {
                            SignInWithGitHubViewModel(isSignedIn: $isSignedIn, isGitHubLoggedIn: $isGitHubLoggedIn, isPresented: $isPresented, isLoading: $isLoading)
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
                        Button(action: { startGoogleSignIn() }) {
                            Text("Sign In with Google")
                        }
                        .padding()
                        .frame(width: 80, height: 80)
                        .background(.gray)
                        .foregroundColor(.black)
                        .cornerRadius(100)
                        
                        // MARK: - Apple
                        Button(action: {
                            // Apple logic
                        }) {
                            Text("Sign in with Apple")
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
            printUserDefaultsValues()
        }
        .onChange(of: isSignedIn) { newValue in
            UserDefaultsManager.shared.isSignedIn = newValue
        }
        .onChange(of: isGitHubLoggedIn) { newValue in
            UserDefaultsManager.shared.isGitHubLoggedIn = newValue
        }
    }
    
    private func printUserDefaultsValues() {
        print("UserDefaults - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("UserDefaults - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
        
        UserDefaultsManager.shared.clearAll()
        isSignedIn = false
        isGitHubLoggedIn = false
        
        printUserDefaultsValues()
    }
    
    private func startGoogleSignIn() {

    }
}


#Preview {
    AuthContentView()
}
