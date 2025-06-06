//
//  Compass.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/6.
//

import SwiftUI


struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 计算三个顶点的位置（基于传入的 rect）
        let topPoint = CGPoint(x: rect.midX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        
        // 构建三角形路径
        path.move(to: topPoint)
        path.addLine(to: bottomLeft)
        path.addLine(to: bottomRight)
        path.closeSubpath()
        
        return path
    }
}


struct Compass<Content: View>: View {

    var degrees: Double
    @ViewBuilder var makeContent: () -> Content

    var triangleWidth: CGFloat = 50
    var triangleHeight: CGFloat = 25 // 三角形的高度
    var trianglePadding: CGFloat = 10 // 三角形的内边距
    
    private func centerCricleSize(geometry: GeometryProxy) -> CGSize {
        let width = geometry.size.width
        let height = geometry.size.height
        let radius = min(width, height) / 2 - triangleHeight - trianglePadding * 2
        print(geometry.size)
        return CGSize(width: radius * 2, height: radius * 2)
        
    }
    
    var body: some View {
        
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.5))
                    .blur(radius: 0.8)
                    .frame(width: min(geometry.size.width, geometry.size.height),
                           height: min(geometry.size.width, geometry.size.height))
                VStack {
                    ZStack() {
                        Triangle()
                            .fill(Color.red).frame(width: triangleWidth, height: triangleHeight)
                        Text("N")
                    }
                    .padding(trianglePadding)
                    .background(Color.white.opacity(0.5))
                    
                    Spacer()
                    
                    ZStack() {
                        Triangle()
                            .fill(Color.red).frame(width: triangleWidth, height: triangleHeight)
                        Text("S")
                    }
                    .padding(trianglePadding)
                    .rotationEffect(.degrees(180)).background(Color.white.opacity(0.5))
                }
                .frame(width: min(geometry.size.width, geometry.size.height),
                       height: min(geometry.size.width, geometry.size.height))
                .rotationEffect(.degrees(degrees))

                makeContent().overlay {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .blur(radius: 0.8)
                        .frame(width: centerCricleSize(geometry: geometry).width,
                               height: centerCricleSize(geometry: geometry).height)
                }
            }.background(Color.red)
        }
        
        

        
    }
}


#Preview {
//    Compass(degrees: 100)
}
