//
//  SocialGithubLoginViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 7/30/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices

class SocialGithubLoginViewModel: NSObject, ObservableObject {
    @Published var userInfo: [String: Any] = [:]
    @Published var userId: String?
    @Published var isGitHubLoggedIn: Bool = false
    @Published var isPresented: Bool = false
    @Published var isLoading: Bool = false
    
    private var clientID: String
    private var clientPW: String
    private var urlScheme: String
    
    private var accessToken: String?
    private var documentID: String?

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
        
        super.init()
        fetchUserData()
    }

    func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            print("로그인된 사용자가 없음")
            return
        }
        
        userId = user.uid
        fetchUserDataFromFirestore(userID: user.uid)
        
        if let githubAccessToken = UserDefaultsManager.shared.githubAccessToken {
            fetchGitHubUserData(accessToken: githubAccessToken)
        }
    }
    
    private func fetchUserDataFromFirestore(userID: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)
        
        userRef.getDocument { [weak self] (document, error) in
            if let document = document, document.exists {
                self?.documentID = document.documentID
                if let data = document.data() {
                    DispatchQueue.main.async {
                        self?.userInfo = data
                    }
                }
            } else {
                print("문서가 존재하지 않거나 오류 발생")
            }
        }
    }
    
    private func fetchGitHubUserData(accessToken: String) {
        let userURL = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: userURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("GitHub 사용자 데이터를 가져오는 중 오류 발생: \(String(describing: error))")
                return
            }
            
            guard let userData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("GitHub 사용자 데이터를 구문 분석하는 중 오류 발생")
                return
            }
            
            DispatchQueue.main.async {
                self?.fetchGitHubUserEmails(accessToken: accessToken, userData: userData)
            }
        }.resume()
    }
    
    private func fetchGitHubUserEmails(accessToken: String, userData: [String: Any]) {
        let emailsURL = URL(string: "https://api.github.com/user/emails")!
        var request = URLRequest(url: emailsURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("GitHub 사용자 이메일을 가져오는 중 오류 발생: \(String(describing: error))")
                return
            }
            
            guard let emailsData = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("GitHub 사용자 이메일 데이터 확인 중 오류 발생")
                return
            }
            
            // 이메일 데이터에서 첫 번째 이메일을 선택 (첫 번째 이메일을 기본으로 선택)
            let email = emailsData.first?["email"] as? String ?? ""
            
            // GitHub 사용자 데이터 업데이트
            var updatedUserData = userData
            updatedUserData["email"] = email
            
            DispatchQueue.main.async {
                self?.updateFirestoreWithGitHubData(userData: updatedUserData)
            }
        }.resume()
    }
    
    func fetchGitHubUserDataIfNeeded() {
        guard let accessToken = UserDefaultsManager.shared.githubAccessToken else {
            return
        }

        fetchGitHubUserData(accessToken: accessToken)
    }
    
    private func updateFirestoreWithGitHubData(userData: [String: Any]) {
        guard let documentID = documentID else {
            print("Document ID X.")
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(documentID)

        // 디버깅을 위해 userData 출력
        print("User Data: \(userData)")

        // Firestore에 데이터 업데이트
        userRef.updateData([
            "displayName": userData["login"] as? String ?? "",
            "photoURL": userData["avatar_url"] as? String ?? "",
            "github-connection": true,
            "github-email": userData["email"] as? String ?? ""
        ]) { error in
            if let error = error {
                print("Error updating Firestore with GitHub data: \(error.localizedDescription)")
            } else {
                // 업데이트 성공 시, local userInfo 업데이트
                self.userInfo["githubLogin"] = userData["login"]
                self.userInfo["githubEmail"] = userData["email"]
                self.userInfo["githubAvatarURL"] = userData["avatar_url"]
            }
        }

        // Firestore에서 데이터 가져오기 (이메일 업데이트 확인용)
        userRef.getDocument { document, error in
            if let error = error {
                print("사용자 데이터를 가져오는 중 오류 발생: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isPresented = false
                }
                return
            }

            if let document = document, document.exists {
                // 데이터가 존재하면 상태 업데이트
                print("Firestore: 사용자 데이터 존재")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isGitHubLoggedIn = true
                    self.isPresented = false
                    UserDefaultsManager.shared.isSignedIn = true
                    UserDefaultsManager.shared.isGitHubLoggedIn = true
                    UserDefaultsManager.shared.githubAccessToken = self.accessToken
                }
            } else {
                // 데이터가 존재하지 않으면 상태 업데이트
                DispatchQueue.main.async {
                    self.isGitHubLoggedIn = true
                    self.isPresented = false
                    UserDefaultsManager.shared.isSignedIn = true
                    UserDefaultsManager.shared.isGitHubLoggedIn = true
                    UserDefaultsManager.shared.githubAccessToken = self.accessToken
                }
            }
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
        authSession.prefersEphemeralWebBrowserSession = true // Use ephemeral web browser session
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

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("토큰을 가져오는 중 오류 발생: \(String(describing: error))")
                DispatchQueue.main.async {
                    self?.isPresented = false
                }
                return
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("Token response: \(responseString)")

            let queryItems = URLComponents(string: "?\(responseString)")?.queryItems
            let accessToken = queryItems?.first(where: { $0.name == "access_token" })?.value

            if let accessToken = accessToken {
                self?.accessToken = accessToken // Save the access token here
                self?.fetchGitHubUserData(accessToken: accessToken)
            } else {
                print("액세스 토큰을 검색하는 중 오류 발생")
                DispatchQueue.main.async {
                    self?.isPresented = false
                }
            }
        }.resume()
    }
}

extension SocialGithubLoginViewModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}

struct SocialGithubLoginView: View {
    @ObservedObject var viewModel: SocialGithubLoginViewModel

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
            Text("GitHub Sign-In Completed")
        }
    }
}
