//
//  ShareSheetModifer.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/17.
//

import SwiftUI

struct ShareSheetModifer: ViewModifier {
    @Binding var showShareSheet: Bool
    @State var shareSheetItems: [Any] = []
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func body(content: Content) -> some View {
        content.sheet(isPresented: $showShareSheet, content: {
            ActivityViewController(activityItems: self.$shareSheetItems, excludedActivityTypes: excludedActivityTypes)
        })
    }
}


struct ActivityViewController: UIViewControllerRepresentable {
    @Binding var activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems,
                                                  applicationActivities: nil)
        
        controller.excludedActivityTypes = excludedActivityTypes
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}


extension View {
    func shareSheet(show: Binding<Bool>, items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) -> some View {
        self.modifier(ShareSheetModifer(showShareSheet: show, shareSheetItems: items, excludedActivityTypes: excludedActivityTypes))
    }
}
