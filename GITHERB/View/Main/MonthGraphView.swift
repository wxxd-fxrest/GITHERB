//
//  MonthGraphView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/6/24.
//

import SwiftUI

struct MonthGraphView: View {
    let title: String
    let data: [DailyCommitData]
    let dateFormatter: DateFormatter
    
    private func colorForValue(_ value: Double, minValue: Double, maxValue: Double) -> Color {
        let range = maxValue - minValue
        let oneThird = range / 3
        
        if value < minValue + oneThird {
            return Color.green
        } else if value < minValue + 2 * oneThird {
            return Color.yellow
        } else {
            return Color.red
        }
    }
    
    var filteredAndSortedData: [DailyCommitData] {
        let today = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        
        let filteredData = data.filter { $0.date <= todayStart }
        
        let sortedData = filteredData.sorted { $0.date < $1.date }
        
        let todayData = sortedData.filter { calendar.isDateInToday($0.date) }
        let otherData = sortedData.filter { !calendar.isDateInToday($0.date) }
        
        return otherData + todayData
    }
    
    var body: some View {
        let filteredData = filteredAndSortedData
        let minValue = filteredData.map { $0.value }.min() ?? 0
        let maxValue = filteredData.map { $0.value }.max() ?? 1
        
        return VStack {
            Text(title)
                .padding(.bottom, 20)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(filteredData) { item in
                            VStack {
                                Text(String(format: "%.0f", item.value))
                                    .font(.caption)
                                    .padding(.bottom, 5)
                                GeometryReader { geometry in
                                    VStack {
                                        Spacer(minLength: 0)
                                        Rectangle()
                                            .fill(colorForValue(item.value, minValue: minValue, maxValue: maxValue))
                                            .frame(width: 30, height: CGFloat(item.value - minValue) / CGFloat(maxValue - minValue) * geometry.size.height)
                                    }
                                }
                                .frame(width: 30, height: 200)
                                
                                Text(item.day)
                                    .font(.caption)
                                    .padding(.top, 5)
                                Text(dateFormatter.string(from: item.date))
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 5)
                            }
                            .id(item.date)
                        }
                    }
                    .onAppear {
                        let today = Date()
                        let calendar = Calendar.current
                        let todayStart = calendar.startOfDay(for: today)
                        if let todayItem = filteredData.first(where: { $0.date == todayStart }) {
                            proxy.scrollTo(todayItem.date, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 400)
    }
}

struct MonthGraphView_Previews: PreviewProvider {
    static var previews: some View {
        MonthGraphView(title: "이번 달", data: exampleYearData, dateFormatter: exampleDateFormatter)
            .previewLayout(.sizeThatFits)
    }
}
