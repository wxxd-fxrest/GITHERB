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
    @State private var signInCoordinator = SignInWithAppleCoordinator()

    var body: some View {
        VStack {
            Button(action: {
                signInCoordinator.startSignInWithAppleFlow(viewModel: viewModel)
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "applelogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text("Apple로 로그인")
                        .font(.system(size: 20, weight: .medium))
                }
                .frame(width: 300, height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color("AuthBackground")))
                .foregroundColor(Color("AuthFont"))
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text(viewModel.alertMessage))
        }
    }
}

class SignInWithAppleCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var viewModel: AppleSignInViewModel?

    func startSignInWithAppleFlow(viewModel: AppleSignInViewModel) {
        self.viewModel = viewModel
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            viewModel?.handleAuthorization(authResults: authorization)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple 로그인 실패: \(error.localizedDescription)")
    }
}

#Preview {
    AppleSignInView(viewModel: AppleSignInViewModel())
}
