//
//  SignInWithGitHubView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/23/24.
//

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseAuth
import FirebaseFirestore

class SignInWithGitHubViewModel: NSObject, ObservableObject {
    @Published var isGitHubLoggedIn: Bool = false
    @Published var isPresented: Bool = false
    @Published var isLoading: Bool = false

    private var clientID: String
    private var clientPW: String
    private var urlScheme: String

    override init() {
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

            guard let user = Auth.auth().currentUser else {
                print("User not found after sign-in")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isPresented = false
                }
                return
            }

            let db = Firestore.firestore()
            let userRef = db.collection("users").document(user.uid)

            userRef.getDocument { document, error in
                if let error = error {
                    print("Error fetching user data: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.isPresented = false
                    }
                    return
                }

                if let document = document, document.exists {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.isGitHubLoggedIn = true
                        self.isPresented = false
                        UserDefaultsManager.shared.isSignedIn = true
                        UserDefaultsManager.shared.isGitHubLoggedIn = true
                        UserDefaultsManager.shared.githubAccessToken = accessToken
                    }
                } else {
                    self.saveUserInfoToFirestore(user: user, userData: userData, email: email)
                    DispatchQueue.main.async {
                        self.isGitHubLoggedIn = true
                        self.isPresented = false
                        UserDefaultsManager.shared.isSignedIn = true
                        UserDefaultsManager.shared.isGitHubLoggedIn = true
                        UserDefaultsManager.shared.githubAccessToken = accessToken
                    }
                }
            }
        }
    }

    private func saveUserInfoToFirestore(user: User, userData: [String: Any], email: String?) {
        let db = Firestore.firestore()

        let login = userData["login"] as? String ?? ""

        let userRef = db.collection("users").document(user.uid)
        userRef.setData([
            "uid": user.uid,
            "email": email ?? (userData["email"] as? String ?? ""),
            "displayName": login,
            "photoURL": userData["avatar_url"] as? String ?? "",
            "login-type": "GITHUB",
            "github-connection": true,
            "github-email": email ?? (userData["email"] as? String ?? ""),
        ]) { error in
            if let error = error {
                print("Error save: \(error.localizedDescription)")
            } else {
                print("success data")
            }
        }
    }
}

extension SignInWithGitHubViewModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}

struct SignInWithGitHubView: View {
    @ObservedObject var viewModel: SignInWithGitHubViewModel

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .background(Color.red.opacity(0.8))
                    .edgesIgnoringSafeArea(.all)
            } else {
                Button(action: {
                    viewModel.startGitHubSignIn()
                }) {
                    Text("Sign In with GitHub")
                }
                .padding()
                .frame(width: 240)
                .background(Color.clear)
                .foregroundColor(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1.4)
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.isPresented) {
            EmptyView()
        }
    }
}
