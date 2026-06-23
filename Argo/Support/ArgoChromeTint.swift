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
        top: 0.20,
        leading: 0.16,
        sidebar: 0.07,
        tabBar: 0.17,
        selection: 0.21,
        glow: 0.10
    )

    private static let neutralStrength = Strength(
        top: 0.11,
        leading: 0.09,
        sidebar: 0.035,
        tabBar: 0.095,
        selection: 0.13,
        glow: 0.045
    )

    var components: Components
    var strength: Strength
    var isNeutral: Bool

    var topFill: Fill { Fill(components: components, alpha: strength.top) }
    var leadingFill: Fill { Fill(components: components, alpha: strength.leading) }
    var sidebarFill: Fill { Fill(components: components, alpha: strength.sidebar) }
    var tabBarFill: Fill { Fill(components: components, alpha: strength.tabBar) }
    var selectionFill: Fill { Fill(components: components, alpha: strength.selection) }
    var glowFill: Fill { Fill(components: components, alpha: strength.glow) }

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
