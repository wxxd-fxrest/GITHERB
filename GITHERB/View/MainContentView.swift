//
//  MainContentView.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import SwiftUI

struct MainContentView: View {
    // 목표 수치와 현재 수치를 상태로 관리
    @State private var targetValue: Double = 33
    @State private var currentValue: Double = 0
    
    // 프로그레스 바 개수
    private let numberOfSegments = 5
    private let segmentSpacing: CGFloat = 4
    
    // 프로그레스 바 색상 배열
    private let segmentColors: [Color] = [
        Color("StepOneColor"), Color("StepTwoColor"), Color("StepThreeColor"), Color("StepFourColor"), Color("StepFiveColor")
    ]
    
    // 퍼센트 계산
    private var progressPercentage: Double {
        (currentValue / targetValue) * 100
    }
    
    // segmentWidth를 computed property로 정의
    private var segmentWidth: CGFloat {
        let totalWidth: CGFloat = UIScreen.main.bounds.width - 48 // 전체 디바이스 넓이에서 48을 뺀 값
        return (totalWidth - CGFloat(numberOfSegments - 1) * segmentSpacing) / CGFloat(numberOfSegments)
    }
    
    // step image
    private var stepImageName: String {
        switch progressPercentage {
        case 0..<30:
            return "GitherbMark" // 0% ~ 29%
        case 30..<70:
            return "cat1" // 30% ~ 69%
        case 70..<99:
            return "cat2" // 70% ~ 99%
        case 100:
            return "cat3" // 100%
        default:
            return "GitherbMark" // 100%
        }
    }
    
    @State private var selectedStatistic: String = "이번 주" // 기본 선택 통계
    
    var body: some View {
        let filledWidth: CGFloat = segmentWidth - segmentSpacing

        VStack {
            Spacer().frame(height: 32)
            // 상단 현재 수치, 목표 수치
            HStack {
                Text("오늘 목표까지")
                    .font(.system(size: 20, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(Color("CurrentValueColor"))
                Spacer()
                Text("\(Int(currentValue)) / \(Int(targetValue))")
                    .font(.system(size: 20, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(Color("CurrentValueColor"))
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 12)
            
            // 프로그래스 바
            HStack(spacing: segmentSpacing) {
                ForEach(0..<numberOfSegments) { index in
                    ZStack(alignment: .leading) {
                        // 배경
                        Rectangle()
                            .frame(width: segmentWidth, height: 34)
                            .foregroundColor(.gray.opacity(0.3))
                            .cornerRadius(4)
                        
                        // 채워진 부분
                        Rectangle()
                            .frame(width: index < Int(currentValue / (targetValue / Double(numberOfSegments))) ?
                                   segmentWidth :
                                    max(0, filledWidth * ((currentValue / (targetValue / Double(numberOfSegments))) - Double(index))), height: 34)
                            .foregroundColor(segmentColors[index % segmentColors.count])
                            .cornerRadius(4)
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.width - 48, height: 34)
            
            // 완료 퍼센트 및 임시 버튼
            HStack {
                Spacer()
                // 현재 수치를 변경할 수 있는 임시 버튼
                Button(action: {
                    if currentValue > 0 {
                        currentValue -= 1
                    }
                }) {
                    Text("-")
                        .font(.largeTitle)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(22)
                }
                
                Button(action: {
                    if currentValue < targetValue {
                        currentValue += 1
                    }
                }) {
                    Text("+")
                        .font(.largeTitle)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(22)
                }
                
                Text("\(String(format: "%.0f%%", progressPercentage)) 완료")
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.trailing, 24)
            
            Spacer().frame(height: 30)
            
            VStack(alignment: .center) {
                // 이미지
                Image(stepImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 240)
            }
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 24)
            
            HStack {
                Spacer().frame(width: 24)
                
                // 주간, 오늘, 월간 표시
                HStack {
                    statisticButton(title: "이번 주", value: "30")
                    Spacer()
                    Divider()
                    Spacer()
                    statisticButton(title: "오늘", value: "03")
                    Spacer()
                    Divider()
                    Spacer()
                    statisticButton(title: "이번 달", value: "146")
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 24)
                .frame(height: 94)
                .background(Color("BoxBackground"))
                .cornerRadius(12)

                Spacer().frame(width: 24)
            }
            
            Spacer().frame(height: 14)
            
            // 그래프
            graphView(title: selectedStatistic)
            Spacer()
        }
    }
    
    private func statisticButton(title: String, value: String) -> some View {
        Button(action: {
            selectedStatistic = title
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
        .buttonStyle(PlainButtonStyle()) // 기본 버튼 스타일 제거
    }
    
    private func graphView(title: String) -> some View {
        VStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .fixedSize(horizontal: true, vertical: false)
            // 그래프 추가 예정
        }
    }
}

#Preview {
    MainContentView()
}
