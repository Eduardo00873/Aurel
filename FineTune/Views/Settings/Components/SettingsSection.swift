// FineTune/Views/Settings/Components/SettingsSection.swift
import SwiftUI

@MainActor
struct SettingsSection<Content: View>: View {
    private let title: String?
    @ViewBuilder private let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let title {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(DesignTokens.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                    .strokeBorder(DesignTokens.Palette.border, lineWidth: 0.5)
            }
        }
    }
}
