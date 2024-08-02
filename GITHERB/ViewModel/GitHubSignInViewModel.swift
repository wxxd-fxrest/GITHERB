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
    @Published var isSignedIn = false
    @Published var isGitHubLoggedIn = false
    @Published var githubAccessToken: String?
    
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
                return
            }

            guard let callbackURL = callbackURL else {
                print("Callback URL == nil")
                return
            }

            let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
            let code = queryItems?.first(where: { $0.name == "code" })?.value

            if let code = code {
                self.exchangeCodeForToken(code: code)
            }
        }

        authSession?.presentationContextProvider = coordinator
        authSession?.prefersEphemeralWebBrowserSession = true
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
                return
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("User data: \(responseString)")

            guard let userData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
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
                return
            }

            guard let user = Auth.auth().currentUser else {
                print("로그인 후 사용자를 찾을 수 없음")
                return
            }

            let db = Firestore.firestore()
            let userRef = db.collection("users").document(user.uid)

            userRef.getDocument { document, error in
                if let error = error {
                    print("사용자 데이터를 가져오는 중 오류 발생 \(error.localizedDescription)")
                    return
                }

                if let document = document, document.exists {
                    if let loginType = document.get("login-type") as? String {
                        DispatchQueue.main.async {
                            self.isSignedIn = true
                            self.isGitHubLoggedIn = loginType == "GITHUB"
                            self.githubAccessToken = accessToken
                        }
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
                    self.githubAccessToken = accessToken
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
