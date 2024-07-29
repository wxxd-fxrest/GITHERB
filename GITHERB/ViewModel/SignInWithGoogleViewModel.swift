//
//  SignInWithGoogleViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 7/27/24.
//

import SwiftUI
import Foundation
import GoogleSignIn
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

class SignInWithGoogleViewModel: ObservableObject {
    private let firestore = Firestore.firestore()
    @Published var isSignedIn: Bool = UserDefaultsManager.shared.isSignedIn

    init() {
        checkAutoLogin()
    }

    func signIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Error: Firebase 클라이언트 ID 못 찾음")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let rootVC = getRootViewController() else {
            print("Error: Root view controller 없음")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Google 로그인 중 오류: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("ID 토큰을 가져오는 중에 오류 발생")
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Google 로그인하는 중에 오류 발생: \(error.localizedDescription)")
                    return
                }
                
                // 사용자가 Firebase에 로그인되어 있음
                self.isSignedIn = true
                UserDefaultsManager.shared.isSignedIn = true
                
                // Firestore에 사용자 정보 저장
                self.storeUserData()
            }
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.windows.first?.rootViewController
        }
        return nil
    }

    private func storeUserData() {
        guard let user = Auth.auth().currentUser else {
            print("오류: 현재 사용자를 찾을 수 없음")
            return
        }
        
        let userRef = firestore.collection("users").document(user.uid)
        
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "login-type": "GOOGLE",
            "github-connection": false,
            "github-email": "",
        ]
        
        userRef.setData(userData) { error in
            if let error = error {
                print("사용자 데이터를 저장하는 중에 오류 발생: \(error.localizedDescription)")
            } else {
                print("사용자 데이터 성공적으로 저장")
            }
        }
    }

    func checkAutoLogin() {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("이전 로그인을 복원하는 중에 오류 발생: \(error.localizedDescription)")
                    return
                }
                
                guard let user = user, let idToken = user.idToken?.tokenString else {
                    print("ID 토큰을 가져오는 중에 오류 발생")
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                               accessToken: user.accessToken.tokenString)
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        print("Google로 로그인하는 중에 오류 발생: \(error.localizedDescription)")
                        return
                    }
                    
                    self.isSignedIn = true
                    UserDefaultsManager.shared.isSignedIn = true
                    
                    self.storeUserData()
                }
            }
        } else {
            self.isSignedIn = false
            UserDefaultsManager.shared.isSignedIn = false
        }
    }
}
