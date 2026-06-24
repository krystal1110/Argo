//
//  ArgoTheme.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

enum ArgoTheme {
    static let twilightDefault = TwilightTheme.default
    static let amber = twilightDefault.amber.color
    static let amber2 = twilightDefault.amber2.color
    static let cyan = twilightDefault.cyan.color
    static let green = twilightDefault.green.color
    static let magenta = twilightDefault.magenta.color
    static let text = Color(nsColor: NSColor(calibratedRed: 0.953, green: 0.961, blue: 0.984, alpha: 1))
    static let textDim = Color(nsColor: NSColor(calibratedRed: 0.784, green: 0.812, blue: 0.875, alpha: 1))
    static let textFaint = Color(nsColor: NSColor(calibratedRed: 0.588, green: 0.616, blue: 0.698, alpha: 1))
    static let glassSide = Color(nsColor: NSColor(calibratedRed: 0.063, green: 0.086, blue: 0.133, alpha: 0.42))
    static let glassRail = Color(nsColor: NSColor(calibratedRed: 0.039, green: 0.055, blue: 0.086, alpha: 0.38))
    static let glassCard = Color(nsColor: NSColor(calibratedRed: 0.141, green: 0.180, blue: 0.267, alpha: 0.42))
    static let glassCardH = Color(nsColor: NSColor(calibratedRed: 0.188, green: 0.243, blue: 0.353, alpha: 0.50))
    static let topGlass = Color(nsColor: NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.114, alpha: 0.34))
    static let hairline = Color.white.opacity(0.10)
    static let hairlineSoft = Color.white.opacity(0.06)
    static let scrimStrong = Color(nsColor: NSColor(calibratedRed: 0.031, green: 0.043, blue: 0.071, alpha: 0.62))
    static let scrimSoft = Color(nsColor: NSColor(calibratedRed: 0.031, green: 0.043, blue: 0.071, alpha: 0.22))

    static let appBackground = Color(nsColor: NSColor(calibratedRed: 0.045, green: 0.05, blue: 0.062, alpha: 1))
    static let canvasBackground = Color(nsColor: NSColor(calibratedRed: 0.05, green: 0.055, blue: 0.069, alpha: 1))
    static let panelBackground = Color(nsColor: NSColor(calibratedRed: 0.067, green: 0.073, blue: 0.089, alpha: 1))
    static let panelRaised = Color(nsColor: NSColor(calibratedRed: 0.074, green: 0.081, blue: 0.099, alpha: 1))
    static let chromeBackground = Color(nsColor: NSColor(calibratedRed: 0.056, green: 0.062, blue: 0.076, alpha: 0.96))
    static let sidebarBackground = Color(nsColor: NSColor(calibratedRed: 0.058, green: 0.064, blue: 0.079, alpha: 1))
    static let sidebarSearchBackground = Color(nsColor: NSColor(calibratedRed: 0.078, green: 0.085, blue: 0.102, alpha: 1))
    static let paneBackground = Color(nsColor: NSColor(calibratedRed: 0.061, green: 0.068, blue: 0.083, alpha: 1))
    static let paneHeaderBackground = Color(nsColor: NSColor(calibratedRed: 0.072, green: 0.078, blue: 0.094, alpha: 1))
    static let backdropBlue = Color(nsColor: NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.47, alpha: 0.18))
    static let backdropTeal = Color(nsColor: NSColor(calibratedRed: 0.11, green: 0.39, blue: 0.34, alpha: 0.14))
    static let border = hairline.opacity(0.85)
    static let strongBorder = Color.white.opacity(0.16)
    static let accent = amber
    static let accentMuted = amber.opacity(0.24)
    static let localAccent = cyan
    static let success = green
    static let warning = amber2
    static let danger = Color(nsColor: NSColor(calibratedRed: 0.92, green: 0.38, blue: 0.36, alpha: 1))
    static let mutedText = textFaint
    static let secondaryText = textDim
    static let tertiaryText = text
    static let subtleFill = glassCard.opacity(0.75)
    static let subtleRaisedFill = glassCardH.opacity(0.80)

    static let sidebarSelectionFill = NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.24, alpha: 1)
    static let sidebarSelectionStroke = NSColor(calibratedRed: 0.26, green: 0.45, blue: 0.78, alpha: 0.92)
    static let sidebarHoverFill = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.16, alpha: 1)
    static let dividerColor = NSColor(calibratedWhite: 1, alpha: 0.08)

    static var accentHexForTests: String { twilightDefault.ghostty.accent }
    static var localAccentHexForTests: String { twilightDefault.ghostty.palette[6]! }
}
