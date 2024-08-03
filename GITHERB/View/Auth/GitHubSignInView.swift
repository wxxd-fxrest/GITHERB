//
//  GitHubSignInView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/2/24.
//
//

import SwiftUI

struct GitHubSignInView: View {
    @StateObject private var viewModel = GitHubSignInViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isSignedIn {
                Text("GitHub로 로그인됨")
            } else {
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
}

struct GitHubSignInView_Previews: PreviewProvider {
    static var previews: some View {
        GitHubSignInView()
    }
}

#Preview {
    GitHubSignInView()
}
