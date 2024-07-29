//
//  SocialGithubLoginViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 7/29/24.
//

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseAuth
import FirebaseFirestore

class SocialGithubLoginViewModel: NSObject, ObservableObject {
    @Published var isGitHubLoggedIn: Bool = false
    @Published var isPresented: Bool = false
    @Published var isLoading: Bool = false

    private var clientID: String
    private var clientPW: String
    private var urlScheme: String

    override init() {
        if let path = Bundle.main.path(forResource: "LoginKey", ofType: "plist"),
           let dictionary = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
           let clientID = dictionary["GihubClientID"] as? String,
           let clientPW = dictionary["GihubClientPW"] as? String,
           let urlScheme = dictionary["GithubURLScheme"] as? String {
            self.clientID = clientID
            self.clientPW = clientPW
            self.urlScheme = urlScheme
        } else {
            fatalError("LoginKey.plist에서 ClientID, ClientPW, urlScheme 찾을 수 없음")
        }
    }

    func startGitHubSignIn() {
        let authSession = ASWebAuthenticationSession(
            url: URL(string: "https://github.com/login/oauth/authorize?client_id=\(self.clientID)&scope=user:email")!,
            callbackURLScheme: urlScheme) { callbackURL, error in
                if let error = error {
                    print("인증 중 오류 발생: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isPresented = false
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    DispatchQueue.main.async {
                        self.isPresented = false
                    }
                    return
                }

                let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
                let code = queryItems?.first(where: { $0.name == "code" })?.value

                if let code = code {
                    self.exchangeCodeForToken(code: code)
                }
            }

        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = true // 풀 스크린 설정
        authSession.start()
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
                print("토큰을 가져오는 중 오류 발생: \(String(describing: error))")
                DispatchQueue.main.async {
                    self.isPresented = false
                }
                return
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("Token response: \(responseString)")

            let queryItems = URLComponents(string: "?\(responseString)")?.queryItems
            let accessToken = queryItems?.first(where: { $0.name == "access_token" })?.value

            if let accessToken = accessToken {
                self.fetchGitHubUserData(accessToken: accessToken)
            } else {
                print("Error token")
                DispatchQueue.main.async {
                    self.isPresented = false
                }
            }
        }.resume()
    }

    private func fetchGitHubUserData(accessToken: String) {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error user data - 1: \(String(describing: error))")
                DispatchQueue.main.async {
                    self.isPresented = false
                }
                return
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("User data: \(responseString)")

            guard let userData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("Error user data - 2")
                DispatchQueue.main.async {
                    self.isPresented = false
                }
                return
            }

            self.fetchGitHubUserEmail(accessToken: accessToken) { email in
                self.signInToFirebaseWithGitHubUserData(userData: userData, email: email, accessToken: accessToken)
            }
        }.resume()
    }

    private func fetchGitHubUserEmail(accessToken: String, completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://api.github.com/user/emails")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error user emails: \(String(describing: error))")
                completion(nil)
                return
            }

            guard let emailData = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  let primaryEmail = emailData.first(where: { $0["primary"] as? Bool == true })?["email"] as? String else {
                print("Error user emails")
                completion(nil)
                return
            }

            completion(primaryEmail)
        }.resume()
    }

    private func signInToFirebaseWithGitHubUserData(userData: [String: Any], email: String?, accessToken: String) {
        DispatchQueue.main.async {
            self.isLoading = true
        }

        let credential = OAuthProvider.credential(withProviderID: "github.com", accessToken: accessToken)
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                print("Error GitHub Signup: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isPresented = false
                }
                return
            }

            if let user = Auth.auth().currentUser {
                print("깃허브 로그인?")
            }
            print("깃허브 로그인 완료")

            DispatchQueue.main.async {
                print("깃허브 로그인 완료1")
                self.isLoading = false
                self.isGitHubLoggedIn = true
                self.isPresented = false
                UserDefaultsManager.shared.isSignedIn = true
                UserDefaultsManager.shared.isGitHubLoggedIn = true
                UserDefaultsManager.shared.githubAccessToken = accessToken
                print("UserDefaults - isSignedIn (after GitHub login): \(UserDefaultsManager.shared.isSignedIn)")
                print("UserDefaults - isGitHubLoggedIn (after GitHub login): \(UserDefaultsManager.shared.isGitHubLoggedIn)")
            }
        }
    }
}

extension SocialGithubLoginViewModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}
