import AppKit
import SwiftUI

struct TwilightWallpaperView: View {
    let preset: TwilightWallpaperPreset
    let customImagePath: String?

    init(preset: TwilightWallpaperPreset, customImagePath: String?) {
        self.preset = preset
        self.customImagePath = customImagePath
    }

    init(theme: TwilightTheme) {
        self.init(preset: .desk, customImagePath: nil)
    }

    private var customImageURL: URL? {
        customImagePath.map(URL.init(fileURLWithPath:))
    }

    var body: some View {
        ZStack {
            wallpaperImage
                .overlay(darkeningLayers)
                .overlay(lightAndVignetteLayers)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var wallpaperImage: some View {
        if let customImageURL,
           let nsImage = NSImage(contentsOf: customImageURL) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            AsyncImage(url: preset.remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    fallbackWallpaper
                @unknown default:
                    fallbackWallpaper
                }
            }
        }
    }

    private var fallbackWallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.149, green: 0.196, blue: 0.267, alpha: 1)),
                    Color(nsColor: NSColor(calibratedRed: 0.110, green: 0.141, blue: 0.196, alpha: 1)),
                    Color(nsColor: NSColor(calibratedRed: 0.067, green: 0.090, blue: 0.125, alpha: 1)),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.365, green: 0.435, blue: 0.541, alpha: 0.36)),
                    .clear,
                ],
                center: UnitPoint(x: 0.78, y: 0.22),
                startRadius: 0,
                endRadius: 720
            )
            RadialGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.306, green: 0.243, blue: 0.424, alpha: 0.30)),
                    .clear,
                ],
                center: UnitPoint(x: 0.18, y: 0.76),
                startRadius: 0,
                endRadius: 620
            )
        }
    }

    private var darkeningLayers: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.24)),
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.48)),
                ],
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.18)),
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.46)),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    private var lightAndVignetteLayers: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.white.opacity(0.04), location: 0.46),
                    .init(color: .clear, location: 0.62),
                ],
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.52),
                    .init(color: Color.black.opacity(0.32), location: 1),
                ],
                center: .center,
                startRadius: 0,
                endRadius: 900
            )
        }
        .accessibilityHidden(true)
        // Source markers: linear-gradient(115deg) and radial-gradient(120% 92%) from preview.html.
    }
}
