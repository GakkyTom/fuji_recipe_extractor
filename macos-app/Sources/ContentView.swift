import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fuji Recipe Extractor")
                    .font(.largeTitle.weight(.semibold))
                Text("Fujifilm JPEG から撮影設定を抽出し、Markdown と画像コピーをまとめて出力します。")
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    folderRow(
                        title: "Input Folder",
                        path: viewModel.inputFolderPath,
                        action: viewModel.chooseInputFolder
                    )
                    folderRow(
                        title: "Output Folder",
                        path: viewModel.outputFolderPath,
                        action: viewModel.chooseOutputFolder
                    )
                }
                .padding(12)
            }

            HStack(alignment: .top, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.headline)

                        Picker("Copy Images By", selection: $viewModel.copyMode) {
                            ForEach(CopyMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("Dry Run", isOn: $viewModel.dryRun)
                        Toggle("Verbose Logging", isOn: $viewModel.verbose)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Run")
                            .font(.headline)
                        Text(viewModel.statusMessage)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            Button(viewModel.isRunning ? "Running..." : "Start Scan") {
                                viewModel.startScan()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isRunning)

                            if viewModel.isRunning {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Log")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            viewModel.clearLog()
                        }
                        .disabled(viewModel.logText.isEmpty)
                    }

                    TextEditor(text: $viewModel.logText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(12)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .alert("Scan Failed", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func folderRow(title: String, path: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            HStack(spacing: 10) {
                Text(path.isEmpty ? "Not selected" : path)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Choose…", action: action)
                    .buttonStyle(.bordered)
            }
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var inputFolderPath: String = ""
    @Published var outputFolderPath: String = ""
    @Published var copyMode: CopyMode = .none
    @Published var dryRun = false
    @Published var verbose = false
    @Published var isRunning = false
    @Published var statusMessage = "Input と Output を選んでから実行してください。"
    @Published var logText = ""
    @Published var showingError = false
    @Published var errorMessage = ""

    private let scanner = RecipeScanner()

    func chooseInputFolder() {
        if let url = chooseFolder() {
            inputFolderPath = url.path(percentEncoded: false)
        }
    }

    func chooseOutputFolder() {
        if let url = chooseFolder() {
            outputFolderPath = url.path(percentEncoded: false)
        }
    }

    func clearLog() {
        logText = ""
    }

    func startScan() {
        guard !inputFolderPath.isEmpty, !outputFolderPath.isEmpty else {
            statusMessage = "Input と Output を選んでください。"
            errorMessage = "Input と Output の両方のフォルダを選択してから実行してください。"
            showingError = true
            return
        }

        let config = ScanConfiguration(
            inputDirectory: URL(fileURLWithPath: inputFolderPath),
            outputDirectory: URL(fileURLWithPath: outputFolderPath),
            copyMode: copyMode,
            dryRun: dryRun,
            verbose: verbose
        )

        isRunning = true
        statusMessage = "Scanning..."
        appendLog("Starting scan")

        Task {
            do {
                let summary = try await scanner.scan(configuration: config) { line in
                    await MainActor.run {
                        self.appendLog(line)
                    }
                }
                isRunning = false
                statusMessage = summary
                appendLog(summary)
            } catch {
                isRunning = false
                statusMessage = "Scan failed"
                errorMessage = error.localizedDescription
                showingError = true
                appendLog("Error: \(error.localizedDescription)")
            }
        }
    }

    func appendLog(_ line: String) {
        if logText.isEmpty {
            logText = line
        } else {
            logText += "\n\(line)"
        }
    }

    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
