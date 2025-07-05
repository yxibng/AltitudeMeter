//
//  VideoEditorView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/7/2.
//

import AVKit
import Combine
import SwiftUI

extension CMTime {
    var isNumeric: Bool {
        return (flags.intersection(.valid)) != [] && value != 0
    }
}

struct VideoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let url: URL
    private var isPlaying: Bool {
        self.videoEditorViewModel.isPlaying
    }

    @StateObject private var videoEditorViewModel = VideoEditorViewModel()
    @StateObject private var frameExtractor = VideoFrameExtractor()

    @State private var showSaveSheet = false
    @State private var outputURL:
        URL? /*参考： 一段因 @State 注入机制所产生的“灵异代码” https://fatbobman.com/zh/posts/bug-code-by-state-inject */

    @State private var indicatorLocation: CGFloat = 0.0

    enum Layout {
        static let toolbarHeight: CGFloat = 50.0
        static let toolbarPadding: CGFloat = 10.0
        static let innerFramesPadding: CGFloat = 10.0
        static let numberOfFrames: Int = 8
    }

    init(url: URL) {
        self.url = url
    }

    var playButton: some View {
        Button(action: {
            self.videoEditorViewModel.togglePlay()
        }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
        }
        .frame(width: Layout.toolbarHeight, height: Layout.toolbarHeight)
    }

    var bottomToolbar: some View {

        Color.clear
            .overlay {

                VStack(spacing: 20) {

                    HStack {
                        Spacer()
                        Text("已选择时长 \(self.videoEditorViewModel.selectedRangeText)")
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        playButton.background(
                            Color.init(uiColor: UIColor.lightGray)
                        )
                        Spacer().frame(width: 1.0)
                        VideoCropperView(
                            indicatorLocation: $videoEditorViewModel.currentTimeRatio,
                            minimumRange: self.videoEditorViewModel.allowedMinRangeRatio,
                            images: frameExtractor.frames.compactMap({
                                $0.image
                            }),
                            onRangeChanged: { range, direction in
                                self.videoEditorViewModel.pause()
                                self.videoEditorViewModel.selecteRange =
                                    range.min...range.max
                            },
                            onIndicatorChanged: { newValue in
                                self.videoEditorViewModel.pause()
                                let seekPoint =
                                    videoEditorViewModel.duration * newValue
                                self.videoEditorViewModel.seek(to: seekPoint)
                            }
                        )
                        .onChange(of: videoEditorViewModel.currentTime) { newValue in
                            
                        }
                        .frame(height: Layout.toolbarHeight)
                    }
                    .frame(height: Layout.toolbarHeight)

                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Text("返回")
                        }
                        Spacer(minLength: 100)
                        Button(action: {
                            cropVideoAction()
                        }) {
                            Text("下一步")
                        }
                        Spacer()
                    }
                }

            }
            .padding()

    }

    var body: some View {
        VStack {
            VideoPlayer(player: videoEditorViewModel.player)
                .disabled(true)
                .aspectRatio(9 / 16.0, contentMode: .fill)
                .padding(
                    EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32)
                )
                .onAppear {
                    videoEditorViewModel.loadVideo(url: url)
                    frameExtractor.loadVideo(from: url)
                    frameExtractor.extractFrames(count: 8)
                }.onChange(of: isPlaying) { newValue in
                    if newValue {
                        videoEditorViewModel.player?.play()
                    } else {
                        videoEditorViewModel.player?.pause()
                    }
                }
            Spacer().frame(height: 20)
            bottomToolbar
            Spacer()
        }.background(Color.black)
        .onChange(
            of: outputURL,
            perform: { _ in }
        ) /*参考：一段因 @State 注入机制所产生的“灵异代码” https://fatbobman.com/zh/posts/bug-code-by-state-inject*/
        .sheet(isPresented: $showSaveSheet) {
            if let outputURL = outputURL {
                ShareVideoView(url: outputURL)
                    .background(Color.black)
            } else {
                Rectangle().fill(Color.red)
                    .overlay(
                        Text("输出文件不存在, \(self.outputURL?.absoluteString ?? "")")
                    )
                    .frame(width: 300, height: 200)

            }
        }

    }
}

extension VideoEditorView {

    fileprivate func cropVideoAction() {
        Task {

            let outputURL = FileManager.default
                .temporaryDirectory.appendingPathComponent(
                    "cropped_video.mp4"
                )

            try await videoEditorViewModel.cropVideo(
                sourceURL: url,
                outputURL: outputURL,
                startTime: CMTime(
                    seconds: videoEditorViewModel.duration
                        * videoEditorViewModel.selecteRange
                        .lowerBound,
                    preferredTimescale: 600
                ),
                endTime: CMTime(
                    seconds: videoEditorViewModel.duration
                        * videoEditorViewModel.selecteRange
                        .upperBound,
                    preferredTimescale: 600
                )
            )

            await MainActor.run {
                self.outputURL = outputURL
                self.showSaveSheet = true
            }

        }
    }

}

#Preview {
    VideoEditorView(
        url: Bundle.main.url(
            forResource: "videoplayback",
            withExtension: "mp4"
        )!
    )
}
