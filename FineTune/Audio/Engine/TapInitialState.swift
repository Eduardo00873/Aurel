// FineTune/Audio/Engine/TapInitialState.swift
import Foundation

/// Persisted settings applied to a fresh ProcessTapController before its IOProc starts.
struct TapInitialState {
    var loudnessEqualizerSettings: LoudnessEqualizerSettings = .init()
}
