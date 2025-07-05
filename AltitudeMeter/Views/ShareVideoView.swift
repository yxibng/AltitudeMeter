//
//  ShareVideoView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/7/4.
//

import AVKit
import SwiftUI

struct ShareVideoView: View {
    private var player: AVPlayer
    private let url: URL
    @State private var showShareSheet = false

    init(url: URL) {
        self.url = url
        player = AVPlayer(url: url)
    }

    var body: some View {
        VStack {
            VideoPlayer(player: player)
                .aspectRatio(9 / 16.0, contentMode: .fit)
                .padding()
                .disabled(true)
                .shareSheet(show: $showShareSheet, items: [url])
                .onAppear {
                    player.play()
                }
                .onTapGesture {
                    if player.timeControlStatus == .playing {
                        player.pause()
                    } else {
                        player.play()
                    }
                }
            Button {
                showShareSheet = true
            } label: {
                Label("Share Video", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    ShareVideoView(url: Bundle.main.url(forResource: "videoplayback", withExtension: "mp4")!)
}
