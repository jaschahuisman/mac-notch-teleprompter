import AVFoundation
import AppKit
import Combine

final class Recorder: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "recorder.session")

    @Published var isRecording = false
    @Published var isAvailable = false
    @Published var status = "Camera not started"
    @Published var lastSavedURL: URL?
    @Published var elapsed: TimeInterval = 0

    var outputFolder: URL = TeleprompterModel.defaultFolder
    var mirrored = false

    private var configured = false
    private var startDate: Date?
    private var tickTimer: Timer?
    private var finishCompletion: (() -> Void)?

    // MARK: Permissions + configuration

    /// Requests camera/mic access and wires up the capture session. Safe to call repeatedly.
    func prepare() {
        guard !configured else { return }
        requestAccess(for: .video) { [weak self] videoOK in
            guard let self else { return }
            self.requestAccess(for: .audio) { audioOK in
                guard videoOK else {
                    DispatchQueue.main.async { self.status = "Camera access denied" }
                    return
                }
                self.configure(audioGranted: audioOK)
            }
        }
    }

    private func requestAccess(for type: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: completion(true)
        case .notDetermined: AVCaptureDevice.requestAccess(for: type) { completion($0) }
        default: completion(false)
        }
    }

    private func configure(audioGranted: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let camera = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(videoInput) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.status = "No camera found" }
                return
            }
            self.session.addInput(videoInput)

            if audioGranted, let mic = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
            self.configured = true
            DispatchQueue.main.async {
                self.isAvailable = true
                self.status = "Ready"
            }
        }
    }

    // MARK: Recording control

    func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        guard configured else {
            prepare()
            DispatchQueue.main.async { self.status = "Starting camera… tap record again" }
            return
        }
        let url = makeOutputURL()
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
        }
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    private func stop() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    /// Finalize an in-progress recording before the app quits, then call completion.
    func finishForTermination(_ completion: @escaping () -> Void) {
        guard movieOutput.isRecording else { completion(); return }
        finishCompletion = completion
        movieOutput.stopRecording()
    }

    private func makeOutputURL() -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let name = "Teleprompter_\(fmt.string(from: Date())).mov"
        return outputFolder.appendingPathComponent(name)
    }

    // MARK: Delegate

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.isRecording = true
            self.startDate = Date()
            self.elapsed = 0
            self.status = "Recording"
            let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self, let s = self.startDate else { return }
                self.elapsed = Date().timeIntervalSince(s)
            }
            RunLoop.main.add(t, forMode: .common)
            self.tickTimer = t
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.tickTimer?.invalidate()
            self.tickTimer = nil
            self.startDate = nil
            if let error {
                self.status = "Error: \(error.localizedDescription)"
            } else {
                self.lastSavedURL = outputFileURL
                self.status = "Saved \(outputFileURL.lastPathComponent)"
            }
            self.finishCompletion?()
            self.finishCompletion = nil
        }
    }

    func revealLastInFinder() {
        guard let url = lastSavedURL else {
            NSWorkspace.shared.activateFileViewerSelecting([outputFolder])
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
