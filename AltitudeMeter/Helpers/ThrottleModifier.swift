//
//  ThrottleModifier.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/7/5.
//

import Combine
import SwiftUI

// 节流修饰器
struct ThrottleChangeModifier<T: Equatable>: ViewModifier {
    @Binding var value: T
    let duration: TimeInterval
    let action: (T) -> Void

    @State private var publisher = PassthroughSubject<T, Never>()
    @State private var cancellable: AnyCancellable?

    func body(content: Content) -> some View {
        content
            .onChange(of: value) { newValue in
                publisher.send(newValue)
            }
            .onAppear {
                cancellable = publisher
                    .throttle(for: .seconds(duration), scheduler: RunLoop.main, latest: true)
                    .sink { newValue in
                        action(newValue)
                    }
            }
    }
}

// 使用扩展简化调用
extension View {
    func throttleChange<T: Equatable>(
        of value: Binding<T>,
        duration: TimeInterval,
        action: @escaping (T) -> Void
    ) -> some View {
        modifier(ThrottleChangeModifier(value: value, duration: duration, action: action))
    }
}
