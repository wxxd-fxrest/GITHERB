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
    @StateObject private var appleLoginVM = AppleSignInViewModel()
    @StateObject private var githubLoginVM = GitHubSignInViewModel()
    
    @State private var isSignedIn: Bool = false
    @State private var isGitHubLoggedIn: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color("AllBackground")
                    .edgesIgnoringSafeArea(.all)
                
                if appleLoginVM.isLoading || githubLoginVM.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1) // 로딩바 크기 조절
                } else {
                    Group {
                        if UserDefaultsManager.shared.isSignedIn && UserDefaultsManager.shared.isGitHubLoggedIn {
                            MainContentView(data: exampleYearData)
                        } else {
                            VStack(spacing: 114) {
                                Spacer()
                                
                                Image("GitherbMark")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 240, height: 290)
                                
                                VStack(spacing: 14) {
                                    GitHubSignInView(viewModel: githubLoginVM)
                                    AppleSignInView(viewModel: appleLoginVM)
                                }
                                .padding(.bottom, 110)
                            }
                        }
                    }
                    NavigationLink(
                        destination: GithubLinkView(viewModel: appleLoginVM),
                        isActive: $appleLoginVM.showGitHubSignIn
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                checkLoginStatus()
            }
        }
    }
    
    private func checkLoginStatus() {
         isSignedIn = Auth.auth().currentUser != nil
         
         isSignedIn = UserDefaultsManager.shared.isSignedIn
         isGitHubLoggedIn = UserDefaultsManager.shared.isGitHubLoggedIn
        
        printUserDefaultsValues()
     }

    private func printUserDefaultsValues() {
        print("ContentView - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("ContentView - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
        if let value = KeychainManager.shared.load(key: "appleUserId") {
            print("ContentView - appleUserId: \(value)")
        } else {
            print("ContentView - appleUserId == nil")
        }
        if let value = KeychainManager.shared.load(key: "githubAccessToken") {
            print("ContentView - githubAccessToken: \(value)")
        } else {
            print("ContentView - githubAccessToken == nil")
        }
    }
}

#Preview {
    ContentView()
}
