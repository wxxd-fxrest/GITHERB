//
//  WeeklyGraphView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/6/24.
//

import SwiftUI

struct WeeklyGraphView: View {
    let title: String
    let data: [DailyCommitData]
    let dateFormatter: DateFormatter

    @State private var scrollViewProxy: ScrollViewProxy?

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

    private func getStartAndEndOfWeek(for date: Date) -> (startOfWeek: Date, endOfWeek: Date) {
        let calendar = Calendar.current
        let weekStart = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let startOfWeek = calendar.date(from: weekStart)!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        return (startOfWeek, endOfWeek)
    }
    
    private func filterDataForCurrentWeek(data: [DailyCommitData]) -> [DailyCommitData] {
        let today = Date()
        let (startOfWeek, endOfWeek) = getStartAndEndOfWeek(for: today)
        
        return data.filter { item in
            return item.date >= startOfWeek && item.date <= today
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        let filteredData = filterDataForCurrentWeek(data: data)
        let minValue = filteredData.map { $0.value }.min() ?? 0
        let maxValue = filteredData.map { $0.value }.max() ?? 1

        return VStack {
            Text(title)
                .padding(.bottom, 20)
            
            ScrollViewReader { scrollViewProxy in
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
                        if let lastDate = filteredData.last?.date {
                            scrollViewProxy.scrollTo(lastDate, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 400)
    }
}

struct WeeklyGraphView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyGraphView(title: "이번 주", data: exampleYearData, dateFormatter: exampleDateFormatter)
            .previewLayout(.sizeThatFits)
    }
}

