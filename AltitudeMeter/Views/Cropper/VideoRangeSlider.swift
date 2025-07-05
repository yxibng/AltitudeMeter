//
//  VideoRangeSlider.swift
//  VideoRangeSlider
//
//  Created by yxibng on 2025/7/3.
//

import UIKit
import SnapKit
import SwiftUI

@propertyWrapper
struct RangeLimited<T: Comparable> {
    private var value: T
    let minValue: T
    let maxValue: T
    
    init(wrappedValue: T, min minValue: T, max maxValue: T) {
        self.minValue = minValue
        self.maxValue = maxValue
        
        if minValue > maxValue {
            fatalError("min should <= max")
        }
        self.value = min(maxValue, max(minValue, wrappedValue))
    }
    
    var wrappedValue: T {
        get { return value }
        set {
            self.value = min(newValue, max(minValue, newValue))
        }
    }
}

class ExtendedTouchView: UIView {
    var touchEdgeInsets = UIEdgeInsets.zero //negative values will increase touch area
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let bounds = self.bounds.inset(by: touchEdgeInsets)
        return bounds.contains(point)
    }
}



extension VideoRangeSlider {
    
    private static let CellIdentifier = "CellIdentifier"
    
    
    class Slider: UIView {
        enum Direction {
            case left
            case right
        }
        private let direction: Direction
        var isInCrop: Bool = false {
            didSet {
                backgroundColor = isInCrop ? Layout.inCropBackgroundColor : Layout.noCropBackgroundColor
                imageView.tintColor = isInCrop ? Layout.inCropArrowColor : Layout.noCropArrowColor
            }
        }
        init(direction: Direction) {
            self.direction = direction
            super.init(frame: .zero)
            
            setup()
            
        }
        private func setup() {
            addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }

            self.backgroundColor = Layout.noCropBackgroundColor
            self.imageView.tintColor = Layout.noCropArrowColor
        }
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private lazy var imageView: UIImageView = {
            let imageName: String = direction == .left ? "chevron.compact.left" : "chevron.compact.right"
            let imageView = UIImageView(image: UIImage(systemName: imageName))
            return imageView
        }()
    }
    
    private enum Layout {
        static let indicatorWidth: CGFloat = 4.0
        static let sliderWidth: CGFloat = 20.0
        static let topBottomPadding: CGFloat = 8.0
        static let backgroundColor = UIColor.lightGray
        static let noCropBackgroundColor = UIColor.clear
        static let inCropBackgroundColor = UIColor.yellow
        static let noCropArrowColor = UIColor.white
        static let inCropArrowColor = UIColor.black
        static let indicatorColor = UIColor.white
    }
}


class VideoRangeSlider: UIView {

    //min, max in [0, 1] && min < max
    struct Range: Equatable {
        var min: CGFloat
        var max: CGFloat
        static let zero: Range = .init(min: 0, max: 0)
        static let `default`: Range = .init(min: 0, max: 1)
    }

    var range: Range = .default {
        didSet {
            print("min = \(range.min), max = \(range.max)")
            self.isCropped = range != .default
        }
    }

    //indicator location should be in [range.min, range.max]
    private var beforeIndicatorOffset: CGFloat = 0
    private var isDraggingIndicator: Bool = false
    var indicatorLocation: CGFloat = 0 {
        didSet {
            if !isDraggingIndicator {
                self.indicatorOffset = indicatorLocation * self.contentView.bounds.size.width
                self.indicatorView.snp.updateConstraints { make in
                    make.centerX.equalTo(self.contentView.snp.left).offset(self.indicatorOffset)
                }
            } else {
                print("indicatorLocation is changed while dragging, ignore it")
            }
        }
    }
    
    
    private var isCropped: Bool = false {
        didSet {
            self.leftSlider.isInCrop = isCropped
            self.rightSlider.isInCrop = isCropped
            
            if isCropped {
                self.topBar.backgroundColor = Layout.inCropBackgroundColor
                self.bottomBar.backgroundColor = Layout.inCropBackgroundColor
            } else {
                self.topBar.backgroundColor = Layout.noCropBackgroundColor
                self.bottomBar.backgroundColor = Layout.noCropBackgroundColor
            }
        }
    }

    
    //call back with min, max
    var onRangeUpdateCallback: ((VideoRangeSlider.Range,VideoRangeSlider.Slider.Direction) -> ())?
    //call back
    var onIndicatorChangeCallback:((CGFloat)->Void)?
    

