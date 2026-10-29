import SwiftUI

/// The sample slide as a one-page PDF, so the engine can read it the way it reads a real lecture.
public enum SampleSlide {
    @MainActor
    public static func pdf() -> Data {
        let renderer = ImageRenderer(content: SineSlideArtwork().environment(\.colorScheme, .light))
        let data = NSMutableData()
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        return data as Data
    }
}
