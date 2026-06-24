//
//  TwilightTheme.swift
//  Argo
//

import AppKit
import SwiftUI

struct TwilightTheme: Equatable {
    struct Preset: Identifiable, Equatable {
        let id: String
        let nameKey: String
        let seedHex: String
    }

    static let defaultSeedHex = "#ffb066"

    static let presets: [Preset] = [
        Preset(id: "twilight", nameKey: "settings.twilight.preset.twilight", seedHex: "#ffb066"),
        Preset(id: "aurora", nameKey: "settings.twilight.preset.aurora", seedHex: "#7af0c0"),
        Preset(id: "abyss", nameKey: "settings.twilight.preset.abyss", seedHex: "#5cc8ff"),
        Preset(id: "sakura", nameKey: "settings.twilight.preset.sakura", seedHex: "#ff9ec4"),
        Preset(id: "ember", nameKey: "settings.twilight.preset.ember", seedHex: "#ff7a59"),
    ]

    let seedHex: String
    let amber: TwilightHSLColor
    let amber2: TwilightHSLColor
    let cyan: TwilightHSLColor
    let green: TwilightHSLColor
    let magenta: TwilightHSLColor
    let wallpaper: TwilightWallpaper
    let ghostty: TwilightGhosttyTheme

    static var `default`: TwilightTheme {
        generate(seed: defaultSeedHex)
    }

