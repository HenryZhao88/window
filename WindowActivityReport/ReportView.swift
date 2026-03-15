import Charts
import SwiftUI

// MARK: - Categories → color

private let categoryColors: [String: Color] = [
    "Social Networking": Color(red: 0.48, green: 0.36, blue: 0.93),
    "Entertainment":     Color(red: 1.00, green: 0.55, blue: 0.15),
    "Games":             Color(red: 0.20, green: 0.78, blue: 0.52),
    "Productivity":      Color(red: 0.20, green: 0.56, blue: 0.98),
    "Education":         Color(red: 0.20, green: 0.70, blue: 0.60),
    "Utilities":         Color.gray,
]

private func color(for category: String) -> Color {
    categoryColors[category] ?? .gray
}

// MARK: - Chart data point

private struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
    let category: String
}

// MARK: - Report view (pure display — no async work)

struct ReportView: View {
    let days: [ProcessedDay]

    private var activeCategories: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for day in days {
            for key in day.categoryMinutes.keys where !seen.contains(key) && key != "Other" {
                seen.insert(key)
                ordered.append(key)
            }
        }
        return ordered.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 20)
            chartArea
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            if !activeCategories.isEmpty {
                legendRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Screen Time")
                .font(.headline)
            Text(totalLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartArea: some View {
        if chartPoints.isEmpty {
            emptyState
                .frame(height: 200)
        } else {
            Chart(chartPoints) { point in
                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Min", point.minutes),
                    series: .value("Category", point.category)
                )
                .foregroundStyle(by: .value("Category", point.category))
                .opacity(0.18)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Min", point.minutes),
                    series: .value("Category", point.category)
                )
                .foregroundStyle(by: .value("Category", point.category))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .symbol {
                    Circle()
                        .fill(Color(.systemBackground))
                        .strokeBorder(color(for: point.category), lineWidth: 2)
                        .frame(width: 7, height: 7)
                }
            }
            .chartForegroundStyleScale(colorScale)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days.count > 7 ? 2 : 1)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color(.systemGray4))
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color(.systemGray4))
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .chartLegend(.hidden)
            .frame(height: 200)
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 14) {
            ForEach(activeCategories, id: \.self) { cat in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: cat))
                        .frame(width: 12, height: 3)
                    Text(cat)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No Screen Time data yet")
                .font(.subheadline).bold()
                .foregroundStyle(.secondary)
            Text("Use your phone normally for a day or two and real data will appear here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed

    private var chartPoints: [DataPoint] {
        var result: [DataPoint] = []
        for day in days {
            for (cat, mins) in day.categoryMinutes where mins > 0 && cat != "Other" {
                result.append(DataPoint(date: day.date, minutes: mins, category: cat))
            }
        }
        return result
    }

    private var colorScale: KeyValuePairs<String, Color> {
        [
            "Social Networking": color(for: "Social Networking"),
            "Entertainment":     color(for: "Entertainment"),
            "Games":             color(for: "Games"),
            "Productivity":      color(for: "Productivity"),
            "Education":         color(for: "Education"),
            "Utilities":         color(for: "Utilities"),
        ]
    }

    private var totalLabel: String {
        let total = days.reduce(0) { $0 + $1.totalMinutes }
        if total == 0 { return "No data yet" }
        let h = Int(total) / 60
        let m = Int(total) % 60
        let range = days.count <= 1 ? "today" : "past \(days.count) days"
        return h > 0 ? "\(h)h \(m)m \(range)" : "\(m)m \(range)"
    }
}
