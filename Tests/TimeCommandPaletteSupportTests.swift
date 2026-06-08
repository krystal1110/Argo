//
//  TimeCommandPaletteSupportTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class TimeCommandPaletteSupportTests: XCTestCase {
    func testPhaseUsesMorningAfternoonSunsetAndNightFallbackRanges() {
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 5), .morning)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 11), .morning)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 12), .afternoon)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 16), .afternoon)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 17), .sunset)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 19), .sunset)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 20), .night)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 4), .night)
    }

    func testPhaseNormalizesOutOfRangeHours() {
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 29), .morning)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: -1), .night)
    }

    func testTimeTextUsesTwoDigitTwentyFourHourClock() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 8,
            hour: 9,
            minute: 4
        ).date)

        XCTAssertEqual(TimeCommandPaletteClock.timeText(for: date, calendar: calendar), "09:04")
    }

    func testPhaseUsesCalendarHourFromDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 8,
            hour: 18,
            minute: 48
        ).date)

        XCTAssertEqual(TimeCommandPaletteClock.phase(for: date, calendar: calendar), .sunset)
    }
}
