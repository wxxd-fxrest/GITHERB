//
//  HomeView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/2/24.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        VStack {
            Text("GITHERB에 오신 것을 환영합니다!")
                .font(.largeTitle)
                .padding()

            if let user = Auth.auth().currentUser {
                Text("Wellcome! \(user.email ?? "User")")
                    .padding()

                Button(action: {
                    signOut()
                }) {
                    Text("Sign Out")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
            } else {
                Text("로그인한 사용자가 없습니다.")
                    .padding()
            }
        }
        .navigationTitle("Home")
    }

    private func printUserDefaultsValues() {
        print("UserDefaults - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("UserDefaults - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
        print("UserDefaults - appleUserId: \(UserDefaultsManager.shared.appleUserId ?? "nil")")
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }

        UserDefaultsManager.shared.clearAll()

        printUserDefaultsValues()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

#Preview {
    HomeView()
}
