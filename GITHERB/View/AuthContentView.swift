//
//  ContentView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import SwiftUI
import Firebase

struct AuthContentView: View {
    @State private var isSignedIn = false
    @State private var showGitHubSignIn = false

    var body: some View {
        VStack {
            if isSignedIn {
                Text("Welcome! You are signed in.")
            } else {
                VStack {
                    Button(action: {
                        // Google logic
                    }) {
                        Text("Sign in with Google")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        showGitHubSignIn = true
                    }) {
                        Text("Sign in with GitHub")
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Apple logic
                    }) {
                        Text("Sign in with Apple")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 300)
                .onAppear {
                    // Firebase 초기화
                    FirebaseApp.configure()
                }
            }
        }
        .sheet(isPresented: $showGitHubSignIn) {
            SignInWithGitHubView(isSignedIn: $isSignedIn, isPresented: $showGitHubSignIn)
        }
    }
}

#Preview {
    AuthContentView()
}
