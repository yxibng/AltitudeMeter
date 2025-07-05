//
//  VideoEditorViewModel.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/7/5.
//

import UIKit
import AVKit
import Combine

class VideoEditorViewModel: ObservableObject {
    
    private var minimumDuration: Double = 3.0 // 最小裁剪时长
    var selecteRange: ClosedRange<Double> = 0.0...1.0 {
        didSet {
            let selecteDuration = (selecteRange.upperBound - selecteRange.lowerBound) * self.duration
            self.selectedRangeText = self.timeString(time: selecteDuration)
        }
    }
    var outputURL: URL?
    /*
     最小允许的视频裁剪时长比例。
     最短 3 秒，少于 3 秒不允许裁剪
     */
    @Published var allowedMinRangeRatio: CGFloat = 1.0
    @Published var selectedRangeText: String = ""
    
    @Published var currentTimeRatio: CGFloat = 0.0 //当前进度条比例
    
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isPlaying = false
    @Published var currentTime: Double = 0 {
        didSet {
            if self.isDurationValid {
                let ratio = currentTime / duration
                self.currentTimeRatio = max(self.selecteRange.lowerBound, min(1.0, self.selecteRange.upperBound, ratio))
            }
        }
    }
    @Published var duration: Double = 0 {
        didSet {
            if isDurationValid {
                let selecteDuration = (selecteRange.upperBound - selecteRange.lowerBound) * self.duration
                self.selectedRangeText = self.timeString(time: selecteDuration)
                let minRangeRatio = minimumDuration / self.duration
                self.allowedMinRangeRatio = max(0,min(1.0, minRangeRatio))
            }
        }
    }
    @Published var resolution: CGSize = .zero
    @Published var bitrate: Double = 0
    @Published var mediaFormat = "未知"
    
    private var playerItem: AVPlayerItem?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    
    // 计算属性：格式化显示
    var durationText: String {
        isDurationValid ? timeString(time: duration) : "--:--"
    }
    
    var currentTimeText: String {
        timeString(time: currentTime)
    }
    
    var bitrateText: String {
        bitrate > 0 ? String(format: "%.1f Mbps", bitrate / 1_000_000) : "未知"
    }
    
    var isDurationValid: Bool {
        duration > 0 && !duration.isNaN
    }
    
    // 加载视频
    func loadVideo(url: URL) {
        reset()
        isLoading = true
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        setupObservers()
    }
    
    // 重置状态
    private func reset() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerItem = nil
        player = nil
        cancellables.removeAll()
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        isLoading = false
        showError = false
        isPlaying = false
        currentTime = 0
        duration = 0
        resolution = .zero
        bitrate = 0
        mediaFormat = "未知"
    }
    
    // 设置观察者
    private func setupObservers() {
        guard let playerItem = playerItem else { return }
        
        // 监听播放状态
        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .playing:
                    self?.isPlaying = true
                    self?.isLoading = false
                case .paused:
                    self?.isPlaying = false
                    self?.isLoading = false
                case .waitingToPlayAtSpecifiedRate:
                    self?.isLoading = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // 监听视频时长
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    // 获取视频时长
                    if playerItem.duration.isNumeric {
                        self.duration = playerItem.duration.seconds
                    }
                case .failed:
                    self.isLoading = false
                    self.showError = true
                    self.errorMessage =
                    playerItem.error?.localizedDescription ?? "未知错误"
                    
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // 添加时间观察器
        addPeriodicTimeObserver()
        
        // 监听播放结束
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isPlaying = false
                self.seek(to: self.duration * self.selecteRange.lowerBound)
            }
            .store(in: &cancellables)
    }
    
    // 添加时间观察器
    private func addPeriodicTimeObserver() {
        let interval = CMTime(
            seconds: 0.5,
            preferredTimescale: CMTimeScale(NSEC_PER_SEC)
        )
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            print("Current time: \(self.currentTime)")
            
            // 如果时长无效但视频正在播放，尝试再次获取时长
            if !self.isDurationValid && self.isPlaying {
                if let duration = self.player?.currentItem?.duration,
                   duration.isNumeric
                {
                    self.duration = duration.seconds
                }
            }
            // 如果当前时间超过右边界，自动跳转到左边界
            let rightBound = self.duration * self.selecteRange.upperBound
            if currentTime >= rightBound {
                self.seek(to: self.duration * self.selecteRange.lowerBound)
            }
        }
    }
    
    // MARK: - 播放控制
    
    func togglePlay() {
        if player?.timeControlStatus == .playing {
            player?.pause()
        } else {
            player?.play()
        }
    }
    
    func play() {
        guard isDurationValid else { return }
        if player?.timeControlStatus != .playing {
            player?.play()
        }
    }

    
    
    func pause() {
        player?.pause()
    }
    
    func skip(seconds: Double) {
        guard isDurationValid else { return }
        let newTime = currentTime + seconds
        seek(to: max(0, min(newTime, duration)))
    }
    
    func seek(to time: Double) {
        guard isDurationValid else { return }
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(
            to: targetTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }
    
    func seekingChanged(editingStarted: Bool) {
        if editingStarted {
            player?.pause()
        } else {
            seek(to: currentTime)
            player?.play()
        }
    }
    
    // 时间格式化
    func timeString(time: Double) -> String {
        guard !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func cropVideo(
        sourceURL: URL,
        outputURL: URL,
        startTime: CMTime,
        endTime: CMTime
    ) async throws {
        
        let asset = AVAsset(url: sourceURL)
        guard
            let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality
            )
        else {
            throw NSError(
                domain: "VideoEditor",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"]
            )
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        print("开始裁剪视频，输出文件：\(outputURL)")
        await exportSession.export()
        switch exportSession.status {
        case .completed:
            print("视频裁剪成功，输出文件：\(outputURL)")
        case .failed:
            if let error = exportSession.error {
                print("视频裁剪失败：\(error.localizedDescription)")
            } else {
                print("视频裁剪失败：未知错误")
            }
            throw exportSession.error
            ?? NSError(
                domain: "VideoEditor",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "导出失败"]
            )
        case .cancelled:
            print("视频裁剪已取消")
            throw NSError(
                domain: "VideoEditor",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "导出已取消"]
            )
        default:
            print("视频裁剪状态未知：\(exportSession.status.rawValue)")
            throw NSError(
                domain: "VideoEditor",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "导出状态未知"]
            )
        }
    }
}
