//
//  GitHubSignInViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 8/3/24.
//

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseAuth
import Combine

class GitHubSignInViewModel: ObservableObject {
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
    @Published var githubAccessToken: String?
    @Published var isLoading: Bool = false // 로딩 상태 추가

    private var authSession: ASWebAuthenticationSession?
    private let coordinator = GitHubSignInCoordinator()
    
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
    
    func startGitHubSignIn() {
        let authURL = URL(string: "https://github.com/login/oauth/authorize?client_id=\(self.clientID)&scope=user:email")!
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: urlScheme
        ) { callbackURL, error in
            if let error = error {
                print("GitHub 인증 오류: \(error.localizedDescription)")
                self.isLoading = false // 로딩 종료
                return
            }

            guard let callbackURL = callbackURL else {
                print("Callback URL == nil")
                self.isLoading = false // 로딩 종료
                return
            }

            let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
            let code = queryItems?.first(where: { $0.name == "code" })?.value

            if let code = code {
                self.exchangeCodeForToken(code: code)
            } else {
                self.isLoading = false // 로딩 종료
            }
        }

        authSession?.presentationContextProvider = coordinator
        authSession?.prefersEphemeralWebBrowserSession = true
        
        self.isLoading = true // 로딩 시작
        
        authSession?.start()
    }
    
    private func exchangeCodeForToken(code: String) {
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
                print("토큰의 코드 교환 중 오류 발생: \(String(describing: error))")
                self.isLoading = false // 로딩 종료
                return
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("Token response: \(responseString)")

            let queryItems = URLComponents(string: "?\(responseString)")?.queryItems
            let accessToken = queryItems?.first(where: { $0.name == "access_token" })?.value

            if let accessToken = accessToken {
                self.fetchGitHubUserData(accessToken: accessToken)
            } else {
                print("오류: 액세스 토큰을 받지 못함")
                self.isLoading = false // 로딩 종료
            }
        }.resume()
    }

    private func fetchGitHubUserData(accessToken: String) {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("사용자 데이터 가져오는 중 오류 발생: \(String(describing: error))")
                self.isLoading = false // 로딩 종료
                return
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("User data: \(responseString)")

            guard let userData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                self.isLoading = false // 로딩 종료
                return
            }

            self.fetchGitHubUserEmail(accessToken: accessToken) { email in
                self.signInOrLinkToFirebase(userData: userData, email: email, accessToken: accessToken)
            }
        }.resume()
    }
    
    private func fetchGitHubUserEmail(accessToken: String, completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://api.github.com/user/emails")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error \(String(describing: error))")
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
    
    private func signInOrLinkToFirebase(userData: [String: Any], email: String?, accessToken: String) {
        let credential = OAuthProvider.credential(withProviderID: "github.com", accessToken: accessToken)
        
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                print("GitHub 로그인 오류: \(error.localizedDescription)")
                self.isLoading = false // 로딩 종료
                return
            }

            guard let user = Auth.auth().currentUser else {
                print("로그인 후 사용자를 찾을 수 없음")
                self.isLoading = false // 로딩 종료
                return
            }

            let db = Firestore.firestore()
            let userRef = db.collection("users").document(user.uid)

            userRef.getDocument { document, error in
                if let error = error {
                    print("사용자 데이터를 가져오는 중 오류 발생 \(error.localizedDescription)")
                    self.isLoading = false // 로딩 종료
                    return
                }
                
                if let document = document, document.exists {
                    let loginType = document.get("login-type") as? String
                    DispatchQueue.main.async {
                        self.isSignedIn = true
                        self.isGitHubLoggedIn = loginType == "GITHUB"
                        print("loginType == GITHUB \(loginType == "GITHUB")")
                        // 키체인에 액세스 토큰 저장
                        KeychainManager.shared.save(key: "githubAccessToken", value: accessToken)
                        self.isLoading = false // 로딩 종료
                    }
                } else {
                    self.saveUserInfoToFirestore(user: user, userData: userData, email: email, accessToken: accessToken)
                }
            }
        }
    }
    
    private func saveUserInfoToFirestore(user: User, userData: [String: Any], email: String?, accessToken: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        let userInfo: [String: Any] = [
            "github-email": email ?? "",
            "github-displayName": userData["login"] as? String ?? "",
            "github-photoURL": userData["avatar_url"] as? String ?? "",
            "github-connection": true,
            "login-type" : "GITHUB"
        ]

        userRef.setData(userInfo) { error in
            if let error = error {
                print("Firestore에 사용자 정보 저장 중 오류 발생 \(error.localizedDescription)")
            } else {
                print("Firestore에 사용자 정보 저장")
                DispatchQueue.main.async {
                    self.isSignedIn = true
                    self.isGitHubLoggedIn = true
                    // 키체인에 액세스 토큰 저장
                    KeychainManager.shared.save(key: "githubAccessToken", value: accessToken)
                    self.isLoading = false // 로딩 종료
                }
            }
        }
    }
}

class GitHubSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}