    static func generate(seed: String) -> TwilightTheme {
        let normalizedSeed = normalizedSeedHex(seed)
        let source = TwilightHSLColor.hexToHSL(normalizedSeed)
        let h = source.hue
        let s = source.saturation
        let l = source.lightness
        let S = clamp(s, 42, 96)

        let amber = TwilightHSLColor(hue: h, saturation: S, lightness: clamp(l, 58, 70))
        let amber2 = TwilightHSLColor(hue: h, saturation: clamp(S - 12, 40, 88), lightness: clamp(l + 15, 72, 86))
        let cyan = TwilightHSLColor(hue: h + 168, saturation: clamp(S - 6, 46, 82), lightness: 70)
        let green = TwilightHSLColor(hue: h + 96, saturation: clamp(S - 12, 40, 76), lightness: 69)
        let magenta = TwilightHSLColor(hue: h - 46, saturation: clamp(S - 4, 46, 82), lightness: 72)

        let skyH = lerpHue(h, 250, 0.72)
        let waterH = lerpHue(h, 218, 0.78)
        let sunS = clamp(S + 4, 55, 98)

        let wallpaper = TwilightWallpaper(
            sunCore: TwilightRadialStop(
                widthPercent: 28,
                heightPercent: 36,
                centerXPercent: 82,
                centerYPercent: 64,
                color: TwilightHSLColor(hue: h, saturation: clamp(S - 18, 30, 70), lightness: 92),
                alpha: 0.95,
                transparentStop: 0.62
            ),
            sunGlow: TwilightRadialStop(
                widthPercent: 72,
                heightPercent: 58,
                centerXPercent: 84,
                centerYPercent: 66,
                color: TwilightHSLColor(hue: h, saturation: sunS, lightness: 62),
                alpha: 0.72,
                transparentStop: 0.68
            ),
            skyWaterStops: [
                TwilightLinearStop(color: TwilightHSLColor(hue: skyH, saturation: clamp(S * 0.5, 18, 55), lightness: 16), location: 0),
                TwilightLinearStop(color: TwilightHSLColor(hue: skyH - 12, saturation: clamp(S * 0.55, 20, 58), lightness: 24), location: 0.20),
                TwilightLinearStop(color: TwilightHSLColor(hue: lerpHue(h, skyH, 0.5), saturation: clamp(S * 0.6, 28, 66), lightness: 40), location: 0.40),
                TwilightLinearStop(color: TwilightHSLColor(hue: h, saturation: clamp(sunS * 0.82, 45, 92), lightness: 54), location: 0.56),
                TwilightLinearStop(color: TwilightHSLColor(hue: lerpHue(h, waterH, 0.5), saturation: clamp(S * 0.55, 26, 64), lightness: 38), location: 0.64),
                TwilightLinearStop(color: TwilightHSLColor(hue: waterH, saturation: clamp(S * 0.5, 24, 58), lightness: 26), location: 0.76),
                TwilightLinearStop(color: TwilightHSLColor(hue: waterH + 4, saturation: clamp(S * 0.52, 24, 60), lightness: 18), location: 0.88),
                TwilightLinearStop(color: TwilightHSLColor(hue: waterH + 6, saturation: clamp(S * 0.5, 22, 58), lightness: 12), location: 1),
            ]
        )

        let semanticSaturation = clamp(S - 6, 48, 78)
        let normal = TwilightGhosttyTheme.SemanticColors(
            black: TwilightHSLColor(hue: waterH, saturation: clamp(S * 0.4, 14, 40), lightness: 18),
            red: TwilightHSLColor(hue: lerpHue(358, h, 0.12), saturation: semanticSaturation, lightness: 64),
            green: TwilightHSLColor(hue: lerpHue(138, h, 0.12), saturation: semanticSaturation, lightness: 56),
            yellow: amber,
            blue: TwilightHSLColor(hue: lerpHue(210, h, 0.12), saturation: semanticSaturation, lightness: 64),
            magenta: TwilightHSLColor(hue: lerpHue(305, h, 0.12), saturation: semanticSaturation, lightness: 68),
            cyan: TwilightHSLColor(hue: lerpHue(182, h, 0.12), saturation: semanticSaturation, lightness: 62),
            white: TwilightHSLColor(hue: h, saturation: 10, lightness: 82)
        )
        let bright = TwilightGhosttyTheme.SemanticColors(
            black: TwilightHSLColor(hue: waterH, saturation: clamp(S * 0.3, 10, 34), lightness: 40),
            red: TwilightHSLColor(hue: lerpHue(358, h, 0.12), saturation: semanticSaturation, lightness: 74),
            green: TwilightHSLColor(hue: lerpHue(138, h, 0.12), saturation: semanticSaturation, lightness: 67),
            yellow: amber2,
            blue: TwilightHSLColor(hue: lerpHue(210, h, 0.12), saturation: semanticSaturation, lightness: 74),
            magenta: TwilightHSLColor(hue: lerpHue(305, h, 0.12), saturation: semanticSaturation, lightness: 78),
            cyan: TwilightHSLColor(hue: lerpHue(182, h, 0.12), saturation: semanticSaturation, lightness: 72),
            white: TwilightHSLColor(hue: h, saturation: 8, lightness: 96)
        )

        return TwilightTheme(
            seedHex: normalizedSeed,
            amber: amber,
            amber2: amber2,
            cyan: cyan,
            green: green,
            magenta: magenta,
            wallpaper: wallpaper,
            ghostty: TwilightGhosttyTheme(
                accentColor: amber,
                backgroundColor: TwilightHSLColor(hue: waterH + 4, saturation: clamp(S * 0.45, 18, 46), lightness: 9),
                foregroundColor: TwilightHSLColor(hue: h, saturation: 12, lightness: 94),
                normal: normal,
                bright: bright
            )
        )
    }

    static func normalizedSeedHex(_ seed: String?) -> String {
        validSeedHex(seed) ?? defaultSeedHex
    }

    static func validSeedHex(_ seed: String?) -> String? {
        guard var hex = seed?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !hex.isEmpty else {
            return nil
        }
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6, UInt64(hex, radix: 16) != nil else {
            return nil
        }
        return "#\(hex)"
    }

    static func isValidSeedHex(_ seed: String) -> Bool {
        validSeedHex(seed) != nil
    }

    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        max(lower, min(upper, value))
    }

    static func lerpHue(_ a: Double, _ b: Double, _ t: Double) -> Double {
        let delta = (b - a + 540).truncatingRemainder(dividingBy: 360) - 180
        return a + delta * t
    }
}

