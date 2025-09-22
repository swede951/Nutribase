//
//  BarcodeScannerComponents.swift
//  nutribase
//
//  Created on 28/08/2025.
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Binding var scannedBarcode: String?
    @Binding var isPresented: Bool
    @State private var manualBarcodeInput: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Use AVFoundation-based scanner
                BarcodeScannerRepresentable { result in
                    isPresented = false
                    switch result {
                    case .success(let code):
                        scannedBarcode = code
                    case .failure(let error):
                        // Silently handle barcode scan errors for simulator testing
                        break
                    }
                }
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Text("Can't scan? Enter barcode manually")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Enter barcode number", text: $manualBarcodeInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Button("Submit") {
                            if !manualBarcodeInput.isEmpty {
                                scannedBarcode = manualBarcodeInput
                                isPresented = false
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }
                .padding(.bottom)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Scanner bridge
struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    enum ScanError: LocalizedError {
        case noCamera, permissionDenied, sessionFailed
        var errorDescription: String? {
            switch self {
            case .noCamera: return "No camera available on this device."
            case .permissionDenied: return "Camera permission denied."
            case .sessionFailed: return "Failed to start capture session."
            }
        }
    }

    typealias Completion = (Result<String, Error>) -> Void
    let onResult: Completion

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.onCodeFound = { code in
            onResult(.success(code))
        }
        vc.onError = { error in
            onResult(.failure(error))
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) { }
}

// MARK: - UIKit barcode scanner
final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    // Public callbacks
    var onCodeFound: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    // AVFoundation components
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let metadataOutput = AVCaptureMetadataOutput()

    // UI overlays
    private let guidanceLabel: UILabel = {
        let label = UILabel()
        label.text = "Point your camera at a barcode"
        label.textColor = .white
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        return label
    }()

    private let boundingBox: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemGreen.cgColor
        layer.lineWidth = 3
        layer.fillColor = UIColor.clear.cgColor
        layer.lineJoin = .round
        layer.lineDashPattern = [6, 4]
        layer.isHidden = true
        return layer
    }()

    private var isSessionConfigured = false
    private var didReturnResult = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Camera preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.layer.addSublayer(boundingBox)

        // Guidance label
        view.addSubview(guidanceLabel)

        // Permission handling & session setup
        configureOrRequestPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds

        let labelWidth = min(view.bounds.width - 40, 360)
        guidanceLabel.frame = CGRect(
            x: (view.bounds.width - labelWidth) / 2,
            y: view.safeAreaInsets.top + 16,
            width: labelWidth,
            height: 40
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSessionIfPossible()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    // MARK: - Permissions & Setup
    private func configureOrRequestPermission() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showNoCameraUI()
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSessionIfNeeded()
                    } else {
                        self?.showPermissionDeniedUI()
                        self?.onError?(BarcodeScannerRepresentable.ScanError.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedUI()
            onError?(BarcodeScannerRepresentable.ScanError.permissionDenied)
        @unknown default:
            onError?(BarcodeScannerRepresentable.ScanError.permissionDenied)
        }
    }

    private func showPermissionDeniedUI() {
        let alert = UIAlertController(
            title: "Camera Access Needed",
            message: "Enable camera access in Settings to scan codes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        present(alert, animated: true)
    }
    
    private func showNoCameraUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Hide camera preview and show simulator-friendly UI
            self.previewLayer.isHidden = true
            self.guidanceLabel.text = "Camera not available\nUse manual entry below"
            self.guidanceLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
            
            // Add a placeholder view for the camera area
            let placeholderView = UIView()
            placeholderView.backgroundColor = UIColor.systemGray5
            placeholderView.layer.cornerRadius = 12
            
            let placeholderLabel = UILabel()
            placeholderLabel.text = "📷\nCamera not available\n(Simulator mode)"
            placeholderLabel.textAlignment = .center
            placeholderLabel.numberOfLines = 0
            placeholderLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            placeholderLabel.textColor = UIColor.systemGray
            
            placeholderView.addSubview(placeholderLabel)
            self.view.addSubview(placeholderView)
            
            placeholderView.translatesAutoresizingMaskIntoConstraints = false
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                placeholderView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                placeholderView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -50),
                placeholderView.widthAnchor.constraint(equalToConstant: 280),
                placeholderView.heightAnchor.constraint(equalToConstant: 200),
                
                placeholderLabel.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
                placeholderLabel.centerYAnchor.constraint(equalTo: placeholderView.centerYAnchor)
            ])
        }
    }

    private func setupSessionIfNeeded() {
        guard !isSessionConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        // Input
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            onError?(BarcodeScannerRepresentable.ScanError.sessionFailed)
            return
        }
        session.addInput(input)

        // Output (metadata)
        guard session.canAddOutput(metadataOutput) else {
            session.commitConfiguration()
            onError?(BarcodeScannerRepresentable.ScanError.sessionFailed)
            return
        }
        session.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        // Focus on food product barcodes
        let types: [AVMetadataObject.ObjectType] = [
            .ean8, .ean13, .upce,
            .code39, .code39Mod43, .code93, .code128,
            .itf14, .dataMatrix
        ].filter { metadataOutput.availableMetadataObjectTypes.contains($0) }

        metadataOutput.metadataObjectTypes = types

        session.commitConfiguration()
        isSessionConfigured = true
        startSessionIfPossible()
    }

    private func startSessionIfPossible() {
        guard isSessionConfigured, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    // MARK: - Delegate
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        guard !didReturnResult else { return } // prevent duplicates after success

        // Find the first readable code with a string value
        for object in metadataObjects {
            guard
                let readable = object as? AVMetadataMachineReadableCodeObject,
                let stringValue = readable.stringValue
            else { continue }

            // Draw bounding box
            if let transformed = previewLayer.transformedMetadataObject(for: readable) as? AVMetadataMachineReadableCodeObject {
                drawBoundingBox(for: transformed)
            }

            print("📱 Found barcode: \(stringValue)")
            didReturnResult = true
            // Give the UI a tiny moment to show the box before closing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.session.stopRunning()
                self?.onCodeFound?(stringValue)
            }
            break
        }

        if metadataObjects.isEmpty {
            boundingBox.isHidden = true
        }
    }

    // MARK: - Bounding box
    private func drawBoundingBox(for object: AVMetadataMachineReadableCodeObject) {
        guard !object.corners.isEmpty else {
            boundingBox.isHidden = true
            return
        }

        let path = UIBezierPath()
        path.move(to: object.corners[0])
        for i in 1..<object.corners.count { path.addLine(to: object.corners[i]) }
        path.close()

        boundingBox.path = path.cgPath
        boundingBox.isHidden = false
    }
}