    //min space between leftSlider's right and rightSlider's left.
    //equal to (selft.bounds.size.width - 2 * Layout.sliderWidth) * minSpaceRatio.
    var minSpaceRatio: CGFloat = 0.2
    private var minSpace: CGFloat {
        return (self.bounds.size.width - 2 * Layout.sliderWidth) * minSpaceRatio
    }

    private lazy var indicatorView: ExtendedTouchView = {
        let view = ExtendedTouchView()
        view.touchEdgeInsets = UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2)
        view.backgroundColor = Layout.indicatorColor
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPanIndicator(_ :)))
        view.addGestureRecognizer(pan)
        return view
    }()
    
    private lazy var leftSlider: Slider = {
        let slider = Slider(direction: .left)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPanLeftSlider(_ :)))
        slider.addGestureRecognizer(pan)
        return slider
    }()
    
    private lazy var rightSlider: Slider = {
        let slider = Slider(direction: .right)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPanRightSlider(_ :)))
        slider.addGestureRecognizer(pan)
        return slider
    }()
    
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.scrollDirection = .horizontal
        layout.sectionInset = .zero
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: VideoRangeSlider.CellIdentifier)
        collection.delegate = self
        collection.dataSource = self
        return collection
    }()
    
    //for frames
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.green
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return view
    }()
    
    private lazy var topBar: UIView = {
        let view = UIView()
        view.backgroundColor = Layout.noCropBackgroundColor
        return view
    }()
    
    
    private lazy var bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = Layout.noCropBackgroundColor
        return view
    }()
    
    //from left to right, positive
    private var leftOffset: CGFloat = 0
    //from right to left, negative
    private var rightOffset: CGFloat = 0
    //from left to right, positive
    private var indicatorOffset: CGFloat = 0 {
        didSet {
            print("indicatorOffset = \(indicatorOffset)")
        }
    }

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    var images: [UIImage] = [] {
        didSet {
            self.collectionView.reloadData()
        }
    }

    private func setup() {
        self.backgroundColor = Layout.backgroundColor
        
        addSubview(contentView)
        addSubview(leftSlider)
        addSubview(rightSlider)
        addSubview(topBar)
        addSubview(bottomBar)
        addSubview(indicatorView)
        
        contentView.snp.makeConstraints { make in
            make.left.equalTo(Layout.sliderWidth)
            make.right.equalTo(-Layout.sliderWidth)
            make.top.equalTo(Layout.topBottomPadding)
            make.bottom.equalTo(-Layout.topBottomPadding)
        }
        
        indicatorView.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(-2)
            make.width.equalTo(Layout.indicatorWidth)
            make.bottom.equalTo(contentView).offset(2)
            make.centerX.equalTo(contentView.snp.left).offset(0)
        }
        
        leftSlider.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(0)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(Layout.sliderWidth)
        }
         
        rightSlider.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(0)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(Layout.sliderWidth)
        }
        
        topBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalTo(Layout.topBottomPadding)
            make.left.equalTo(leftSlider.snp.right)
            make.right.equalTo(rightSlider.snp.left)
        }
        
        bottomBar.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(Layout.topBottomPadding)
            make.left.equalTo(leftSlider.snp.right)
            make.right.equalTo(rightSlider.snp.left)
        }
    }
    
    
}

extension VideoRangeSlider {
    
    private func updateIndicatorPosition(offsetX: CGFloat) {
        self.indicatorView.snp.updateConstraints { make in
            make.centerX.equalTo(self.contentView.snp.left).offset(offsetX)
        }
        self.layoutIfNeeded()
    }
    
