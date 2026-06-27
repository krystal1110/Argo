//
//  SidebarIconActivityColorResolver.swift
//  Argo
//

import SwiftUI

enum SidebarIconActivityColorResolver {
    static func activityColor(
        twilightTheme: TwilightTheme?,
        fallbackPalette: SidebarIconPalette
    ) -> Color {
        if let twilightTheme {
            return ArgoChromeTint.resolved(for: twilightTheme).components.color
        }
        return fallbackPalette.descriptor.gradientEnd
    }
}
