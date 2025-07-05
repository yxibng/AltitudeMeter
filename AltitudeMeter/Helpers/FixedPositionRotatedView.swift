//
//  FixedPositionRotatedView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/21.
//

import SwiftUI

struct FixedPositionRotatedView<Content: View>: View {
    let content: Content
    let angle: Double
    @State private var originalSize: CGSize = .zero

    init(angle: Double = 90, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.angle = angle
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .rotationEffect(.degrees(angle))
                .frame(
                    width: shouldSwapDimensions ? geometry.size.height : geometry.size.width,
                    height: shouldSwapDimensions ? geometry.size.width : geometry.size.height
                )
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
        }
    }


    private var shouldSwapDimensions: Bool {
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 360)
        return normalizedAngle.isClose(to: 90) || normalizedAngle.isClose(to: 270)
    }
}

// 浮点数近似比较扩展
extension Double {
    func isClose(to target: Double, tolerance: Double = 1.0) -> Bool {
        return abs(self - target) < tolerance
    }
}
