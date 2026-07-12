import UIKit

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        if maxSide <= maxDimension { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Resize then JPEG-encode to a base64 string (no data-URL prefix) — the shape the
    /// `analyzeImport` GraphQL mutation expects for photo sources.
    func jpegBase64(maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.7) -> String? {
        resized(maxDimension: maxDimension)
            .jpegData(compressionQuality: compressionQuality)?
            .base64EncodedString()
    }
}
