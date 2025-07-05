//
//  AVCaptureVideoPreview.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/23.
//

import AVFoundation
import SwiftUI
import UIKit

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
        if focusPoint.x < 0 || focusPoint.x > 1 || focusPoint.y < 0 || focusPoint.y > 1 {
            return // Ignore taps outside the valid range
        }
        tapAction?(touchPoint, focusPoint)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupPreviewLayer() {
        self.previewLayer.videoGravity = .resizeAspect
    }

    var session: AVCaptureSession? {
        get {
            previewLayer.session
        }
        set {
            previewLayer.session = newValue
        }
    }

    var videoOrientaion: AVCaptureVideoOrientation {
        get {
            previewLayer.connection?.videoOrientation ?? .portrait
        }
        set {
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = newValue
            }
        }
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct AVCaptureVideoPreviewView: UIViewRepresentable {
    var session: AVCaptureSession?
    var videoOrientation: AVCaptureVideoOrientation = .portrait

    // touch point in preview, focus point
    typealias TapAction = (CGPoint, CGPoint) -> Void
    var tapAction: TapAction?

    func makeUIView(context _: Context) -> AVCaptureVideoPreview {
        let preview = AVCaptureVideoPreview()
        preview.session = session
        preview.videoOrientaion = videoOrientation
        return preview
    }

    func updateUIView(_ uiView: AVCaptureVideoPreview, context _: Context) {
        uiView.session = session
        uiView.videoOrientaion = videoOrientation
        uiView.tapAction = tapAction
    }
}
