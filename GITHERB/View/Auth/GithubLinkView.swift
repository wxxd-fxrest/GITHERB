//
//  GithubLinkView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/3/24.
//

import SwiftUI

struct GithubLinkView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AppleSignInViewModel

    var body: some View {
        VStack(spacing: 104) {
            Spacer()
            
            VStack(spacing: 34) {
                VStack(spacing: 4) {
                    Text("GitHub 계정을 연결해 주세요!")
                        .font(.system(size: 24, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("GitHub 계정이 없다면 가입 후 이용해 주세요.")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 300, alignment: .leading)
                
                Image("GitherbMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 240, height: 290)
            }
            
            Button(action: {
                viewModel.linkGitHubAccount()
            }) {
                HStack(spacing: 16) {
                    Image("GithubMark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text("GitHub로 계속하기")
                        .font(.system(size: 20, weight: .medium))
                }
                .frame(width: 300, height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color("AuthBackground")))
                .foregroundColor(Color("AuthFont"))
            }
        }
        .padding(.bottom, 110)
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .navigationBarBackButtonHidden(true) 
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("AuthBackground"))
                    }
                }
            }
        }
    }
}

#Preview {
    GithubLinkView(viewModel: AppleSignInViewModel())
}
