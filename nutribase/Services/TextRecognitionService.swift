import SwiftUI
import Vision
import VisionKit

class TextRecognitionService: ObservableObject {
    static let shared = TextRecognitionService()
    
    @Published var recognizedText = ""
    @Published var isScanning = false
    @Published var scanError: String?
    
    // Process image for text recognition
    func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        // Create a new Vision request to recognize text
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.scanError = "Error scanning text: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Process the results
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    self.scanError = "No text recognized"
                    completion(nil)
                }
                return
            }
            
            // Extract the recognized text
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")
            
            DispatchQueue.main.async {
                self.recognizedText = recognizedText
                completion(recognizedText)
            }
        }
        
        // Configure the request for ingredient lists
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Create a Vision image request handler and perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.scanError = "Failed to perform text recognition: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
    }
    
    // Extract ingredients from recognized text
    func extractIngredients(from text: String) -> String {
        // Look for common ingredient list patterns
        let lowercaseText = text.lowercased()
        
        // Try to find the ingredients section
        var ingredientsText = ""
        
        // Common patterns for ingredient lists
        let patterns = [
            "ingredients:(.*?)(?:\\.|$|nutrition|allergens)",
            "ingredients list:(.*?)(?:\\.|$|nutrition|allergens)",
            "contains:(.*?)(?:\\.|$|nutrition|allergens)",
            "ingredients \\[(.*?)\\]"
        ]
        
        for pattern in patterns {
            if let range = lowercaseText.range(of: pattern, options: .regularExpression) {
                // Extract the matched text
                let match = String(lowercaseText[range])
                
                // Remove the "ingredients:" prefix
                if let colonIndex = match.firstIndex(of: ":") {
                    ingredientsText = String(match[match.index(after: colonIndex)...])
                } else {
                    ingredientsText = match
                }
                
                break
            }
        }
        
        // If no pattern matched, just return the original text
        if ingredientsText.isEmpty {
            return text
        }
        
        // Clean up the extracted text
        ingredientsText = ingredientsText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return ingredientsText
    }
}

// Camera view controller for scanning ingredients
struct ScannerViewController: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var isScanning: Bool
    var completion: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = context.coordinator
        return documentCameraViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(recognizedText: $recognizedText, isScanning: $isScanning, completion: completion)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        @Binding var recognizedText: String
        @Binding var isScanning: Bool
        var completion: (UIImage) -> Void
        
        init(recognizedText: Binding<String>, isScanning: Binding<Bool>, completion: @escaping (UIImage) -> Void) {
            self._recognizedText = recognizedText
            self._isScanning = isScanning
            self.completion = completion
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Process the scanned image
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true)
                isScanning = false
                return
            }
            
            let image = scan.imageOfPage(at: 0)
            completion(image)
            controller.dismiss(animated: true)
            isScanning = false
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            isScanning = false
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document camera view controller did fail with error: \(error.localizedDescription)")
            controller.dismiss(animated: true)
            isScanning = false
        }
    }
}
