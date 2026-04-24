import Vision
import AppKit

// MARK: - TextRecognizer — Vision OCR wrapper

actor TextRecognizer {
    static let shared = TextRecognizer()

    func analyze(_ image: CGImage) async throws -> [RecognizedTextBlock] {
        // Guard: image too small for meaningful OCR
        guard image.width >= 50 && image.height >= 50 else { return [] }

        return try await Task.detached(priority: .userInitiated) {
            var blocks: [RecognizedTextBlock] = []

            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                blocks = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["it-IT", "en-US"]
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            return blocks
        }.value
    }
}
