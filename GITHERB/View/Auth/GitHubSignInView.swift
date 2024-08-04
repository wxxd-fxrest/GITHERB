//
//  GitHubSignInView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/2/24.
//
//

import SwiftUI

struct GitHubSignInView: View {
    @ObservedObject var viewModel: GitHubSignInViewModel
    
    var body: some View {
        VStack {
            Button(action: {
                viewModel.startGitHubSignIn()
            }) {
                HStack(spacing: 16) {
                    Image("GithubMark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text("GitHub로 로그인")
                        .font(.system(size: 20, weight: .medium))
                }
                .frame(width: 300, height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color("AuthBackground")))
                .foregroundColor(Color("AuthFont"))
            }
        }
    }
}

#Preview {
    GitHubSignInView(viewModel: GitHubSignInViewModel())
}
