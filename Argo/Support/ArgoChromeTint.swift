//
//  ArgoChromeTint.swift
//  Argo
//

import AppKit
import SwiftUI

struct ArgoChromeTint: Equatable {
    struct Components: Equatable {
        var red: Double
        var green: Double
        var blue: Double

        var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue)
        }

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(color: Color) {
            let resolved = NSColor(color).usingColorSpace(.sRGB)
                ?? NSColor.systemBlue.usingColorSpace(.sRGB)
                ?? NSColor(calibratedRed: 0.25, green: 0.54, blue: 0.98, alpha: 1)
            self.init(
                red: Double(resolved.redComponent),
                green: Double(resolved.greenComponent),
                blue: Double(resolved.blueComponent)
            )
        }
    }

    struct Fill: Equatable {
        var components: Components
        var alpha: Double

        var color: Color {
            components.color.opacity(alpha)
        }
    }

    struct Strength: Equatable {
        var top: Double
        var leading: Double
        var sidebar: Double
        var tabBar: Double
        var selection: Double
        var glow: Double
    }

    static let defaultAccentComponents = Components(red: 0.25, green: 0.54, blue: 0.98)

    private static let balancedStrength = Strength(
        top: 0.30,
        leading: 0.28,
        sidebar: 0.16,
        tabBar: 0.28,
        selection: 0.30,
        glow: 0.20
    )

    private static let neutralStrength = Strength(
        top: 0.18,
        leading: 0.16,
        sidebar: 0.08,
        tabBar: 0.16,
        selection: 0.18,
        glow: 0.09
    )

    private static let topChromeSurfaceBase = Components(red: 0.29, green: 0.30, blue: 0.31)
    private static let topChromeSurfaceLift = 0.02

    var components: Components
    var strength: Strength
    var isNeutral: Bool

    var topFill: Fill { Fill(components: components, alpha: strength.top) }
    var leadingFill: Fill { Fill(components: components, alpha: strength.leading) }
    var sidebarFill: Fill { Fill(components: components, alpha: strength.sidebar) }
    var tabBarFill: Fill { Fill(components: components, alpha: strength.tabBar) }
    var selectionFill: Fill { Fill(components: components, alpha: strength.selection) }
    var glowFill: Fill { Fill(components: components, alpha: strength.glow) }
    var topChromeSurfaceComponents: Components {
        let tintWeight = isNeutral ? 0.08 : 0.18
        let baseWeight = 1 - tintWeight
        let base = Self.topChromeSurfaceBase
        let lift = Self.topChromeSurfaceLift

        return Components(
            red: min(1, base.red * baseWeight + components.red * tintWeight + lift),
            green: min(1, base.green * baseWeight + components.green * tintWeight + lift),
            blue: min(1, base.blue * baseWeight + components.blue * tintWeight + lift)
        )
    }

    static var fallback: ArgoChromeTint {
        ArgoChromeTint(
            components: defaultAccentComponents,
            strength: balancedStrength,
            isNeutral: false
        )
    }

    static func resolved(for palette: SidebarIconPalette?) -> ArgoChromeTint {
        guard let palette else { return fallback }
        let isNeutral = neutralPalettes.contains(palette)
        let descriptor = palette.descriptor
        return ArgoChromeTint(
            components: Components(color: isNeutral ? descriptor.border : descriptor.gradientEnd),
            strength: isNeutral ? neutralStrength : balancedStrength,
            isNeutral: isNeutral
        )
    }

    private static let neutralPalettes: Set<SidebarIconPalette> = [
        .slate,
        .smoke,
        .charcoal,
        .graphite,
        .mocha,
    ]
}
