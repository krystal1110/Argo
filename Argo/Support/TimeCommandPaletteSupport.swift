//
//  TimeCommandPaletteSupport.swift
//  Argo
//
//  Author: krystal
//

import Foundation

enum TimeCommandPalettePhase: Equatable {
    case morning
    case afternoon
    case sunset
    case night

    static func phase(forHour hour: Int) -> TimeCommandPalettePhase {
        let normalizedHour = ((hour % 24) + 24) % 24
        switch normalizedHour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<20:
            return .sunset
        default:
            return .night
        }
    }
}

enum TimeCommandPaletteClock {
    static func phase(for date: Date, calendar: Calendar = .current) -> TimeCommandPalettePhase {
        TimeCommandPalettePhase.phase(forHour: calendar.component(.hour, from: date))
    }

    static func timeText(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}
