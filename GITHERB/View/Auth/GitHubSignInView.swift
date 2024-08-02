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
                    Text("GitHub로 로그인")
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
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

