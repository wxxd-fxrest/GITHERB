//
//  MainContentView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import SwiftUI

struct MainContentView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: MainContentViewModel
    
    init(data: [DailyCommitData]) {
        _viewModel = StateObject(wrappedValue: MainContentViewModel(data: data))
    }
    
    var body: some View {
        let filledWidth: CGFloat = viewModel.segmentWidth - viewModel.segmentSpacing
        
        ScrollView {
            VStack {
                Spacer().frame(height: 32)
                headerView()
                progressBarView()
                actionButtons()
                Spacer().frame(height: 30)
                stepImageView()
                Spacer().frame(height: 24)
                statisticSelector()
                Spacer().frame(height: 14)
                graphView()
                Spacer().frame(height: 30)
                signOutButton()
                Spacer().frame(height: 16)
            }
        }
    }
    
    private func headerView() -> some View {
        HStack {
            Text("오늘 목표까지")
                .font(.system(size: 20, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(Color("CurrentValueColor"))
            Spacer()
            Text("\(Int(viewModel.currentValue)) / \(Int(viewModel.targetValue))")
                .font(.system(size: 20, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(Color("CurrentValueColor"))
        }
        .padding(.horizontal, 24)
    }
    
    private func progressBarView() -> some View {
        HStack(spacing: viewModel.segmentSpacing) {
            ForEach(0..<viewModel.numberOfSegments) { index in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: viewModel.segmentWidth, height: 34)
                        .foregroundColor(.gray.opacity(0.3))
                        .cornerRadius(4)
                    
                    Rectangle()
                        .frame(width: index < Int(viewModel.currentValue / (viewModel.targetValue / Double(viewModel.numberOfSegments))) ?
                               viewModel.segmentWidth :
                                max(0, viewModel.segmentWidth * ((viewModel.currentValue / (viewModel.targetValue / Double(viewModel.numberOfSegments))) - Double(index))), height: 34)
                        .foregroundColor(viewModel.segmentColors[index % viewModel.segmentColors.count])
                        .cornerRadius(4)
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width - 48, height: 34)
    }
    
    private func actionButtons() -> some View {
        HStack {
            Spacer()
            Button(action: {
                viewModel.decreaseValue()
            }) {
                Text("-")
                    .font(.largeTitle)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(22)
            }
            
            Button(action: {
                viewModel.increaseValue()
            }) {
                Text("+")
                    .font(.largeTitle)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(22)
            }
            
            Text("\(String(format: "%.0f%%", viewModel.progressPercentage)) 완료")
                .font(.system(size: 16, weight: .medium))
        }
        .padding(.trailing, 24)
    }
    
    private func stepImageView() -> some View {
        VStack(alignment: .center) {
            Image(viewModel.stepImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 240)
        }
        .padding(.horizontal, 24)
    }
    
    private func statisticSelector() -> some View {
        HStack {
            Spacer().frame(width: 24)
            HStack {
                statisticButton(title: "이번 주", value: "30")
                Spacer()
                Divider()
                Spacer()
                statisticButton(title: "이번 달", value: "86")
                Spacer()
                Divider()
                Spacer()
                statisticButton(title: "이번 년도", value: "345")
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .frame(height: 94)
            .background(Color("BoxBackground"))
            .cornerRadius(12)
            Spacer().frame(width: 24)
        }
    }
    
    @ViewBuilder
    private func graphView() -> some View {
        switch viewModel.selectedStatistic {
        case "이번 주":
            WeeklyGraphView(title: viewModel.selectedStatistic, data: viewModel.filteredData, dateFormatter: exampleDateFormatter)
        case "이번 달":
            MonthGraphView(title: viewModel.selectedStatistic, data: viewModel.filteredData, dateFormatter: exampleDateFormatter)
        case "이번 년도":
            YearGraphView(title: viewModel.selectedStatistic, data: viewModel.filteredData, dateFormatter: exampleDateFormatter)
        default:
            EmptyView()  // 빈 뷰를 반환하여 오류 해결
        }
    }


    private func signOutButton() -> some View {
        Button(action: {
            viewModel.showAlert = true
        }) {
            Text("Sign Out")
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("로그아웃 확인"),
                message: Text("정말로 로그아웃 하시겠습니까?"),
                primaryButton: .destructive(Text("로그아웃")) {
                    viewModel.signOut()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func statisticButton(title: String, value: String) -> some View {
        Button(action: {
            viewModel.selectStatistic(title)
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(Color("ActivateFont"))
                Text(value)
                    .font(.system(size: 20, weight: .medium))
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(Color("ActivateFont"))
            }
            .padding()
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainContentView(data: exampleYearData)
}
