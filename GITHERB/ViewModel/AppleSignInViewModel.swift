//
//  AppleSignInViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 8/3/24.
//

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseAuth
import FirebaseFirestore

class AppleSignInViewModel: ObservableObject {
    @Published var isSignedIn: Bool {
        didSet {
            UserDefaultsManager.shared.isSignedIn = isSignedIn
        }
    }
    @Published var isGitHubLoggedIn: Bool {
        didSet {
            UserDefaultsManager.shared.isGitHubLoggedIn = isGitHubLoggedIn
        }
    }
    @Published var showGitHubSignIn: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var isLoading: Bool = false // 로딩 상태 추가
    
    private var authSession: ASWebAuthenticationSession?
    private let coordinator = AppleSignInCoordinator()
    
    private var clientID: String
    private var clientPW: String
    private var urlScheme: String

    init() {
        if let path = Bundle.main.path(forResource: "LoginKey", ofType: "plist"),
           let dictionary = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
           let clientID = dictionary["GithubClientID"] as? String,
           let clientPW = dictionary["GithubClientPW"] as? String,
           let urlScheme = dictionary["GithubURLScheme"] as? String {
            self.clientID = clientID
            self.clientPW = clientPW
            self.urlScheme = urlScheme
            self.isSignedIn = UserDefaultsManager.shared.isSignedIn
            self.isGitHubLoggedIn = UserDefaultsManager.shared.isGitHubLoggedIn
        } else {
            fatalError("LoginKey.plist에서 ClientID, ClientPW, urlScheme 찾을 수 없음")
        }
    }

    func handleAuthorization(authResults: ASAuthorization) {
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            print("ID 토큰을 가져올 수 없음")
            return
        }
        
        // 키체인에 Apple User ID 저장
         let appleUserID = appleIDCredential.user
         KeychainManager.shared.save(key: "appleUserId", value: appleUserID)

        let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                  idToken: identityTokenString,
                                                  rawNonce: nil)

        self.isLoading = true // 로딩 시작
        
        Auth.auth().signIn(with: credential) { (authResult, error) in
            self.isLoading = false // 로딩 종료
            if let error = error {
                if let authError = error as NSError?,
                   authError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
                    print("동일한 계정 존재")
                } else {
                    print("Apple sign-in error: \(error.localizedDescription)")
                }
                return
            }

            if let user = authResult?.user {
                print("Signed in as user: \(user.uid)")
                self.checkIfUserIsLinkedWithGitHub()
            }
        }
    }

    private func checkIfUserIsLinkedWithGitHub() {
        guard let user = Auth.auth().currentUser else {
            showGitHubSignIn = true
            return
        }
        
        var isLinkedWithGitHub = false
        
        for profile in user.providerData {
            if profile.providerID == "github.com" {
                isLinkedWithGitHub = true
                break
            }
        }
        
        if isLinkedWithGitHub {
            self.isSignedIn = true
            self.isGitHubLoggedIn = true
            // 여기서 추가 작업을 할 수 있음 (예: 사용자 데이터 가져오기 등)
        } else {
            showGitHubSignIn = true
        }
    }
    
    func linkGitHubAccount() {
        let authURL = URL(string: "https://github.com/login/oauth/authorize?client_id=\(self.clientID)&scope=user:email")!
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: urlScheme
        ) { callbackURL, error in
            if let error = error {
                print("GitHub 인증 오류: \(error.localizedDescription)")
                return
            }

            guard let callbackURL = callbackURL else {
                print("Callback URL == nil")
                return
            }

            let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
            let code = queryItems?.first(where: { $0.name == "code" })?.value

            if let code = code {
                self.exchangeCodeForToken(code: code) { accessToken in
                    if let accessToken = accessToken {
                        self.linkGitHubAccountToFirebase(accessToken: accessToken)
                    }
                }
            }
        }

        authSession?.presentationContextProvider = coordinator
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }
    
    private func linkGitHubAccountToFirebase(accessToken: String) {
        let credential = OAuthProvider.credential(withProviderID: "github.com", accessToken: accessToken)

        Auth.auth().currentUser?.link(with: credential) { authResult, error in
            if let error = error {
                print("GitHub 계정 연결 오류: \(error.localizedDescription)")
                self.showAlert = true
                self.alertMessage = "GitHub 계정 연결 중 오류 발생"
                return
            }

            self.showAlert = true
            self.alertMessage = "GitHub 계정 연결 성공"
            self.showGitHubSignIn = false

            self.fetchGitHubUserData(accessToken: accessToken)
        }
    }

    func exchangeCodeForToken(code: String, completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": self.clientID,
            "client_secret": self.clientPW,
            "code": code,
            "redirect_uri": "\(urlScheme)://"
        ]
        let bodyString = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("토큰 코드 교환 중 오류 발생: \(String(describing: error))")
                completion(nil)
                return
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("Token response: \(responseString)")

            let queryItems = URLComponents(string: "?\(responseString)")?.queryItems
            let accessToken = queryItems?.first(where: { $0.name == "access_token" })?.value

            completion(accessToken)
        }.resume()
    }
    
    private func fetchGitHubUserData(accessToken: String) {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("사용자 데이터 가져오는 중 오류 발생 \(String(describing: error))")
                return
            }

            guard let userData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return
            }

            self.fetchGitHubUserEmail(accessToken: accessToken) { email in
                self.saveUserInfoToFirestore(userData: userData, email: email, accessToken: accessToken)
                DispatchQueue.main.async {
                    self.isSignedIn = true // 여기에서 로그인 상태를 true로 설정
                    self.isGitHubLoggedIn = true
                    // 키체인에 깃허브 액세스 토큰 저장
                    KeychainManager.shared.save(key: "githubAccessToken", value: accessToken)
                }
            }
        }.resume()
    }
    
    private func fetchGitHubUserEmail(accessToken: String, completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://api.github.com/user/emails")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        self.isLoading = true // 로딩 시작
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.isLoading = false // 로딩 종료
            guard let data = data, error == nil else {
                print("사용자 이메일 가져오는 중 오류 발생: \(String(describing: error))")
                completion(nil)
                return
            }

            guard let emailData = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  let primaryEmail = emailData.first(where: { $0["primary"] as? Bool == true })?["email"] as? String else {
                completion(nil)
                return
            }

            completion(primaryEmail)
        }.resume()
    }
    
    private func saveUserInfoToFirestore(userData: [String: Any], email: String?, accessToken: String) {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        let userInfo: [String: Any] = [
            "github-email": email ?? "",
            "github-displayName": userData["login"] as? String ?? "",
            "github-photoURL": userData["avatar_url"] as? String ?? "",
            "github-connection": true,
            "login-type": "APPLE"
        ]

        userRef.setData(userInfo) { error in
            if let error = error {
                print("Firestore에 사용자 정보 저장 중 오류 발생 \(error.localizedDescription)")
            } else {
                print("Firestore에 사용자 정보 저장")
            }
        }
    }
}

class AppleSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}
