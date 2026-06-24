import SwiftUI

struct TwilightWallpaperView: View {
    let theme: TwilightTheme

    var body: some View {
        ZStack {
            LinearGradient(
                stops: theme.wallpaper.skyWaterStops.map {
                    Gradient.Stop(color: $0.color.color, location: $0.location)
                },
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                stops: [
                    .init(color: theme.wallpaper.sunGlow.color.color(alpha: theme.wallpaper.sunGlow.alpha), location: 0),
                    .init(color: .clear, location: theme.wallpaper.sunGlow.transparentStop),
                ],
                center: UnitPoint(x: 0.84, y: 0.66),
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                stops: [
                    .init(color: theme.wallpaper.sunCore.color.color(alpha: theme.wallpaper.sunCore.alpha), location: 0),
                    .init(color: .clear, location: theme.wallpaper.sunCore.transparentStop),
                ],
                center: UnitPoint(x: 0.82, y: 0.64),
                startRadius: 0,
                endRadius: 210
            )

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .mask(alignment: .top) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle().frame(height: 28)
                    Spacer(minLength: 0)
                }
            }
        }
        .ignoresSafeArea()
    }
}
