//
//  VideoCropperView.swift
//  VideoRangeSlider
//
//  Created by yxibng on 2025/7/4.
//

import SwiftUI



struct VideoCropperView: UIViewRepresentable {
    @Binding var indicatorLocation: CGFloat
    let minimumRange: CGFloat
    let images: [UIImage]
    let onRangeChanged: (VideoRangeSlider.Range, VideoRangeSlider.Slider.Direction) -> Void
    let onIndicatorChanged: (CGFloat) -> Void
    

    func makeUIView(context: Context) -> VideoRangeSlider {
        let slider = VideoRangeSlider()
        slider.onRangeUpdateCallback = onRangeChanged
        slider.onIndicatorChangeCallback = {
            self.indicatorLocation = $0
            self.onIndicatorChanged($0)
        }
        slider.images = images
        return slider
    }
    
    func updateUIView(_ uiView: VideoRangeSlider, context: Context) {
        uiView.images = images
        uiView.indicatorLocation = indicatorLocation
        uiView.minSpaceRatio = minimumRange
    }
    
    func makeCoordinator() -> VideoCropperView.Coordinate {
        return Coordinate(cropperView: self)
    }
    
    typealias UIViewType = VideoRangeSlider
}


extension VideoCropperView {
    class Coordinate: NSObject {
        var cropperView: VideoCropperView
        init(cropperView: VideoCropperView) {
            self.cropperView = cropperView
        }
        
    }
    
    
}


#Preview {

}
