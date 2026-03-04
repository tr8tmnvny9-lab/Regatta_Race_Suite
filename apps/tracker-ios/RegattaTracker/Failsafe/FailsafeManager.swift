import Foundation
import Combine

class FailsafeManager: ObservableObject {
    private var logFileHandle: FileHandle?
    private let fileManager = FileManager.default
    
    @Published var isRecordingLocal: Bool = false
    
    private var logsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("TelemetryLogs")
    }
    
    init() {
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
    
    func startRecording() {
        guard !isRecordingLocal else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileName = "telemetry_\(timestamp).jsonl"
        let fileURL = logsDirectory.appendingPathComponent(fileName)
        
        fileManager.createFile(atPath: fileURL.path, contents: nil)
        
        do {
            logFileHandle = try FileHandle(forWritingTo: fileURL)
            isRecordingLocal = true
            print("Failsafe: Started local recording to \(fileName)")
        } catch {
            print("Failsafe: Failed to create log file: \(error)")
        }
    }
    
    func stopRecording() {
        logFileHandle?.closeFile()
        logFileHandle = nil
        isRecordingLocal = false
        print("Failsafe: Stopped local recording")
    }
    
    func logTelemetry(_ payload: [String: Any]) {
        guard isRecordingLocal, let handle = logFileHandle else { return }
        
        var mutablePayload = payload
        mutablePayload["failsafe_ts"] = Date().timeIntervalSince1970
        
        if let data = try? JSONSerialization.data(withJSONObject: mutablePayload),
           let jsonString = String(data: data, encoding: .utf8) {
            let line = jsonString + "\n"
            if let lineData = line.data(using: .utf8) {
                handle.write(lineData)
            }
        }
    }
}
