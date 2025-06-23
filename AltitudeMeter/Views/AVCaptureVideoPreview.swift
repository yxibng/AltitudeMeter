//
//  AVCaptureVideoPreview.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/23.
//

import UIKit
import AVFoundation
import SwiftUI

class AVCaptureVideoPreview: UIView {
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewLayer()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tapGesture)
    }
    
    var tapAction: ((CGPoint, CGPoint) -> Void)?
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: self)
        let focusPoint = self.previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        tapAction?(touchPoint, focusPoint)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupPreviewLayer() {
        self.previewLayer.videoGravity = .resizeAspectFill
    }
    
    var session: AVCaptureSession? {
        get {
            return previewLayer.session
        }
        set {
            previewLayer.session = newValue
        }
    }

    var videoOrientaion: AVCaptureVideoOrientation {
        get {
            return previewLayer.connection?.videoOrientation ?? .portrait
        }
        set {
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = newValue
            }
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}



struct AVCaptureVideoPreviewView: UIViewRepresentable {
    var session: AVCaptureSession?
    var videoOrientation: AVCaptureVideoOrientation = .portrait
    
    //touch point in preview, focus point
    typealias TapAction = (CGPoint, CGPoint) -> Void
    var tapAction: TapAction? = nil
    
    func makeUIView(context: Context) -> AVCaptureVideoPreview {
        let preview = AVCaptureVideoPreview()
        preview.session = session
        preview.videoOrientaion = videoOrientation
        return preview
    }
    
    func updateUIView(_ uiView: AVCaptureVideoPreview, context: Context) {
        uiView.session = session
        uiView.videoOrientaion = videoOrientation
        uiView.tapAction = tapAction
    }
}


