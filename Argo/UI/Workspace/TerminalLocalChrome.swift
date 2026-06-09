//
//  TerminalLocalChrome.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct TerminalChromeCategoryDescriptor: Identifiable, Equatable {
    let id: UUID
    let title: String
    let isSelected: Bool
    let canClose: Bool
}

struct TerminalLocalChrome: View {
    @ObservedObject private var localization = LocalizationManager.shared

    let path: String
    let categories: [TerminalChromeCategoryDescriptor]
    let activeCategoryID: UUID?
    let isFocused: Bool
    let canCreateCategory: Bool
    let canSplit: Bool
    let onSelectCategory: (UUID) -> Void
    let onCloseCategory: (UUID) -> Void
    let onRenameCategory: (UUID, String) -> Void
    let onCreateCategory: () -> Void
    let onSplitRight: () -> Void
    let onSplitDown: () -> Void

    @State private var editingCategoryID: UUID?
    @State private var renameDraft = ""

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        HStack(spacing: 12) {
            categoryArea

            HStack(spacing: 5) {
                TransparentPaneActionButton(
                    systemName: "plus",
                    isDisabled: !canCreateCategory,
                    accessibilityLabel: localized("terminal.category.new"),
                    help: localized("terminal.category.new"),
                    action: onCreateCategory
                )

                TransparentPaneActionButton(
                    systemName: "rectangle.split.2x1",
                    isDisabled: !canSplit,
                    accessibilityLabel: localized("menu.file.splitRight"),
                    help: localized("menu.file.splitRight"),
                    action: onSplitRight
                )

                TransparentPaneActionButton(
                    systemName: "rectangle.split.1x2",
                    isDisabled: !canSplit,
                    accessibilityLabel: localized("menu.file.splitDown"),
                    help: localized("menu.file.splitDown"),
                    action: onSplitDown
                )
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: activeCategoryID) { _, _ in
            cancelRename()
        }
    }

    @ViewBuilder
    private var categoryArea: some View {
        if categories.isEmpty {
            fallbackCategoryPill
        } else {
            categoryStrip
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { category in
                    TerminalChromeCategoryPill(
                        category: category,
                        isFocused: isFocused && category.isSelected,
                        renamePopoverBinding: renamePopoverBinding(for: category.id),
                        onSelect: {
                            onSelectCategory(category.id)
                        },
                        onRename: {
                            beginRename(category)
                        },
                        onClose: {
                            onCloseCategory(category.id)
                        },
                        renamePopover: {
                            TerminalChromeCategoryRenamePopover(
                                draft: $renameDraft,
                                onCommit: commitRename,
                                onCancel: cancelRename
                            )
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var fallbackCategoryPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(path)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.968, green: 0.976, blue: 0.988, alpha: 1)))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(pathFill(isSelected: true), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.235), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
        .layoutPriority(1)
    }

    private func renamePopoverBinding(for categoryID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                editingCategoryID == categoryID
            },
            set: { isPresented in
                if !isPresented, editingCategoryID == categoryID {
                    cancelRename()
                }
            }
        )
    }

    private func beginRename(_ category: TerminalChromeCategoryDescriptor) {
        renameDraft = category.title
        editingCategoryID = category.id
    }

    private func commitRename() {
        guard let editingCategoryID else {
            cancelRename()
            return
        }
        let normalized = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            onRenameCategory(editingCategoryID, normalized)
        }
        cancelRename()
    }

    private func cancelRename() {
        editingCategoryID = nil
        renameDraft = ""
    }

    private func pathFill(isSelected: Bool) -> some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(isSelected ? (isFocused ? 0.255 : 0.205) : 0.12),
                Color.white.opacity(isSelected ? (isFocused ? 0.145 : 0.105) : 0.055)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct TerminalChromeCategoryPill<RenamePopover: View>: View {
    let category: TerminalChromeCategoryDescriptor
    let isFocused: Bool
    let renamePopoverBinding: Binding<Bool>
    let onSelect: () -> Void
    let onRename: () -> Void
    let onClose: () -> Void
    @ViewBuilder let renamePopover: () -> RenamePopover

    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(category.isSelected ? 0.72 : 0.46))

                    Text(category.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if category.isSelected {
                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
                .foregroundStyle(Color.white.opacity(isHovered ? 0.76 : 0.48))
                .accessibilityLabel(Text(LocalizationManager.shared.string("terminal.category.rename")))
                .help(LocalizationManager.shared.string("terminal.category.rename"))
                .popover(isPresented: renamePopoverBinding) {
                    renamePopover()
                }
            }

            if category.canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(closeOpacity))
                .background(Color.white.opacity(isCloseHovered ? 0.14 : 0.06), in: Circle())
                .onHover { hovering in
                    isCloseHovered = hovering
                }
                .help(LocalizationManager.shared.string("terminal.category.close"))
            }
        }
        .padding(.horizontal, 12)
        .frame(width: category.isSelected ? 250 : 180, height: 32)
        .contentShape(Capsule())
        .background(backgroundFill, in: Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: category.isSelected ? 1 : 0.8))
        .shadow(color: .black.opacity(category.isSelected ? 0.07 : 0), radius: 8, y: 3)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(category.title)
    }

    private var foreground: Color {
        if category.isSelected {
            return Color(nsColor: NSColor(calibratedRed: 0.968, green: 0.976, blue: 0.988, alpha: 1))
        }
        return Color.white.opacity(isHovered ? 0.70 : 0.46)
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(category.isSelected ? (isFocused ? 0.255 : 0.205) : (isHovered ? 0.09 : 0.0)),
                Color.white.opacity(category.isSelected ? (isFocused ? 0.145 : 0.105) : (isHovered ? 0.045 : 0.0))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderColor: Color {
        if category.isSelected {
            return Color.white.opacity(0.235)
        }
        return Color.white.opacity(isHovered ? 0.10 : 0.0)
    }

    private var closeOpacity: Double {
        if isCloseHovered {
            return 0.92
        }
        if isHovered || category.isSelected {
            return 0.68
        }
        return 0.42
    }
}

private struct TerminalChromeCategoryRenamePopover: View {
    @Binding var draft: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    @State private var isCommitHovered = false
    @State private var isCancelHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizationManager.shared.string("terminal.category.rename"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))

            HStack(spacing: 8) {
                TextField(LocalizationManager.shared.string("main.tab.namePlaceholder"), text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.white.opacity(0.095), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .onSubmit(onCommit)

                Button(action: onCommit) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(isCommitHovered ? 0.96 : 0.72))
                .background(Color.white.opacity(isCommitHovered ? 0.16 : 0.08), in: Circle())
                .accessibilityLabel(Text(LocalizationManager.shared.string("common.ok")))
                .help(LocalizationManager.shared.string("common.ok"))
                .onHover { hovering in
                    isCommitHovered = hovering
                }

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(isCancelHovered ? 0.90 : 0.58))
                .background(Color.white.opacity(isCancelHovered ? 0.14 : 0.06), in: Circle())
                .accessibilityLabel(Text(LocalizationManager.shared.string("common.cancel")))
                .help(LocalizationManager.shared.string("common.cancel"))
                .onHover { hovering in
                    isCancelHovered = hovering
                }
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct TransparentPaneActionButton: View {
    let systemName: String
    var isDisabled = false
    let accessibilityLabel: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: isDisabled ? .regular : .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.white.opacity(isDisabled ? 0.32 : 0.88))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}
