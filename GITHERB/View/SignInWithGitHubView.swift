//
//  SignInWithGitHubView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/23/24.
//

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseFirestore

// SignInWithGitHubView 구조체는 UIViewControllerRepresentable을 채택하여
// GitHub 로그인 화면을 표시하고 OAuth 인증을 처리합니다.
struct SignInWithGitHubView: UIViewControllerRepresentable {
    @Binding var isSignedIn: Bool  // 로그인 상태를 나타내는 바인딩 변수
    @Binding var isPresented: Bool  // 시트를 표시하거나 숨길 때 사용하는 바인딩 변수

    // Coordinator 클래스는 ASWebAuthenticationSession의 프레젠테이션 컨텍스트를 제공
    class Coordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
        var parent: SignInWithGitHubView  // 부모 뷰를 참조하기 위한 변수

        init(parent: SignInWithGitHubView) {
            self.parent = parent
        }

        // 로그인 세션을 표시할 윈도우를 제공하는 메서드
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            return UIApplication.shared.windows.first { $0.isKeyWindow }!  // 현재 키 윈도우를 반환
        }
    }

    // MARK: UIViewController를 생성하고 GitHub 인증 세션을 시작하는 메서드
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()  // 빈 UIViewController 생성
        let authSession = ASWebAuthenticationSession(
            url: URL(string: "https://github.com/login/oauth/authorize?client_id=YOUR_CLIENT_ID&scope=read:user")!,
            callbackURLScheme: "your.bundle.id") { callbackURL, error in
                // 인증 과정에서 오류가 발생한 경우
                if let error = error {
                    print("Error authentication: \(error.localizedDescription)")  // 오류 메시지 출력
                    DispatchQueue.main.async {
                        self.isPresented = false  // 시트 닫기
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    // callbackURL이 nil인 경우
                    DispatchQueue.main.async {
                        self.isPresented = false  // 시트 닫기
                    }
                    return
                }

                // callbackURL에서 인증 코드를 추출
                let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
                let code = queryItems?.first(where: { $0.name == "code" })?.value

                // 인증 코드가 있는 경우
                if let code = code {
                    self.exchangeCodeForToken(code: code)  // 인증 코드로 토큰을 교환
                }
            }
        authSession.presentationContextProvider = context.coordinator  // 프레젠테이션 컨텍스트 설정
        authSession.start()  // 인증 세션 시작
        return vc  // UIViewController 반환
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    // SwiftUI의 UIViewControllerRepresentable을 사용하여 UIKit의 UIViewController를 SwiftUI 뷰 계층에 통합할 때 사용

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)  // Coordinator 인스턴스 생성
    }

    // MARK: 인증 코드로 액세스 토큰을 교환하는 메서드
    func exchangeCodeForToken(code: String) {
        let url = URL(string: "https://github.com/login/oauth/access_token")!  // 액세스 토큰 교환 URL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"  // HTTP 메서드 POST 설정
        request.setValue("application/json", forHTTPHeaderField: "Accept")  // 헤더 설정

        // 요청 본문에 클라이언트 ID, 클라이언트 비밀, 인증 코드 포함
        let body: [String: String] = [
            "client_id": "YOUR_CLIENT_ID",
            "client_secret": "YOUR_CLIENT_SECRET",
            "code": code
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])  // 본문 데이터로 변환

        URLSession.shared.dataTask(with: request) { data, response, error in
            // 요청 처리 중 오류 발생 시
            guard let data = data, error == nil else {
                print("Error token: \(String(describing: error))")  // 오류 메시지 출력
                DispatchQueue.main.async {
                    self.isPresented = false  // 시트 닫기
                }
                return
            }

            // 응답 데이터에서 액세스 토큰 추출
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                self.signInToFirebaseWithAccessToken(accessToken)  // 액세스 토큰으로 Firebase 로그인
            }
        }.resume()  // 데이터 작업 시작
    }

    // MARK: 액세스 토큰으로 Firebase 인증을 수행하는 메서드
    func signInToFirebaseWithAccessToken(_ accessToken: String) {
        let credential = OAuthProvider.credential(withProviderID: "github.com", accessToken: accessToken)  // GitHub OAuth 자격 증명 생성
        Auth.auth().signIn(with: credential) { authResult, error in
            // 로그인 중 오류 발생 시
            if let error = error {
                print("github sign in error: \(error)")  // 오류 메시지 출력
                DispatchQueue.main.async {
                    self.isPresented = false  // 시트 닫기
                }
                return
            }
            
            // 로그인 성공 시 현재 사용자 정보 저장 및 출력
            if let user = Auth.auth().currentUser {
                self.saveUserInfoToFirestore(user: user)  // Firestore에 사용자 정보 저장
                self.printUserInfo(user: user)  // 사용자 정보 출력
            }
            
            DispatchQueue.main.async {
                self.isSignedIn = true  // 로그인 상태 업데이트
                self.isPresented = false  // 시트 닫기
            }
        }
    }
    
    // MARK: Firestore에 사용자 정보 저장
    func saveUserInfoToFirestore(user: User) {
        let db = Firestore.firestore()  // Firestore 인스턴스 생성
        
        let userRef = db.collection("users").document(user.uid)  // 사용자 문서 참조
        
        userRef.setData([
            "uid": user.uid,  // 사용자 ID
            "email": user.email ?? "",  // 사용자 이메일
            "displayName": user.displayName ?? "",  // 사용자 디스플레이 이름
            "photoURL": user.photoURL?.absoluteString ?? ""  // 사용자 사진 URL
        ]) { error in
            // 데이터 저장 중 오류 발생 시
            if let error = error {
                print("Error Firestore: \(error)")  // 오류 메시지 출력
            } else {
                print("success Firestore")  // 성공 메시지 출력
            }
        }
    }
    
    // MARK: 사용자 정보 출력
    func printUserInfo(user: User) {
        print("User ID: \(user.uid)")  // 사용자 ID 출력
        print("User Email: \(user.email ?? "No email")")  // 사용자 이메일 출력
        print("User Display Name: \(user.displayName ?? "No display name")")  // 사용자 디스플레이 이름 출력
        print("User Photo URL: \(user.photoURL?.absoluteString ?? "No photo URL")")  // 사용자 사진 URL 출력
    }
}

// 요약
// SignInWithGitHubView: GitHub 로그인 인증을 처리하는 구조체. UIViewControllerRepresentable을 채택하여 ASWebAuthenticationSession을 사용하여 GitHub 로그인 화면을 표시
// Coordinator: ASWebAuthenticationSession의 프레젠테이션 컨텍스트를 제공하는 클래스
// makeUIViewController: ASWebAuthenticationSession을 사용하여 GitHub 로그인 시작
// exchangeCodeForToken: 인증 코드로 GitHub에서 액세스 토큰 교환
// signInToFirebaseWithAccessToken: 액세스 토큰을 사용하여 Firebase에 로그인
// saveUserInfoToFirestore: Firebase Firestore에 사용자 정보 저장
// printUserInfo: 사용자 정보 출력
