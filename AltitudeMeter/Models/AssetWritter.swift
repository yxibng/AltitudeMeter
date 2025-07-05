//
//  AssetWritter.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/7/1.
//

import AVFoundation
import UIKit

class AssetWritter: NSObject {
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false {
        didSet {
            if !isRecording {
                startTime = .zero  // 重置开始时间
            }
        }
    }
    private var startTime: CMTime = .zero

    typealias PixelBufferFilter = (CVPixelBuffer) -> CVPixelBuffer
    var pixelBufferFilter: PixelBufferFilter?

    init(pixelBufferFilter: PixelBufferFilter? = nil) {
        self.pixelBufferFilter = pixelBufferFilter
        super.init()
    }

    private func setup(outputURL: URL, videoSize: CGSize) {
        try? FileManager.default.removeItem(at: outputURL)  // 删除旧文件
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        } catch {
            print("Error creating AVAssetWriter: \(error)")
            return
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
        ]
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true

        // Pixel buffer adapter for optimal performance
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height,
        ]

        if let videoWriterInput {
            pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )
        }

        // Audio input configuration
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]

        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioWriterInput?.expectsMediaDataInRealTime = true

        // Add inputs to writer
        if let videoWriterInput, assetWriter?.canAdd(videoWriterInput) == true {
            assetWriter?.add(videoWriterInput)
        }

        if let audioWriterInput, assetWriter?.canAdd(audioWriterInput) == true {
            assetWriter?.add(audioWriterInput)
        }
    }

    func startRecording(outputURL: URL, videoSize: CGSize) {
        if isRecording {
            print("录制已在进行中")
            return
        }
        self.setup(outputURL: outputURL, videoSize: videoSize)
        // Start writing session
        guard assetWriter?.startWriting() == true else {
            print("启动录制失败: \(assetWriter?.error?.localizedDescription ?? "未知错误")")
            return
        }
        self.isRecording = true
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        if !isRecording {
            print("录制未开始")
            completion(nil)
            return
        }

        let url = assetWriter?.outputURL
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            guard let self else { return }
            if assetWriter?.status == .completed {
                print("录制完成，文件保存到: \(url?.absoluteString ?? "未知路径")")
                completion(url)
            } else {
                print("录制失败: \(assetWriter?.error?.localizedDescription ?? "未知错误")")
                completion(nil)
            }
            assetWriter = nil
            videoWriterInput = nil
            audioWriterInput = nil
            isRecording = false
        }
    }

    func writeAudio(sampleBuffer: CMSampleBuffer) {
        if !isRecording { return }
        // Handle audio sample
        if let audioWriterInput,
           audioWriterInput.isReadyForMoreMediaData {
            let result = audioWriterInput.append(sampleBuffer)
            if !result {
                print("音频写入失败: \(assetWriter?.error?.localizedDescription ?? "未知错误")")
            }
        }
    }

    func writeVideo(sampleBuffer: CMSampleBuffer) {
        if !isRecording { return }
        // Start session if needed
        if startTime == .zero {
            startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter?.startSession(atSourceTime: startTime)
        }
        // Handle video sample
        if let videoWriterInput,
           videoWriterInput.isReadyForMoreMediaData {
            // Try to append pixel buffer directly for better performance
            if let adapter = pixelBufferAdapter,
               adapter.assetWriterInput.isReadyForMoreMediaData,
               let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                if let pixelBufferFilter = pixelBufferFilter?(pixelBuffer) {
                    // Apply pixel buffer filter if provided
                    adapter.append(pixelBufferFilter, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                } else {
                    adapter.append(pixelBuffer, withPresentationTime: timestamp)
                }
            }
            // Fallback to sample buffer appending
            else if videoWriterInput.append(sampleBuffer) == false {
                print("视频写入失败: \(assetWriter?.error?.localizedDescription ?? "未知错误")")
            }
        }
    }
}
