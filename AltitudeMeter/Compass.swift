//
//  Compass.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/6.
//

import SwiftUI


struct Triangle: Shape {
    
    var radius: CGFloat = 0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 计算三个顶点的位置（基于传入的 rect）
        let topPoint = CGPoint(x: rect.midX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        
        // 构建三角形路径
        path.move(to: bottomLeft)
        path.addLine(to: topPoint)
        path.addLine(to: bottomRight)
        
        if radius > rect.width / 2 {
            let offsetY = sqrt(radius * radius - rect.size.width * rect.size.width / 4)
            let centerY = offsetY + rect.height
            let centerX = rect.midX
            
            let angle = atan2(offsetY, rect.width / 2)
            
            let startAngle = CGFloat.pi * 2 - angle
            let endAngle = CGFloat.pi + angle
            path.addArc(center: CGPointMake(centerX, centerY),
                        radius: radius,
                        startAngle: Angle(radians: startAngle),
                        endAngle: Angle(radians: endAngle),
                        clockwise: true)
        } else {
            path.closeSubpath()
        }
        return path
    }
}


struct Compass<Content: View>: View {
    
    var degrees: Double
    @ViewBuilder var makeContent: () -> Content
    
    var triangleWidth: CGFloat = 70
    var triangleHeight: CGFloat = 25 // 三角形的高度
    var trianglePadding: CGFloat = 10 // 三角形的内边距
    
    private func centerCricleSize(geometry: GeometryProxy) -> CGSize {
        let width = geometry.size.width
        let height = geometry.size.height
        let radius = min(width, height) / 2 - triangleHeight - trianglePadding * 2
        return CGSize(width: radius * 2, height: radius * 2)
    }
    
    
    
    private func triangleRadius(geometry: GeometryProxy) -> CGFloat {
        return centerCricleSize(geometry: geometry).height / 2 + trianglePadding
    }

    var body: some View {
        
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .blur(radius: 0.8)
                    .frame(width: min(geometry.size.width, geometry.size.height),
                           height: min(geometry.size.width, geometry.size.height))
                VStack {
                    
                    Triangle(radius: triangleRadius(geometry: geometry))
                        .fill(Color.orange.opacity(0.5))
                        .overlay(content: {
                            Text("N")
                                .foregroundColor(.white)
                        })
                        .frame(width: triangleWidth, height: triangleHeight)
                        .padding(trianglePadding)

                    Spacer()
                    
                    Triangle(radius: triangleRadius(geometry: geometry))
                        .fill(Color.blue.opacity(0.5))
                        .overlay(content: {
                            Text("S").foregroundColor(.white)
                        })
                        .frame(width: triangleWidth, height: triangleHeight)
                        .padding(trianglePadding)
                        .rotationEffect(.degrees(180))
                }
                .frame(width: min(geometry.size.width, geometry.size.height),
                       height: min(geometry.size.width, geometry.size.height))
                .rotationEffect(.degrees(degrees))
                
                makeContent()
                    .frame(width: centerCricleSize(geometry: geometry).width,
                           height: centerCricleSize(geometry: geometry).height)
                    .overlay {
                        Circle().fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.orange.opacity(0.5),
                                                            .blue.opacity(0.5)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        
        
        
        
    }
}


#Preview {
    //    Compass(degrees: 100)
}
