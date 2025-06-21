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
        GeometryReader { outerProxy in
            ZStack {
                // 测量原始内容尺寸
                Color.clear
                    .background(
                        GeometryReader { innerProxy in
                            Color.clear
                                .onAppear {
                                    originalSize = innerProxy.size
                                }
                        }
                    )
                
                // 旋转后的内容（保持中心点位置不变）
                content
                    .rotationEffect(.degrees(angle))
                    .frame(
                        width: shouldSwapDimensions ? originalSize.height : originalSize.width,
                        height: shouldSwapDimensions ? originalSize.width : originalSize.height
                    )
                    .position(
                        x: outerProxy.size.width / 2,
                        y: outerProxy.size.height / 2
                    )
            }
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
