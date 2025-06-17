//
//  CustomNavigationView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/11.
//

import SwiftUI

struct CustomNavigationView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        
        // 配置导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 使用示例
struct CustomNavigationView_Preview: View {
    var body: some View {
        CustomNavigationView(title: "透明导航") {
            ZStack {
                Color.blue.edgesIgnoringSafeArea(.all)
                Text("导航栏是透明的")
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    CustomNavigationView_Preview()
}