    @objc func onPanLeftSlider(_ pan: UIPanGestureRecognizer) {
        var newOffset = pan.translation(in: self).x + self.leftOffset
        if newOffset < 0 {
            newOffset = 0
        }
        let maxOffset = self.rightSlider.frame.origin.x - Layout.sliderWidth - minSpace
        if newOffset > maxOffset {
            newOffset = maxOffset
        }
        if pan.state == .ended {
            self.leftOffset = newOffset
        }
        self.leftSlider.snp.updateConstraints { make in
            make.left.equalToSuperview().offset(newOffset)
        }

        //update indicator
        self.indicatorOffset = newOffset
        self.notifyIndicatorChange(offsetX: self.indicatorOffset)
        
        self.layoutIfNeeded()
        self.notifyLeftChange(offsetX: newOffset)
    }
    
    @objc func onPanRightSlider(_ pan: UIPanGestureRecognizer) {
        
        var newOffset = pan.translation(in: self).x + self.rightOffset
        if newOffset > 0 {
            newOffset = 0
        }
        let maxOffset = self.bounds.size.width - CGRectGetMaxX(self.leftSlider.frame) - minSpace - Layout.sliderWidth
        if newOffset < -maxOffset {
            newOffset = -maxOffset
        }
        if pan.state == .ended {
            self.rightOffset = newOffset
        }
        self.rightSlider.snp.updateConstraints { make in
            make.right.equalToSuperview().offset(newOffset)
        }
        
        //update indicator
        self.indicatorOffset = self.contentView.bounds.size.width + newOffset
        self.notifyIndicatorChange(offsetX: self.indicatorOffset)
        
        
        self.layoutIfNeeded()
        self.notifyRightChange(offsetX: newOffset)
    }
    
    @objc func onPanIndicator(_ pan: UIPanGestureRecognizer) {
        if pan.state == .began {
            self.beforeIndicatorOffset = self.indicatorOffset
            self.isDraggingIndicator = true
        }
        var newOffset = pan.translation(in: self).x + self.beforeIndicatorOffset
        if newOffset < self.leftOffset {
            newOffset = self.leftOffset
        }
        
        let maxOffset = self.contentView.bounds.size.width + self.rightOffset
        if newOffset > maxOffset {
            newOffset = maxOffset
        }
        if pan.state == .ended {
            self.isDraggingIndicator = false
            self.indicatorOffset = newOffset
        }
        if pan.state == .cancelled {
            self.isDraggingIndicator = false
            newOffset = self.beforeIndicatorOffset
        }
        //update indicator
        self.notifyIndicatorChange(offsetX: newOffset)
        updateIndicatorPosition(offsetX: newOffset)
        self.layoutIfNeeded()
    }
    
    
    //offsetX is positive
    private func notifyLeftChange(offsetX: CGFloat) {
        let startRatio = offsetX / (self.bounds.size.width - 2 * Layout.sliderWidth)
        if startRatio == self.range.min { return }
        self.range.min = startRatio
        self.onRangeUpdateCallback?(range, .left)
    }
    //offsetX is negative
    private func notifyRightChange(offsetX: CGFloat) {
        let endRatio = 1 + offsetX / (self.bounds.size.width - 2 * Layout.sliderWidth)
        if endRatio == self.range.max { return }
        self.range.max = endRatio
        self.onRangeUpdateCallback?(range, .right)
    }
    
    private func notifyIndicatorChange(offsetX: CGFloat) {
        let ratio = offsetX / self.contentView.bounds.size.width
        self.onIndicatorChangeCallback?(ratio)
        print("indicator ratio = \(ratio)")
    }
}


extension VideoRangeSlider: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoRangeSlider.CellIdentifier, for: indexPath)
        if let backgroundView = cell.backgroundView as? UIImageView {
            backgroundView.image = images[indexPath.item]
            backgroundView.contentMode = .scaleAspectFill
        } else {
            let imageView = UIImageView(image: images[indexPath.item])
            imageView.contentMode = .scaleAspectFill
            cell.backgroundView = imageView
        }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if self.images.isEmpty {
            return collectionView.bounds.size
        }
        let width = collectionView.bounds.size.width / CGFloat(images.count)
        return CGSize(width: width, height: collectionView.bounds.size.height)
    }

}
