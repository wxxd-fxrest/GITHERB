//
//  TodayGraphView.swift
//  GITHERB
//
//  Created by 밀가루 on 8/6/24.
//

import SwiftUI

struct YearGraphView: View {
    let title: String
    let data: [DailyCommitData]
    let dateFormatter: DateFormatter

    @State private var scrollToToday = false
    
    private func getMinMaxValues() -> (minValue: Double, maxValue: Double) {
        let values = data.map { $0.value }
        return (values.min() ?? 0, values.max() ?? 1)
    }

    func colorForValue(_ value: Double?, minValue: Double, maxValue: Double) -> Color {
        guard let value = value else {
            return Color.gray.opacity(0.3)
        }
        
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

    private func monthHeaders() -> [String] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        return (1...12).compactMap { month -> String? in
            return dateFormatter.string(from: calendar.date(from: DateComponents(year: 2024, month: month, day: 1))!)
        }
    }

    private func generateGridData() -> [(date: Date, value: Double?)] {
        let calendar = Calendar.current
        let year = 2024
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        let today = Date()

        let filteredData = data.filter { $0.date >= yearStart && $0.date <= yearEnd }
        var gridData: [(date: Date, value: Double?)] = []
        
        for day in stride(from: yearStart, to: yearEnd, by: 60*60*24) {
            let matchingData = filteredData.first { calendar.isDate($0.date, inSameDayAs: day) }
            gridData.append((date: day, value: day <= today ? matchingData?.value : nil))
        }

        return gridData
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding(.bottom)

            let (minValue, maxValue) = getMinMaxValues()
            let monthNames = monthHeaders()
            let gridData = generateGridData()
            let today = Date()

            let dayColumns: [GridItem] = Array(repeating: .init(.fixed(20)), count: 7)

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { scrollViewProxy in
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            ForEach(monthNames, id: \.self) { month in
                                Text(month)
                                    .font(.caption)
                                    .frame(width: 100, height: 20, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, -2)

                        LazyHGrid(rows: dayColumns, spacing: 4) {
                            ForEach(gridData.indices, id: \.self) { index in
                                let day = gridData[index]
                                VStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(colorForValue(day.value, minValue: minValue, maxValue: maxValue))
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .accessibility(label: Text("\(day.date, formatter: dateFormatter): \(day.value ?? 0) contributions"))
                                .id(day.date)
                            }
                        }
                    }
                    .onAppear {
                        if let todayIndex = gridData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                            scrollViewProxy.scrollTo(gridData[todayIndex].date, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 400)
    }
}

struct YearGraphView_Previews: PreviewProvider {
    static var previews: some View {
        YearGraphView(title: "이번 년도", data: exampleYearData, dateFormatter: exampleDateFormatter)
            .previewLayout(.sizeThatFits)
    }
}
