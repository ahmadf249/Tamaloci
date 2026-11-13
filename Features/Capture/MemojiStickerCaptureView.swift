import SwiftUI
import UIKit

/// Lets the user insert a Memoji / Genmoji sticker from the system emoji keyboard
/// into a `UITextView`, then extracts a `UIImage` for ephemeral likeness mapping.
///
/// - iOS 18+: `NSAdaptiveImageGlyph` via `supportsAdaptiveImageGlyph`
/// - iOS 17: `NSTextAttachment` via `allowsEditingTextAttributes`
struct MemojiStickerCaptureView: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Open the emoji keyboard, tap Stickers, then choose a Memoji (or Genmoji on supported devices). We’ll use it only to style your floating head — the image isn’t kept.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                MemojiStickerTextView(onImage: onCapture)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(.separator), lineWidth: 1)
                    )

                Text("Tap the field above, then insert a sticker.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Memoji sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

/// UIKit bridge: rich `UITextView` that reports the first inserted sticker image.
private struct MemojiStickerTextView: UIViewRepresentable {
    var onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = true
        textView.font = .systemFont(ofSize: 40)
        textView.textAlignment = .center
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 12, bottom: 24, right: 12)
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        if #available(iOS 18.0, *) {
            textView.supportsAdaptiveImageGlyph = true
        }
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onImage = onImage
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onImage: (UIImage) -> Void
        private var didEmit = false

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !didEmit, let attr = textView.attributedText, attr.length > 0 else { return }

            if let image = Self.extractStickerImage(from: attr) {
                didEmit = true
                textView.text = ""
                onImage(image)
            }
        }

        private static func extractStickerImage(from attr: NSAttributedString) -> UIImage? {
            let full = NSRange(location: 0, length: attr.length)

            if #available(iOS 18.0, *) {
                var glyphImage: UIImage?
                attr.enumerateAttribute(.adaptiveImageGlyph, in: full) { value, _, stop in
                    guard let glyph = value as? NSAdaptiveImageGlyph else { return }
                    if let image = decodeGlyphImage(glyph.imageContent) {
                        glyphImage = image
                        stop.pointee = true
                    }
                }
                if let glyphImage { return glyphImage }
            }

            var attachmentImage: UIImage?
            attr.enumerateAttribute(.attachment, in: full) { value, range, stop in
                guard let attachment = value as? NSTextAttachment else { return }
                let image = attachment.image
                    ?? attachment.image(
                        forBounds: attachment.bounds,
                        textContainer: nil,
                        characterIndex: range.location
                    )
                if let image {
                    attachmentImage = image
                    stop.pointee = true
                }
            }
            return attachmentImage
        }

        /// Adaptive glyphs often ship HEIC `imageContent`; force a drawable UIImage.
        private static func decodeGlyphImage(_ data: Data) -> UIImage? {
            if let image = UIImage(data: data), image.size.width > 1, image.size.height > 1 {
                return image
            }
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return UIImage(cgImage: cgImage)
            }
            return nil
        }
    }
}