// Lighting analyzer for adaptive camera settings
class LightingAnalyzer {
    private var currentLightingCondition: LightingCondition = .good
    
    enum LightingCondition {
        case excellent, good, fair, poor
        
        var description: String {
            switch self {
            case .excellent: return "Excellent lighting"
            case .good: return "Good lighting"
            case .fair: return "Fair lighting"
            case .poor: return "Poor lighting"
            }
        }
    }
    
    func updateLightingConditions() {
        // Get current camera device
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        // Analyze current ISO and exposure duration
        let currentISO = captureDevice.iso
        let exposureDuration = captureDevice.exposureDuration.seconds
        
        // Determine lighting condition based on camera metrics
        let newCondition: LightingCondition
        if currentISO < 200 && exposureDuration < 1.0/60.0 {
            newCondition = .excellent
        } else if currentISO < 400 && exposureDuration < 1.0/30.0 {
            newCondition = .good
        } else if currentISO < 800 && exposureDuration < 1.0/15.0 {
            newCondition = .fair
        } else {
            newCondition = .poor
        }
        
        // Update settings if condition changed
        if newCondition != currentLightingCondition {
            currentLightingCondition = newCondition
            adaptCameraSettings(for: newCondition, device: captureDevice)
        }
    }
    
    private func adaptCameraSettings(for condition: LightingCondition, device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            switch condition {
            case .excellent, .good:
                // Optimal conditions - use standard settings
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
                
            case .fair:
                // Moderate conditions - slightly more aggressive exposure
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                
            case .poor:
                // Poor conditions - enable torch and optimize for low light
                if device.isTorchModeSupported(.on) {
                    device.torchMode = .on
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                // Lock focus to infinity for better low-light performance
                if device.isFocusModeSupported(.locked) {
                    device.setFocusModeLocked(lensPosition: 1.0, completionHandler: nil)
                }
            }
            
            device.unlockForConfiguration()
            print("📷 Lighting condition: \(condition.description)")
            
        } catch {
            print("❌ Failed to adapt camera settings: \(error)")
        }
    }
}
