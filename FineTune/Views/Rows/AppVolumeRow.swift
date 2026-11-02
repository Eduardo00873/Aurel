// FineTune/Views/Rows/AppVolumeRow.swift
import SwiftUI

/// Per-app row: icon, name and output on top, a full-width volume slider with an
/// integrated mute button below. The percentage only appears while interacting.
struct AppVolumeRow<Output: View>: View {
    let icon: NSImage
    let name: String
    let volume: Float  // Linear gain 0-1
    let isMuted: Bool
    var isInactive: Bool = false
    var isFocused: Bool = false
    let onVolumeChange: (Float) -> Void
    let onMuteChange: (Bool) -> Void
    var onIconTap: (() -> Void)? = nil
    @ViewBuilder let output: () -> Output

    @State private var dragOverrideValue: Double?
    @State private var isHovered = false
    @State private var isSliderEditing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sliderValue: Double {
        dragOverrideValue ?? VolumeMapping.gainToSlider(volume)
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { sliderValue },
            set: { newValue in
                dragOverrideValue = newValue
                onVolumeChange(VolumeMapping.sliderToGain(newValue))
                if isMuted {
                    onMuteChange(false)
                }
            }
        )
    }

    private var displayedPercentage: Int { Int(round(sliderValue * 100)) }

    /// Muted OR displayed 0% — the x² mapping can leave tiny non-zero slider values.
    private var showMutedIcon: Bool { isMuted || displayedPercentage == 0 }

    private var showsPercentage: Bool { isHovered || isSliderEditing || isFocused }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                appIcon
                Text(name)
                    .font(DesignTokens.Typography.itemName)
                    .foregroundStyle(isInactive ? DesignTokens.Palette.textSecondary : DesignTokens.Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: DesignTokens.Spacing.xs)
                EditablePercentage(
                    percentage: Binding(
                        get: { displayedPercentage },
                        set: { onVolumeChange(VolumeMapping.sliderToGain(Double($0) / 100.0)) }
                    ),
                    range: 0...100,
                    isRowFocused: isFocused
                )
                .opacity(showsPercentage ? 1 : 0)
                .allowsHitTesting(showsPercentage)
                output()
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                LiquidGlassSlider(
                    value: sliderBinding,
                    showUnityMarker: false,
                    onEditingChanged: { editing in
                        isSliderEditing = editing
                        if !editing {
                            dragOverrideValue = nil
                        }
                    }
                )
                .opacity(showMutedIcon ? 0.45 : 1)
                .scrollWheelStep(sliderBinding, in: 0.0...1.0)

                MuteButton(isMuted: showMutedIcon, levelFraction: sliderValue) {
                    if showMutedIcon {
                        if displayedPercentage == 0 {
                            onVolumeChange(1.0)
                        }
                        onMuteChange(false)
                    } else {
                        onMuteChange(true)
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(isFocused ? DesignTokens.Colors.hoverSurface : .clear)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: showsPercentage)
        .animation(reduceMotion ? nil : DesignTokens.Animation.quick, value: showMutedIcon)
    }

    @ViewBuilder
    private var appIcon: some View {
        let image = Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: 20, height: 20)
            .saturation(isInactive ? 0 : 1)
            .opacity(isInactive ? 0.6 : 1)
        if let onIconTap {
            Button(action: onIconTap) { image }
                .buttonStyle(.plain)
                .help("Bring \(name) to the front")
        } else {
            image
        }
    }
}
