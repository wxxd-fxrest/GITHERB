//
//  AppleSignInView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/2/24.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInView: View {
    @ObservedObject var viewModel: AppleSignInViewModel

    var body: some View {
        VStack {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authResults):
                    viewModel.handleAuthorization(authResults: authResults)
                case .failure(let error):
                    print("Apple 로그인 실패: \(error)")
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(width: 280, height: 60)

            if viewModel.showGitHubSignIn {
                Button("GitHub 연동하기") {
                    viewModel.linkGitHubAccount()
                }
                .padding()
                .frame(width: 280, height: 60)
                .background(Color.black)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text(viewModel.alertMessage))
        }
    }
}
