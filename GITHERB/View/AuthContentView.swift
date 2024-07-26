//
//  ContentView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import SwiftUI

struct AuthContentView: View {
    @State private var isSignedIn = false
    @State private var isPresented = false
    @State private var isLoading: Bool = false

    var body: some View {
        VStack {
            if isSignedIn {
                Text("Signed In!")
            } else {
                Button(action: {
                    isPresented = true
                }) {
                    Text("Sign In with GitHub")
                }
                .fullScreenCover(isPresented: $isPresented) {
                    SignInWithGitHubView(isSignedIn: $isSignedIn, isPresented: $isPresented, isLoading: $isLoading)
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
            }
        }
    }
}

#Preview {
    AuthContentView()
}
