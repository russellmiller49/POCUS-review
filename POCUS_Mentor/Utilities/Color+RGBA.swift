import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double)? {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return (Double(red), Double(green), Double(blue), Double(alpha))
        #else
        return nil
        #endif
    }

    init?(rgbaColor: ReviewAnnotationPayload.AnnotationColor) {
        #if canImport(UIKit)
        self = Color(
            .sRGB,
            red: CGFloat(rgbaColor.red),
            green: CGFloat(rgbaColor.green),
            blue: CGFloat(rgbaColor.blue),
            opacity: CGFloat(rgbaColor.alpha)
        )
        #else
        return nil
        #endif
    }
}
