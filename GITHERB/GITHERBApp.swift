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
                .edgesIgnoringSafeArea(.all) 
        }
    }
}

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var viewModel = AppleSignInViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color("AllBackground")
                    .edgesIgnoringSafeArea(.all)
                
                Group {
                    if viewModel.isSignedIn {
                        HomeView()
                    } else {
                        VStack(spacing: 114) {
                            Spacer()
                            
                            Image("GitherbMark")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 240, height: 290)
                            
                            VStack(spacing: 14) {
                                GitHubSignInView()
                                AppleSignInView(viewModel: viewModel)
                            }
                            .padding(.bottom, 110)
                        }
                    }
                }
                
                NavigationLink(
                    destination: GithubLinkView(viewModel: viewModel),
                    isActive: $viewModel.showGitHubSignIn
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func printUserDefaultsValues() {
        print("ContentView - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("ContentView - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
        print("ContentView - appleUserId: \(UserDefaultsManager.shared.appleUserId ?? "nil")")
        print("ContentView - githubAccessToken: \(UserDefaultsManager.shared.githubAccessToken ?? "nil")")
    }
}

#Preview {
    ContentView()
}
