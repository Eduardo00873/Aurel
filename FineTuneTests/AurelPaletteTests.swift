// FineTuneTests/AurelPaletteTests.swift
import Testing
import SwiftUI
import AppKit
@testable import FineTune

@Suite("DesignTokens — Aurel palette")
@MainActor
struct AurelPaletteTests {
    private static let aqua = NSAppearance(named: .aqua)!
    private static let darkAqua = NSAppearance(named: .darkAqua)!

    private func hex(_ color: Color, in appearance: NSAppearance) -> UInt32 {
        var resolved: NSColor = .clear
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        }
        let r = UInt32((resolved.redComponent * 255).rounded())
        let g = UInt32((resolved.greenComponent * 255).rounded())
        let b = UInt32((resolved.blueComponent * 255).rounded())
        return (r << 16) | (g << 8) | b
    }

    @Test("Dark palette matches the redesign spec")
    func darkValues() {
        let expected: [(Color, UInt32)] = [
            (DesignTokens.Palette.background, 0x17191E),
            (DesignTokens.Palette.surface, 0x22252C),
            (DesignTokens.Palette.elevatedSurface, 0x292D35),
            (DesignTokens.Palette.border, 0x373B45),
            (DesignTokens.Palette.textPrimary, 0xF0F1F4),
            (DesignTokens.Palette.textSecondary, 0xA0A5B0),
            (DesignTokens.Palette.textTertiary, 0x737987)
        ]
        for (token, value) in expected {
            #expect(hex(token, in: Self.darkAqua) == value)
        }
    }

    @Test("Light palette uses light counterparts")
    func lightValues() {
        let expected: [(Color, UInt32)] = [
            (DesignTokens.Palette.background, 0xF5F6F8),
            (DesignTokens.Palette.surface, 0xFFFFFF),
            (DesignTokens.Palette.border, 0xE1E3E8),
            (DesignTokens.Palette.textPrimary, 0x1C1D21)
        ]
        for (token, value) in expected {
            #expect(hex(token, in: Self.aqua) == value)
        }
    }

    @Test("Radii follow the spec scale")
    func radii() {
        #expect(DesignTokens.Radius.small == 6)
        #expect(DesignTokens.Radius.medium == 10)
        #expect(DesignTokens.Radius.large == 12)
    }
}
