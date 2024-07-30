//
//  SignInWithAppleViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 7/27/24.
//

import SwiftUI
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

class SignInWithAppleViewModel: NSObject, ObservableObject {
    @Published var isSignedIn: Bool = UserDefaultsManager.shared.isSignedIn
    @Published var isGitHubLoggedIn: Bool = false
    
    private var currentNonce: String?

    override init() {
        super.init()
        checkAutoLogin()
    }

    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Nonce를 생성할 수 없음, OSStatus로 인해 SecRandomCopyBytes 실패 \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    func checkAutoLogin() {
        guard let userId = UserDefaultsManager.shared.appleUserId else {
            UserDefaultsManager.shared.isSignedIn = false
            self.isSignedIn = false
            self.objectWillChange.send()
            return
        }
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: userId) { (credentialState, error) in
            DispatchQueue.main.async {
                switch credentialState {
                case .authorized:
                    UserDefaultsManager.shared.isSignedIn = true
                    self.isSignedIn = true
                case .revoked, .notFound:
                    UserDefaultsManager.shared.isSignedIn = false
                    self.isSignedIn = false
                default:
                    UserDefaultsManager.shared.isSignedIn = false
                    self.isSignedIn = false
                }
                self.objectWillChange.send()
            }
        }
    }

    private func saveUserInfoToFirestore(user: User, appleIDCredential: ASAuthorizationAppleIDCredential) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { [weak self] (document, error) in
            if let document = document, document.exists {
                self?.checkGitHubLoginStatus(userRef: userRef)
            } else {
                userRef.setData([
                    "uid": user.uid,
                    "login-type": "APPLE",
                ]) { error in
                    if let error = error {
                        print("Firestore에 사용자 정보를 저장하는 중 오류 발생: \(error.localizedDescription)")
                    } else {
                        print("Firestore에 사용자 정보를 성공적으로 저장했습니다.")
                        self?.checkGitHubLoginStatus(userRef: userRef)
                    }
                }
            }
        }
    }

    private func checkGitHubLoginStatus(userRef: DocumentReference) {
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                if let data = document.data(), data["github-email"] as? String != nil {
                    DispatchQueue.main.async {
                        self?.isGitHubLoggedIn = true
                        UserDefaultsManager.shared.isGitHubLoggedIn = true
                    }
                    print("GitHub 로그인되어 있음")
                } else {
                    DispatchQueue.main.async {
                        self?.isGitHubLoggedIn = false
                        UserDefaultsManager.shared.isGitHubLoggedIn = false
                    }
                    print("GitHub에 로그인되어 있지 않음")
                }
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            } else {
                print("Document X")
            }
        }
    }
}

extension SignInWithAppleViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("잘못된 상태: 로그인 콜백이 수신되었지만 로그인 요청이 전송되지 않음")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("ID 토큰을 가져올 수 없음")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("데이터에서 토큰 문자열을 직렬화할 수 없음: \(appleIDToken.debugDescription)")
                return
            }

            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
            Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
                if let error = error {
                    print("Apple 로그인하는 중에 오류 발생: \(error.localizedDescription)")
                    return
                }
                
                guard let user = authResult?.user else {
                    print("사용자 정보가 없음")
                    return
                }
                
                self?.saveUserInfoToFirestore(user: user, appleIDCredential: appleIDCredential)
                
                UserDefaultsManager.shared.appleUserId = appleIDCredential.user
                UserDefaultsManager.shared.isSignedIn = true
                self?.isSignedIn = true
                self?.objectWillChange.send()
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple 로그인 오류 발생: \(error)")
    }
}

extension SignInWithAppleViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}
