import AppKit
import ImageIO
import SwiftUI

enum ArtworkImageFactory {
    /// MediaRemote / dosya verisinden mümkün olan en yüksek çözünürlüklü NSImage.
    static func make(from data: Data) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldAllowFloat: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return fallbackNSImage(from: data)
        }

        let count = CGImageSourceGetCount(source)
        var best: (CGImage, Int)?

        for index in 0..<count {
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let pixels = width * height

            let createOptions: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let cgImage = CGImageSourceCreateImageAtIndex(
                source,
                index,
                createOptions as CFDictionary
            ) else { continue }

            let score = max(pixels, cgImage.width * cgImage.height)
            if best == nil || score > best!.1 {
                best = (cgImage, score)
            }
        }

        guard let cgImage = best?.0 else {
            return fallbackNSImage(from: data)
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)
        image.isTemplate = false
        return image
    }

    static func pixelCount(of image: NSImage?) -> Int {
        guard let image else { return 0 }
        if let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).max(by: {
            $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh
        }) {
            return rep.pixelsWide * rep.pixelsHigh
        }
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg.width * cg.height
        }
        return Int(image.size.width * image.size.height)
    }

    private static func fallbackNSImage(from data: Data) -> NSImage? {
        guard let image = NSImage(data: data) else { return nil }
        if let rep = image.representations.first {
            let pixelSize = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            if pixelSize.width > 0, pixelSize.height > 0 {
                image.size = pixelSize
            }
        }
        return image
    }
}

/// Retina-aware, yüksek kaliteli kapak çizimi (SwiftUI Image downscale bulanıklığını aşar).
struct SharpArtworkView: NSViewRepresentable {
    var image: NSImage?
    var cgImage: CGImage?
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> ArtworkLayerView {
        let view = ArtworkLayerView()
        view.update(image: image, cgImage: cgImage, cornerRadius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: ArtworkLayerView, context: Context) {
        nsView.update(image: image, cgImage: cgImage, cornerRadius: cornerRadius)
    }
}

final class ArtworkLayerView: NSView {
    private let imageLayer = CALayer()
    private var sourceImage: NSImage?
    private var sourceCGImage: CGImage?
    private var appliedCorner: CGFloat = 0
    /// Son çizilen kaynak + piksel boyutu — animasyon sırasında her layout'ta
    /// yeniden rasterleştirip titremeyi önler.
    private var renderedKey: RenderKey?

    private struct RenderKey: Equatable {
        let image: ObjectIdentifier?
        let cgImage: ObjectIdentifier?
        /// Kaynağın çizildiği kısa kenar çözünürlüğü (64'e yuvarlanmış).
        let resolution: Int
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerUsesCoreImageFilters = false
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .trilinear
        imageLayer.allowsEdgeAntialiasing = true
        imageLayer.needsDisplayOnBoundsChange = false
        // SwiftUI offset/scale animasyonlarında CALayer'ın kendi örtük
        // animasyonu devreye girerse kare kayması (titreme) oluşuyor.
        imageLayer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "contents": NSNull()
        ]
        layer?.masksToBounds = true
        layer?.addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        imageLayer.contentsScale = scale
        layer?.contentsScale = scale
        CATransaction.commit()
        renderContents(scale: scale)
    }

    func update(image: NSImage?, cgImage: CGImage?, cornerRadius: CGFloat) {
        let imageChanged = sourceImage !== image || sourceCGImage !== cgImage
        sourceImage = image
        sourceCGImage = cgImage

        if appliedCorner != cornerRadius {
            appliedCorner = cornerRadius
            layer?.cornerRadius = cornerRadius
            layer?.cornerCurve = .continuous
            imageLayer.cornerRadius = cornerRadius
            imageLayer.cornerCurve = .continuous
            imageLayer.masksToBounds = true
        }

        // Aynı görsel tekrar gelirse yeniden çizme — swipe sırasında
        // saniyede onlarca kez rasterleştirme titremeye yol açıyordu.
        guard imageChanged else { return }
        renderedKey = nil
        needsLayout = true
    }

    /// Kırpma katmana (`resizeAspectFill`) bırakılır; bitmap kaynağın kendi
    /// en-boy oranında üretilir. Böylece görünüm 1:1'den 16:9'a doğru
    /// büyürken her karede yeniden rasterleştirme gerekmez ve şekil bozulmaz.
    private func renderContents(scale: CGFloat) {
        if let sourceCGImage {
            let key = RenderKey(image: nil, cgImage: ObjectIdentifier(sourceCGImage), resolution: 0)
            guard renderedKey != key else { return }
            renderedKey = key
            setContents(sourceCGImage)
            return
        }
        guard let sourceImage, bounds.width > 1, bounds.height > 1 else {
            renderedKey = nil
            setContents(nil)
            return
        }

        let needed = max(bounds.width, bounds.height) * scale
        let resolution = min(1_024, max(64, Int((needed / 64).rounded(.up)) * 64))
        let key = RenderKey(image: ObjectIdentifier(sourceImage), cgImage: nil, resolution: resolution)
        guard renderedKey != key else { return }
        renderedKey = key

        let imageSize = sourceImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let factor = CGFloat(resolution) / min(imageSize.width, imageSize.height)
        let pxW = max(1, Int((imageSize.width * factor).rounded()))
        let pxH = max(1, Int((imageSize.height * factor).rounded()))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxW,
            pixelsHigh: pxH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            setContents(sourceImage)
            return
        }
        rep.size = NSSize(width: pxW, height: pxH)
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .high
            ctx.shouldAntialias = true
            sourceImage.draw(
                in: NSRect(x: 0, y: 0, width: pxW, height: pxH),
                from: .zero,
                operation: .copy,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        setContents(rep.cgImage)
    }

    private func setContents(_ contents: Any?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = contents
        CATransaction.commit()
    }
}