struct TwilightHSLColor: Equatable {
    let hue: Double
    let saturation: Double
    let lightness: Double

    var normalizedHue: Double {
        Self.normalizedHue(hue)
    }

    var hex: String {
        Self.hslToHex(hue: hue, saturation: saturation, lightness: lightness)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        let rgb = Self.hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
        return NSColor(calibratedRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }

    func color(alpha: Double) -> Color {
        color.opacity(alpha)
    }

    static func hexToHSL(_ hex: String) -> TwilightHSLColor {
        let normalized = TwilightTheme.normalizedSeedHex(hex).dropFirst()
        let value = UInt64(normalized, radix: 16)!
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255

        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        var hue = 0.0
        if delta != 0 {
            if maximum == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maximum == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue *= 60
            if hue < 0 {
                hue += 360
            }
        }

        let lightness = (maximum + minimum) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        return TwilightHSLColor(hue: hue, saturation: saturation * 100, lightness: lightness * 100)
    }

    static func hslToHex(hue: Double, saturation: Double, lightness: Double) -> String {
        let rgb = hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
        let red = Int((rgb.red * 255).rounded())
        let green = Int((rgb.green * 255).rounded())
        let blue = Int((rgb.blue * 255).rounded())
        return String(format: "#%02x%02x%02x", red, green, blue)
    }

    static func hslToRGB(hue: Double, saturation: Double, lightness: Double) -> (red: Double, green: Double, blue: Double) {
        let h = normalizedHue(hue)
        let s = TwilightTheme.clamp(saturation, 0, 100) / 100
        let l = TwilightTheme.clamp(lightness, 0, 100) / 100
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let rgb: (Double, Double, Double)

        switch h {
        case 0..<60:
            rgb = (c, x, 0)
        case 60..<120:
            rgb = (x, c, 0)
        case 120..<180:
            rgb = (0, c, x)
        case 180..<240:
            rgb = (0, x, c)
        case 240..<300:
            rgb = (x, 0, c)
        default:
            rgb = (c, 0, x)
        }

        return (rgb.0 + m, rgb.1 + m, rgb.2 + m)
    }

    private static func normalizedHue(_ hue: Double) -> Double {
        let value = hue.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}

struct TwilightLinearStop: Equatable {
    let color: TwilightHSLColor
    let location: Double
}

struct TwilightRadialStop: Equatable {
    let widthPercent: Double
    let heightPercent: Double
    let centerXPercent: Double
    let centerYPercent: Double
    let color: TwilightHSLColor
    let alpha: Double
    let transparentStop: Double
}

struct TwilightWallpaper: Equatable {
    let sunCore: TwilightRadialStop
    let sunGlow: TwilightRadialStop
    let skyWaterStops: [TwilightLinearStop]
}

struct TwilightGhosttyTheme: Equatable {
    struct SemanticColors: Equatable {
        let black: TwilightHSLColor
        let red: TwilightHSLColor
        let green: TwilightHSLColor
        let yellow: TwilightHSLColor
        let blue: TwilightHSLColor
        let magenta: TwilightHSLColor
        let cyan: TwilightHSLColor
        let white: TwilightHSLColor

        var ordered: [TwilightHSLColor] {
            [black, red, green, yellow, blue, magenta, cyan, white]
        }
    }

    let accentColor: TwilightHSLColor
    let backgroundColor: TwilightHSLColor
    let foregroundColor: TwilightHSLColor
    let normal: SemanticColors
    let bright: SemanticColors

    var accent: String { accentColor.hex }
    var background: String { backgroundColor.hex }
    var foreground: String { foregroundColor.hex }

    var palette: [Int: String] {
        Dictionary(uniqueKeysWithValues: (normal.ordered + bright.ordered).enumerated().map { index, color in
            (index, color.hex)
        })
    }

    var paletteLines: [String] {
        (0...15).map { index in
            "palette = \(index)=\(palette[index]!)"
        }
    }
}
