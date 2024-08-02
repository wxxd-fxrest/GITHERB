//
//  GITHERBApp.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct GITHERBApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var viewModel = AppleSignInViewModel()

    var body: some View {
        Group {
            if viewModel.isSignedIn {
                HomeView()
            } else {
                VStack {
                    AppleSignInView(viewModel: viewModel)
                    GitHubSignInView()
                }
            }
        }
        .onAppear {
            printUserDefaultsValues()
        }
    }

    private func printUserDefaultsValues() {
        print("ContentView - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("ContentView - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
        print("ContentView - appleUserId: \(UserDefaultsManager.shared.appleUserId ?? "nil")")
        print("ContentView - githubAccessToken: \(UserDefaultsManager.shared.githubAccessToken ?? "nil")")
    }
}
