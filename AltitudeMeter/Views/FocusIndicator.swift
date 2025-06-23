//
//  FocusIndicator.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/19.
//

import SwiftUI

struct FocusIndicator: View {
    @State private var animate = false
    
    var body: some View {
        
        GeometryReader { geometry in
            
            Rectangle()
                .stroke(lineWidth: 1.0)
                .foregroundColor(.yellow)
                .overlay {
                    GeometryReader { geometry in
                        Path { path in
                            let barHeight: CGFloat = 8.0
                            
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            path.move(to: CGPoint(x: width / 2, y: 0))  // 顶部中心点
                            path.addLine(
                                to: CGPoint(x: width / 2, y: barHeight)
                            )  // 顶部横线
                            
                            path.move(to: CGPoint(x: 0, y: height / 2))  // 左侧中心点)
                            path.addLine(
                                to: CGPoint(x: barHeight, y: height / 2)
                            )  // 左侧竖线
                            
                            path.move(to: CGPoint(x: width, y: height / 2))  // 右侧中心点
                            path.addLine(
                                to: CGPoint(x: width - barHeight, y: height / 2)
                            )  // 右侧竖线
                            
                            path.move(to: CGPoint(x: width / 2, y: height))  // 底部中心点
                            path.addLine(
                                to: CGPoint(x: width / 2, y: height - barHeight)
                            )  // 底部横线
                        }
                        .stroke(Color.yellow, lineWidth: 1.0)
                    }
                }
                .scaleEffect(animate ? 1 : 2)
                .animation(.easeOut(duration: 0.8), value: animate)
                .onAppear { animate = true }  // 出现时触发动画
        }
    }
}

struct FocusLocation: Identifiable {
    let id = UUID()  // 唯一标识
    let position: CGPoint
}

#Preview {
    FocusIndicator()
}
