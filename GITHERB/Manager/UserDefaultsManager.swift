//
//  UserDefaultsManager.swift
//  GITHERB
//
//  Created by 밀가루 on 7/26/24.
//

import Foundation

class UserDefaultsManager {
    
    private enum Keys: String {
        case isSignedIn
        case isGitHubLoggedIn
    }
    
    static let shared = UserDefaultsManager()
    
    private init() {}
    
    // 일반 로그인 상태
    var isSignedIn: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.isSignedIn.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isSignedIn.rawValue)
        }
    }
    
    // GitHub 로그인 상태
    var isGitHubLoggedIn: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.isGitHubLoggedIn.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isGitHubLoggedIn.rawValue)
        }
    }
    
    // Clear UserDefaults - 로그아웃
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: Keys.isSignedIn.rawValue)
        UserDefaults.standard.removeObject(forKey: Keys.isGitHubLoggedIn.rawValue)
    }
    
    private func clear(_ key: Keys) {
        UserDefaults.standard.removeObject(forKey: key.rawValue)
    }
}
