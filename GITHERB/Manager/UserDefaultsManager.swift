//
//  UserDefaultsManager.swift
//  GITHERB
//
//  Created by 밀가루 on 7/26/24.
//

import Foundation

final class KeychainManager {
    static let shared = KeychainManager()
    
    func save(key: String, value: String) -> Bool {
        let data = Data(value.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as [String: Any]
        
        // 기존 항목 삭제
        SecItemDelete(query as CFDictionary)
        
        // 새로운 항목 추가
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    func delete(key: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
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
            let value = KeychainManager.shared.load(key: Keys.appleUserId)
            print("appleUserId: \(String(describing: value))")
            return value
        }
        set {
            if let userId = newValue {
                _ = KeychainManager.shared.save(key: Keys.appleUserId, value: userId)
                print("appleUserId 저장: \(userId)")
            } else {
                _ = KeychainManager.shared.delete(key: Keys.appleUserId)
                print("appleUserId 삭제")
            }
        }
    }
    
    var githubAccessToken: String? {
        get {
            let value = KeychainManager.shared.load(key: Keys.githubAccessToken)
            print("githubAccessToken: \(String(describing: value))")
            return value
        }
        set {
            if let token = newValue {
                _ = KeychainManager.shared.save(key: Keys.githubAccessToken, value: token)
                print("githubAccessToken 값: \(token)")
            } else {
                _ = KeychainManager.shared.delete(key: Keys.githubAccessToken)
                print("githubAccessToken 삭제")
            }
        }
    }
    
    func clearAll() {
        userDefaults.removeObject(forKey: Keys.isSignedIn)
        userDefaults.removeObject(forKey: Keys.isGitHubLoggedIn)
        KeychainManager.shared.delete(key: Keys.appleUserId)
        KeychainManager.shared.delete(key: Keys.githubAccessToken)
        print("모든 사용자 기본값 삭제")
    }
}
