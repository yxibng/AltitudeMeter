import AVFoundation
//
//  VideoFrameExtractor.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/7/3.
//
import SwiftUI

// 视频帧模型
struct VideoFrame: Identifiable, Hashable {
    let id = UUID()
    let time: CMTime  // 帧在视频中的时间点
    let image: UIImage?  // 帧图像
    var isLoading = false  // 加载状态
}

// UIImage 扩展 - 调整图像尺寸
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// 视频抽帧管理器
class VideoFrameExtractor: ObservableObject {
    @Published var frames: [VideoFrame] = []
    @Published var isExtracting = false
    @Published var error: Error?

    private var asset: AVAsset?
    private var imageGenerator: AVAssetImageGenerator?
    private let thumbnailSize = CGSize(width: 120, height: 68)  // 缩略图尺寸

    // 初始化视频资源
    func loadVideo(from url: URL) {
        asset = AVAsset(url: url)
        imageGenerator = AVAssetImageGenerator(asset: asset!)
        imageGenerator?.appliesPreferredTrackTransform = true  // 应用视频方向
        imageGenerator?.requestedTimeToleranceBefore = .zero  // 精确时间
        imageGenerator?.requestedTimeToleranceAfter = .zero
    }

    // 提取指定数量的帧
    func extractFrames(count: Int = 10) {
        guard let asset, let imageGenerator else {
            return
        }

        isExtracting = true
        frames.removeAll()

        // 获取视频时长
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        guard durationSeconds > 0 else { return }

        // 计算要提取的时间点
        let times = (0..<count).map { index in
            let seconds = Double(index) * durationSeconds / Double(count)
            return CMTime(seconds: seconds, preferredTimescale: 600)
        }

        // 初始化帧数组（默认状态为加载中）
        frames = times.map { time in
            VideoFrame(time: time, image: nil, isLoading: true)
        }

        // 批量请求帧图像（异步）
        let group = DispatchGroup()
        var errors: [Error] = []

        for (index, time) in times.enumerated() {
            group.enter()

            imageGenerator.generateCGImagesAsynchronously(forTimes: [
                NSValue(time: time)
            ]) {
                [weak self] _, cgImage, actualTime, _, error in
                defer { group.leave() }

                if let error {
                    errors.append(error)
                    return
                }

                guard let cgImage else { return }

                // 调整图像尺寸
                let image = UIImage(cgImage: cgImage).resized(
                    to: self?.thumbnailSize ?? CGSize(width: 120, height: 68)
                )

                // 更新帧数据
                DispatchQueue.main.async {
                    self?.frames[index] = VideoFrame(
                        time: actualTime,
                        image: image,
                        isLoading: false
                    )
                }
            }
        }

        // 所有请求完成后
        group.notify(queue: .main) { [weak self] in
            self?.isExtracting = false
            if !errors.isEmpty {
                self?.error = errors.first
            }
        }
    }
}
