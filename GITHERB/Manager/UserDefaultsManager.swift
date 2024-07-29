//
//  UserDefaultsManager.swift
//  GITHERB
//
//  Created by 밀가루 on 7/26/24.
//

import Foundation

final class KeychainManager {
    static let shared = KeychainManager()
    
    func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as [String: Any]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func load(key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }
    
    func delete(key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
    }
}

final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let isSignedIn = "isSignedIn"
        static let isGitHubLoggedIn = "isGitHubLoggedIn"
        static let appleUserId = "appleUserId"
        static let githubAccessToken = "githubAccessToken"
    }
    
    var isSignedIn: Bool {
        get {
            let value = userDefaults.bool(forKey: Keys.isSignedIn)
            print("isSignedIn: \(value)")
            return value
        }
        set {
            userDefaults.set(newValue, forKey: Keys.isSignedIn)
            print("isSignedIn: \(newValue)")
        }
    }
    
    var isGitHubLoggedIn: Bool {
        get {
            let value = userDefaults.bool(forKey: Keys.isGitHubLoggedIn)
            print("isGitHubLoggedIn: \(value)")
            return value
        }
        set {
            userDefaults.set(newValue, forKey: Keys.isGitHubLoggedIn)
            print("isGitHubLoggedIn: \(newValue)")
        }
    }
    
    var appleUserId: String? {
        get {
            let value = userDefaults.string(forKey: Keys.appleUserId)
            print("appleUserId: \(String(describing: value))")
            return value
        }
        set {
            userDefaults.set(newValue, forKey: Keys.appleUserId)
            print("appleUserId: \(String(describing: newValue))")
        }
    }
    
    func clearAll() {
        userDefaults.removeObject(forKey: Keys.isSignedIn)
        userDefaults.removeObject(forKey: Keys.isGitHubLoggedIn)
        userDefaults.removeObject(forKey: Keys.appleUserId)
        KeychainManager.shared.delete(key: Keys.githubAccessToken)
        print("모든 사용자 기본값 삭제")
    }
    
    var githubAccessToken: String? {
        get {
            let value = KeychainManager.shared.load(key: Keys.githubAccessToken)
            print("githubAccessToken: \(String(describing: value))")
            return value
        }
        set {
            if let token = newValue {
                KeychainManager.shared.save(key: Keys.githubAccessToken, value: token)
                print("githubAccessToken 값: \(token)")
            } else {
                KeychainManager.shared.delete(key: Keys.githubAccessToken)
                print("githubAccessToken 삭제")
            }
        }
    }
}
