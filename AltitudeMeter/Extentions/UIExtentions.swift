//
//  UIExtentions.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/17.
//

import SwiftUI

extension UIView {
    func asImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: self.layer.bounds.size, format: format)
            .image { context in
                self.drawHierarchy(in: self.layer.bounds, afterScreenUpdates: true)
            }
    }
}

extension UIScreen {
    static var safeAreaInsets: UIEdgeInsets {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        return keyWindow?.safeAreaInsets ?? .zero
    }
    
    static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
}

extension View {
    func asImage(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self.edgesIgnoringSafeArea(.all))
        controller.view.bounds = CGRect(origin: .zero, size: size)
        let image = controller.view.asImage()
        return image
    }
}
