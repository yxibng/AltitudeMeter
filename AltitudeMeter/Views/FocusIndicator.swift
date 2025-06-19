//
//  FocusIndicator.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/19.
//

import SwiftUI

struct FocusIndicator: View {
    var isFocus: Bool = true
    var scale: CGFloat = 1.0
    var body: some View {
        ZStack {
            Circle()
                .stroke(isFocus ? Color.green : Color.yellow, lineWidth: 2)
                .frame(width: 60 * scale, height: 60 * scale)
            
            Rectangle()
                .frame(width: 20 * scale, height: 2 * scale)
                .foregroundColor(isFocus ? Color.green : Color.yellow)
                .offset(x: -35 * scale)
            
            Rectangle()
                .frame(width: 20 * scale, height: 2 * scale)
                .foregroundColor(isFocus ? Color.green : Color.yellow)
                .offset(x: 35 * scale)
            
            Rectangle()
                .frame(width: 2 * scale, height: 20 * scale)
                .foregroundColor(isFocus ? Color.green : Color.yellow)
                .offset(y: -35 * scale)
            
            Rectangle()
                .frame(width: 2 * scale, height: 20 * scale)
                .foregroundColor(isFocus ? Color.green : Color.yellow)
                .offset(y: 35 * scale)
        }
    }
}



#Preview {
    FocusIndicator()
}
