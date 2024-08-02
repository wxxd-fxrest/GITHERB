//
//  AuthViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 8/2/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var isAppleLinked: Bool = false
    @Published var isGitHubLinked: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuthState()
    }
    
    func checkAuthState() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user {
                self.isSignedIn = true
                self.checkLinkedAccounts(for: user)
            } else {
                self.isSignedIn = false
                self.isAppleLinked = false
                self.isGitHubLinked = false
            }
        }
    }
    
    func checkLinkedAccounts(for user: User) {
        isAppleLinked = user.providerData.contains { $0.providerID == "apple.com" }
        isGitHubLinked = user.providerData.contains { $0.providerID == "github.com" }
    }
}
