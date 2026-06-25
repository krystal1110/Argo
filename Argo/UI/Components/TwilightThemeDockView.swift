//
//  TwilightThemeDockView.swift
//  Argo
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TwilightThemeDockView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject private var localization = LocalizationManager.shared

    let surfacePalette: TwilightSurfacePalette
    let opacity: TwilightOpacityModel

    @State private var seedDraft = TwilightTheme.defaultSeedHex
    @State private var seedHasError = false
    @State private var toastFileName: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 10) {
                dockLabel("预设")

                ForEach(TwilightTheme.presets) { preset in
                    Button {
                        seedDraft = preset.seedHex
                        seedHasError = false
                        store.setTwilightSeedHex(preset.seedHex)
                    } label: {
                        TwilightThemeSwatch(
                            seedHex: preset.seedHex,
                            isSelected: store.appSettings.twilightThemeSeedHex == preset.seedHex
                        )
                    }
                    .buttonStyle(.plain)
                    .help(localization.string(preset.nameKey))
                }

                divider
                dockLabel("图片")

                ForEach(TwilightWallpaperPreset.allCases) { preset in
                    Button {
                        store.setTwilightWallpaperPreset(preset)
                    } label: {
                        TwilightWallpaperSwatch(
                            preset: preset,
                            isSelected: store.appSettings.twilightWallpaperPreset == preset && store.appSettings.twilightCustomWallpaperPath == nil
                        )
                    }
                    .buttonStyle(.plain)
                    .help(preset.label)
                }

                Button {
                    chooseCustomWallpaper()
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(opacity.softFillAlpha), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.13), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(ArgoTheme.textDim)
                .help("本地图片")

                divider

                Slider(
                    value: Binding(
                        get: { Double(store.appSettings.twilightOpacityPercent) },
                        set: { store.setTwilightOpacityPercent(Int($0.rounded())) }
                    ),
                    in: 0...100,
                    step: 1
                )
                .frame(width: 92)

                Text("\(store.appSettings.twilightOpacityPercent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ArgoTheme.textDim)
                    .frame(width: 34, alignment: .trailing)

                divider

                ColorPicker(
                    "",
                    selection: Binding(
                        get: { store.currentTwilightTheme.amber.color },
                        set: { color in
                            if let hex = color.twilightHexString {
                                seedDraft = hex
                                seedHasError = false
                                store.setTwilightSeedHex(hex)
                            }
                        }
                    )
                )
                .labelsHidden()
                .frame(width: 26, height: 26)

                TextField(
                    "#cba6f7",
                    text: Binding(
                        get: { seedDraft },
                        set: { value in
                            seedDraft = value.lowercased()
                            guard let normalized = TwilightTheme.validSeedHex(value) else {
                                seedHasError = true
                                return
                            }
                            seedHasError = false
                            store.setTwilightSeedHex(normalized)
                        }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 72, height: 26)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(opacity.softFillAlpha), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(seedHasError ? ArgoTheme.danger.opacity(0.9) : ArgoTheme.hairline, lineWidth: 1)
                )

                Button {
                    exportWarp()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Warp")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(height: 30)
                    .padding(.horizontal, 13)
                    .background(store.currentTwilightTheme.amber.color.opacity(0.90), in: Capsule())
                    .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.102, green: 0.071, blue: 0.031, alpha: 1)))
                }
                .buttonStyle(.plain)
                .help("导出 Warp 主题")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(surfacePalette.color(\.dock, alpha: opacity.dockAlpha), in: Capsule())
            .overlay(Capsule().stroke(ArgoTheme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.50), radius: 20, y: 12)

            if let toastFileName {
                TwilightToastView(
                    fileName: toastFileName,
                    surfacePalette: surfacePalette,
                    opacity: opacity
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            seedDraft = store.appSettings.twilightThemeSeedHex
        }
        .onChange(of: store.appSettings.twilightThemeSeedHex) { _, newValue in
            if !seedHasError {
                seedDraft = newValue
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(ArgoTheme.hairlineSoft)
            .frame(width: 1, height: 20)
    }

    private func dockLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(ArgoTheme.textFaint)
    }

    private func chooseCustomWallpaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.setTwilightCustomWallpaper(url: url)
        } catch {
            store.presentedError = PresentedError(title: "Wallpaper", message: error.localizedDescription)
        }
    }

    private func exportWarp() {
        do {
            let url = try store.exportCurrentTwilightWarpTheme()
            toastFileName = url.lastPathComponent
            toastTask?.cancel()
            toastTask = Task {
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                await MainActor.run {
                    toastFileName = nil
                }
            }
        } catch {
            store.presentedError = PresentedError(title: "Warp", message: error.localizedDescription)
        }
    }
}

private struct TwilightThemeSwatch: View {
    let seedHex: String
    let isSelected: Bool

    var body: some View {
        let hsl = TwilightHSLColor.hexToHSL(seedHex)

        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor(twilightHex: seedHex) ?? .white),
                        TwilightHSLColor(
                            hue: hsl.hue,
                            saturation: TwilightTheme.clamp(hsl.saturation, 40, 90),
                            lightness: 34
                        ).color,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 24, height: 24)
            .overlay(Circle().stroke(isSelected ? Color.white : ArgoTheme.hairline, lineWidth: isSelected ? 2 : 1))
    }
}

private struct TwilightWallpaperSwatch: View {
    let preset: TwilightWallpaperPreset
    let isSelected: Bool

    var body: some View {
        AsyncImage(url: preset.remoteURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ArgoTheme.glassCard)
            }
        }
        .frame(width: 34, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
        )
    }
}

private struct TwilightToastView: View {
    let fileName: String
    let surfacePalette: TwilightSurfacePalette
    let opacity: TwilightOpacityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("已导出 \(fileName)")
            Text("mv ~/Downloads/\(fileName) ~/.warp/themes/")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(ArgoTheme.textFaint)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(ArgoTheme.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: 380, alignment: .leading)
        .background(surfacePalette.color(\.toast, alpha: opacity.toastAlpha), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(ArgoTheme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
    }
}

private extension NSColor {
    convenience init?(twilightHex hex: String) {
        guard let normalized = TwilightTheme.validSeedHex(hex),
              let value = UInt64(normalized.dropFirst(), radix: 16) else {
            return nil
        }

        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    var twilightHexString: String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let red = Int((nsColor.redComponent * 255).rounded())
        let green = Int((nsColor.greenComponent * 255).rounded())
        let blue = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", red, green, blue)
    }
}
