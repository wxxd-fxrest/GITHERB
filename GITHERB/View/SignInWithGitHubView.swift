//
//  SignInWithGitHubView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/23/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices

struct SignInWithGitHubView: UIViewControllerRepresentable {
    private var clientID: String
    private var clientPW: String
    
    @Binding var isSignedIn: Bool
    @Binding var isPresented: Bool
    @Binding var isLoading: Bool

    init(isSignedIn: Binding<Bool>, isPresented: Binding<Bool>, isLoading: Binding<Bool>) {
        self._isSignedIn = isSignedIn
        self._isPresented = isPresented
        self._isLoading = isLoading
        
        if let path = Bundle.main.path(forResource: "LoginKey", ofType: "plist"),
           let dictionary = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
           let clientID = dictionary["GihubClientID"] as? String,
           let clientPW = dictionary["GihubClientPW"] as? String {
            self.clientID = clientID
            self.clientPW = clientPW
        } else {
            fatalError("LoginKey.plist에서 ClientID, ClientPW 찾을 수 없음")
        }
    }

    class Coordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
        var parent: SignInWithGitHubView

        init(parent: SignInWithGitHubView) {
            self.parent = parent
        }

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            return UIApplication.shared.windows.first { $0.isKeyWindow }!
        }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()

        let authSession = ASWebAuthenticationSession(
            url: URL(string: "https://github.com/login/oauth/authorize?client_id=\(self.clientID)&scope=user:email")!,
            callbackURLScheme: "myapp") { callbackURL, error in
                if let error = error {
                    print("Error during authentication: \(error.localizedDescription)")
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
        
        authSession.presentationContextProvider = context.coordinator
        authSession.prefersEphemeralWebBrowserSession = true // 풀 스크린 설정
        authSession.start()
        
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func exchangeCodeForToken(code: String) {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": self.clientID,
            "client_secret": self.clientPW,
            "code": code,
            "redirect_uri": "myapp://"
        ]
        let bodyString = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching token: \(String(describing: error))")
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

    func fetchGitHubUserData(accessToken: String) {
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

    func fetchGitHubUserEmail(accessToken: String, completion: @escaping (String?) -> Void) {
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

    func signInToFirebaseWithGitHubUserData(userData: [String: Any], email: String?, accessToken: String) {
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
                self.saveUserInfoToFirestore(user: user, userData: userData, email: email)
            }

            DispatchQueue.main.async {
                self.isSignedIn = true
                self.isLoading = false
                self.isPresented = false
            }
        }
    }

    func saveUserInfoToFirestore(user: User, userData: [String: Any], email: String?) {
        let db = Firestore.firestore()

        let login = userData["login"] as? String ?? ""
        
        let userRef = db.collection("users").document(user.uid)
        userRef.setData([
            "uid": user.uid,
            "email": email ?? (userData["email"] as? String ?? ""),
            "displayName": login,
            "photoURL": userData["avatar_url"] as? String ?? ""
        ]) { error in
            if let error = error {
                print("Error save: \(error.localizedDescription)")
            } else {
                print("success data")
            }
        }
    }
}
