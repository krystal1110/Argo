//
//  PaneSplitSizing.swift
//  Argo
//
//  Author: krystal
//

import CoreGraphics

enum PaneSplitSizing {
    static let defaultFraction = 0.5
    static let minimumFraction = 0.12
    static let maximumFraction = 0.88

    struct Lengths: Equatable {
        var first: CGFloat
        var second: CGFloat
        var available: CGFloat
    }

    static func clampedFraction(_ fraction: Double) -> Double {
        guard fraction.isFinite else {
            return defaultFraction
        }
        return min(max(fraction, minimumFraction), maximumFraction)
    }

    static func fraction(
        startingAt startFraction: Double,
        translation: CGFloat,
        availableLength: CGFloat
    ) -> Double {
        let delta = Double(translation / max(availableLength, 1))
        return clampedFraction(startFraction + delta)
    }

    static func lengths(
        totalLength: CGFloat,
        dividerThickness: CGFloat,
        fraction: Double,
        minimumFirst: CGFloat,
        minimumSecond: CGFloat
    ) -> Lengths {
        let available = max(totalLength - dividerThickness, 0)
        guard available > 0 else {
            return Lengths(first: 0, second: 0, available: 0)
        }

        let clamped = CGFloat(clampedFraction(fraction))

        guard available >= minimumFirst + minimumSecond else {
            let first = available * clamped
            return Lengths(
                first: first,
                second: max(available - first, 0),
                available: available
            )
        }

        let desiredFirst = available * clamped
        let first = min(max(desiredFirst, minimumFirst), available - minimumSecond)
        return Lengths(
            first: first,
            second: max(available - first, 0),
            available: available
        )
    }
}
