import Foundation

/// Audio EQ Cookbook biquad coefficient calculations (used by the K-weighting filter)
/// Reference: Robert Bristow-Johnson's Audio EQ Cookbook
enum BiquadMath {
    /// Compute high shelf biquad coefficients (RBJ cookbook)
    /// Returns [b0, b1, b2, a1, a2] normalized by a0 for vDSP_biquad
    static func highShelfCoefficients(
        frequency: Double,
        gainDB: Float,
        q: Double,
        sampleRate: Double
    ) -> [Double] {
        let A = pow(10.0, Double(gainDB) / 40.0)
        let omega = 2.0 * .pi * frequency / sampleRate
        let sinW = sin(omega)
        let cosW = cos(omega)
        let alpha = sinW / (2.0 * q)
        let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha

        let b0 = A * ((A + 1.0) + (A - 1.0) * cosW + twoSqrtAAlpha)
        let b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosW)
        let b2 = A * ((A + 1.0) + (A - 1.0) * cosW - twoSqrtAAlpha)
        let a0 = (A + 1.0) - (A - 1.0) * cosW + twoSqrtAAlpha
        let a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosW)
        let a2 = (A + 1.0) - (A - 1.0) * cosW - twoSqrtAAlpha

        return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
    }

    /// Compute high-pass biquad coefficients (RBJ cookbook, 2nd-order Butterworth)
    /// Returns [b0, b1, b2, a1, a2] normalized by a0 for vDSP_biquad
    static func highPassCoefficients(
        frequency: Double,
        q: Double,
        sampleRate: Double
    ) -> [Double] {
        let omega = 2.0 * .pi * frequency / sampleRate
        let sinW = sin(omega)
        let cosW = cos(omega)
        let alpha = sinW / (2.0 * q)

        let b0 =  (1.0 + cosW) / 2.0
        let b1 = -(1.0 + cosW)
        let b2 =  (1.0 + cosW) / 2.0
        let a0 =  1.0 + alpha
        let a1 = -2.0 * cosW
        let a2 =  1.0 - alpha

        return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
    }
}
