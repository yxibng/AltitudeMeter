//
//  PixelBufferCompositingFilter.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/7/1.
//

import CoreImage


class PixelBufferCompositingFilter: NSObject {
    
    enum WatermarkType {
        case text(attributedString: NSAttributedString)
        case image(CIImage, scale: CGFloat = 1.0)
    }
    
    struct WatermarkItem {
        let type: WatermarkType
        let position: CGPoint  // 水印位置
    }

    private lazy var ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        }
        return CIContext()
    }()
    
    func composite(pixelBuffer: CVPixelBuffer, with Watermarks: [WatermarkItem]) -> CVPixelBuffer {
        func addTextWatermark(_ watermark: WatermarkItem, to image: CIImage) -> CIImage? {
            guard case .text(let attributedString) = watermark.type else { return nil }
            let textFilter = CIFilter(name: "CIAttributedTextImageGenerator")!
            textFilter.setValue(attributedString, forKey: "inputText")
            guard let textImage = textFilter.outputImage else { return nil }
        
        
            // 计算文字位置（基于原图尺寸）
            let transform = CGAffineTransform(translationX: watermark.position.x, y: watermark.position.y)
            let translatedTextImage = textImage.transformed(by: transform)
            // 合成原图和文字水印
            let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
            compositeFilter.setValue(translatedTextImage, forKey: kCIInputImageKey)
            compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
            return compositeFilter.outputImage
        }
        func addImageWatermark(_ watermark: WatermarkItem, to image: CIImage) -> CIImage? {
            guard case .image(let watermarkImage, let scale) = watermark.type else { return nil }
            // 缩放水印图像
            let scaledWatermarkImage = watermarkImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            // 计算水印位置（基于原图尺寸）
            let transform = CGAffineTransform(translationX: watermark.position.x, y: watermark.position.y)
            let translatedWatermarkImage = scaledWatermarkImage.transformed(by: transform)
            // 合成原图和水印图像
            let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
            compositeFilter.setValue(translatedWatermarkImage, forKey: kCIInputImageKey)
            compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
            return compositeFilter.outputImage
        }
        var filteredImage: CIImage = CIImage(cvPixelBuffer: pixelBuffer)
        for watermark in Watermarks {
            switch watermark.type {
            case .text:
                if let image = addTextWatermark(watermark, to: filteredImage) {
                    filteredImage = image
                }
            case .image:
                if let image = addImageWatermark(watermark, to: filteredImage) {
                    filteredImage = image
                }
            }
        }
        return self.convertToPixelBuffer(ciImage: filteredImage, width: filteredImage.extent.width, height: filteredImage.extent.height) ?? pixelBuffer
    }
    
    private func convertToPixelBuffer(ciImage: CIImage, width: CGFloat, height: CGFloat) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width as NSNumber,
            kCVPixelBufferHeightKey: height as NSNumber,
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        self.ciContext.render(ciImage, to: buffer)
        return buffer
    }
    
    
}
