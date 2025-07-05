//
//  CIImage.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/18.
//

import AVFoundation
import CoreImage
import UIKit

extension CGRect {
    func cropRect(aspectRatio targetRatio: CGFloat) -> CGRect {
        let imageRatio = self.width / self.height
        var cropRect = self
        if imageRatio > targetRatio {
            // 图像比目标更宽，裁剪左右两侧
            let excessWidth = cropRect.width - cropRect.height * targetRatio
            cropRect.origin.x += excessWidth / 2
            cropRect.size.width -= excessWidth
        } else {
            // 图像比目标更高，裁剪上下两侧
            let excessHeight = cropRect.height - cropRect.width / targetRatio
            cropRect.origin.y += excessHeight / 2
            cropRect.size.height -= excessHeight
        }
        return cropRect
    }
}

extension CIImage {
    func cropToAspectRatio(_ targetRatio: CGFloat) -> CIImage {
        let imageRatio = self.extent.width / self.extent.height
        var cropRect = self.extent
        if imageRatio > targetRatio {
            // 图像比目标更宽，裁剪左右两侧
            let excessWidth = cropRect.width - cropRect.height * targetRatio
            cropRect.origin.x += excessWidth / 2
            cropRect.size.width -= excessWidth
        } else {
            // 图像比目标更高，裁剪上下两侧
            let excessHeight = cropRect.height - cropRect.width / targetRatio
            cropRect.origin.y += excessHeight / 2
            cropRect.size.height -= excessHeight
        }
        return self.cropped(to: cropRect)
    }

    var uiImage: UIImage? {
        // 将 CIImage 转换为 UIImage
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(self, from: self.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    /*
     参考：
     https://stackoverflow.com/questions/8170336/core-image-after-using-cicrop-applying-a-compositing-filter-doesnt-line-up
     */
    var correctedExtent: CIImage {
        let toTransform = CGAffineTransform(translationX: -self.extent.origin.x, y: -self.extent.origin.y)
        return self.transformed(by: toTransform)
    }
}

extension AVCapturePhoto {
    var ciImage: CIImage? {
        if let pixelBuffer {
            // raw
            return CIImage(cvPixelBuffer: pixelBuffer)
        }

        guard let data = self.fileDataRepresentation() else { return nil }
        // 创建带元数据的 CIImage
          let options: [CIImageOption: Any] = [
              .applyOrientationProperty: true,  // 应用图像方向
              .properties: self.metadata,       // 保留照片元数据
          ]
        return CIImage(data: data, options: options)
    }
}
