import SwiftUI

struct TelemetryDebugView: View {
    @StateObject private var telemetry = TelemetryManager.shared
    @State private var report = KPIReport(ocrSuccessRate: 0, averageOCRDuration: 0, exportSuccessRate: 0, averageExportDuration: 0, parseCancellationRate: 0, tableDetectionSuccessRate: 0, retryFrequency: 0, documentSaveRate: 0)
    @State private var query = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Telemetry Opt-In", isOn: $telemetry.telemetryEnabled).tint(.cyan)
                    Text("Queue: \(telemetry.liveEvents.count) • Uploading: \(telemetry.isUploading ? "Yes" : "No")")
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                        card("OCR Success", report.ocrSuccessRate)
                        card("OCR Avg(ms)", report.averageOCRDuration)
                        card("Export Success", report.exportSuccessRate)
                        card("Export Avg(ms)", report.averageExportDuration)
                        card("Parse Cancel", report.parseCancellationRate)
                        card("Table Success", report.tableDetectionSuccessRate)
                    }
                    TextField("Search events", text: $query).textFieldStyle(.roundedBorder)
                    ForEach(telemetry.liveEvents.filter { query.isEmpty || $0.name.rawValue.contains(query) }) { event in
                        VStack(alignment: .leading) {
                            Text(event.name.rawValue).bold()
                            Text(event.metadata.description).font(.caption).foregroundStyle(.secondary)
                        }.padding(8).background(.ultraThinMaterial).cornerRadius(8)
                    }
                    if !telemetry.recentFailures.isEmpty { Text("Recent failures: \(telemetry.recentFailures.joined(separator: ", "))").font(.caption) }
                    HStack {
                        Button("Clear Telemetry") { telemetry.clear() }
                        if let url = telemetry.exportURL() { ShareLink("Export JSON", item: url) }
                    }
                }.padding()
            }
        }
        .preferredColorScheme(.dark)
        .task { report = await telemetry.snapshotKPI() }
    }

    private func card(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption); Text(String(format: "%.2f", value)).font(.headline) }
            .frame(maxWidth: .infinity, alignment: .leading).padding().background(.ultraThinMaterial).cornerRadius(12)
    }
}
