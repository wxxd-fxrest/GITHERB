//
//  MainContentViewModel.swift
//  GITHERB
//
//  Created by 밀가루 on 8/6/24.
//

import SwiftUI
import FirebaseAuth

class MainContentViewModel: ObservableObject {
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var targetValue: Double = 33
    @Published var currentValue: Double = 0
    @Published var selectedStatistic: String = "이번 주"

    let numberOfSegments = 5
    let segmentSpacing: CGFloat = 4
    let segmentColors: [Color] = [
        Color("StepOneColor"), Color("StepTwoColor"), Color("StepThreeColor"), Color("StepFourColor"), Color("StepFiveColor")
    ]
    
    var progressPercentage: Double {
        (currentValue / targetValue) * 100
    }
    
    var segmentWidth: CGFloat {
        let totalWidth: CGFloat = UIScreen.main.bounds.width - 48
        return (totalWidth - CGFloat(numberOfSegments - 1) * segmentSpacing) / CGFloat(numberOfSegments)
    }
    
    var stepImageName: String {
        switch progressPercentage {
        case 0..<30:
            return "GitherbMark"
        case 30..<70:
            return "cat1"
        case 70..<99:
            return "cat2"
        case 100:
            return "cat3"
        default:
            return "GitherbMark"
        }
    }
    
    let data: [DailyCommitData]
    let maxValue: Double

    init(data: [DailyCommitData]) {
        self.data = data
        self.maxValue = data.map { $0.value }.max() ?? 0  // 0 대신 1로 설정 시 데이터가 없는 경우 문제가 될 수 있음
    }
    
    var filteredData: [DailyCommitData] {
         switch selectedStatistic {
         case "이번 주":
             return data.filter { Calendar.current.isDateInThisWeek($0.date) }
         case "이번 달":
             return data.filter { Calendar.current.isDateInThisMonth($0.date) }
         case "이번 년도":
             return data.filter { Calendar.current.isDateInThisYear($0.date) }
         default:
             return data
         }
     }
    
    func increaseValue() {
        currentValue = min(currentValue + 10, targetValue)
    }
    
    func decreaseValue() {
        currentValue = max(currentValue - 10, 0)
    }
    
    func selectStatistic(_ statistic: String) {
        selectedStatistic = statistic
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            UserDefaultsManager.shared.clearAll()
            if let window = UIApplication.shared.windows.first {
                window.rootViewController = UIHostingController(rootView: ContentView())
                window.makeKeyAndVisible()
            }
            printUserDefaultsValues()
        } catch {
            print("로그아웃 실패: \(error.localizedDescription)")
        }
    }
    
    private func printUserDefaultsValues() {
        print("signOut - isSignedIn: \(UserDefaultsManager.shared.isSignedIn)")
        print("signOut - isGitHubLoggedIn: \(UserDefaultsManager.shared.isGitHubLoggedIn)")
        if let value = KeychainManager.shared.load(key: "appleUserId") {
            print("signOut - appleUserId: \(value)")
        } else {
            print("signOut - appleUserId == nil")
        }
        if let value = KeychainManager.shared.load(key: "githubAccessToken") {
            print("signOut - githubAccessToken: \(value)")
        } else {
            print("signOut - githubAccessToken == nil")
        }
    }
}

extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    func isDateInThisMonth(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .month)
    }

    func isDateInThisYear(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .year)
    }
}
