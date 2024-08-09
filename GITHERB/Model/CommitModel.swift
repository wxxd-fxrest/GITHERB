//
//  CommitModel.swift
//  GITHERB
//
//  Created by 밀가루 on 8/6/24.
//

import Foundation
import SwiftUI

// today commit 데이터 모델
struct DailyCommitData: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
    let date: Date
}

// 날짜 formatter
func date(from string: String) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.date(from: string)
}

// 날짜 formatter 사용 예시
let exampleDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

// Year Data 예시
let exampleYearData: [DailyCommitData] = {
    var data: [DailyCommitData] = []
    let calendar = Calendar.current
    let year = 2024
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    for month in 1...12 {
        let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month))!)!
        for day in range {
            let dateString = String(format: "%04d-%02d-%02d", year, month, day)
            if let date = date(from: dateString) {
                let dayName = dateFormatter.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
                let value = Double.random(in: 10...100) // Random value between 10 and 100
                data.append(DailyCommitData(day: dayName, value: value, date: date))
            }
        }
    }
    return data
}()
