//
//  IslandClosedAgentsGrid.swift
//  Argo
//
//  Author: krystal
//

import SwiftUI

enum IslandGridCellState: Equatable {
    case running
    case idle
    case waiting

    init(phase: IslandSessionPhase) {
        if phase.requiresAttention {
            self = .waiting
        } else if phase == .running {
            self = .running
        } else {
            self = .idle
        }
    }
}

enum IslandGridCell: Equatable {
    case session(hexColor: String, state: IslandGridCellState)
    case overflow(Int)
}

enum IslandRightSlotContent: Equatable {
    case count(Int)
    case agents([IslandGridCell])
}

struct IslandRightSlotView: View {
    let content: IslandRightSlotContent

    var body: some View {
        switch content {
        case let .count(count):
            Text("×\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
        case let .agents(cells):
            IslandClosedAgentsGrid(cells: cells)
        }
    }

    static func balancedRows(_ count: Int) -> [Int] {
        switch count {
        case ..<1:
            []
        case 1:
            [1]
        case 2:
            [2]
        case 3:
            [3]
        case 4:
            [2, 2]
        case 5:
            [3, 2]
        case 6:
            [3, 3]
        case 7:
            [4, 3]
        case 8:
            [4, 4]
        case 9:
            [3, 3, 3]
        default:
            [4, 4]
        }
    }
}

struct IslandClosedAgentsGrid: View {
    let cells: [IslandGridCell]

    var body: some View {
        let rowSizes = IslandRightSlotView.balancedRows(cells.count)
        let rows = splitIntoRows(cells, rowSizes: rowSizes)
        VStack(spacing: rowSizes.count >= 3 ? 1.5 : 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: rowSizes.count >= 3 ? 1.5 : 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        IslandGridTile(cell: cell, size: rowSizes.count >= 3 ? 6 : 8)
                    }
                }
            }
        }
        .fixedSize()
    }

    private func splitIntoRows(_ cells: [IslandGridCell], rowSizes: [Int]) -> [[IslandGridCell]] {
        var output: [[IslandGridCell]] = []
        var index = 0
        for size in rowSizes {
            let end = min(index + size, cells.count)
            output.append(Array(cells[index..<end]))
            index = end
            if index >= cells.count { break }
        }
        return output
    }
}

private struct IslandGridTile: View {
    let cell: IslandGridCell
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        switch cell {
        case let .session(hexColor, state):
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(islandHex: hexColor) ?? .white)
                .frame(width: size, height: size)
                .opacity(opacity(for: state))
                .onAppear {
                    if state == .waiting {
                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                }
        case let .overflow(count):
            ZStack {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(.white.opacity(0.14))
                Text("+\(count)")
                    .font(.system(size: max(5, size * 0.55), weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }

    private func opacity(for state: IslandGridCellState) -> Double {
        switch state {
        case .running:
            1
        case .idle:
            0.22
        case .waiting:
            pulse ? 1 : 0.35
        }
    }
}

private extension Color {
    init?(islandHex hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
