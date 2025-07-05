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
    var excludedActivityTypes: [UIActivity.ActivityType]?

    func body(content: Content) -> some View {
        content.sheet(
            isPresented: $showShareSheet,
            content: {
                ActivityViewController(
                    activityItems: $shareSheetItems,
                    excludedActivityTypes: excludedActivityTypes
                )
            }
        )
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    @Binding var activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]?

    func makeUIViewController(
        context _: UIViewControllerRepresentableContext<Self>
    ) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        controller.excludedActivityTypes = excludedActivityTypes

        return controller
    }

    func updateUIViewController(
        _: UIActivityViewController,
        context _: UIViewControllerRepresentableContext<Self>
    ) {}
}

extension View {
    func shareSheet(
        show: Binding<Bool>,
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil
    ) -> some View {
        self.modifier(
            ShareSheetModifer(
                showShareSheet: show,
                shareSheetItems: items,
                excludedActivityTypes: excludedActivityTypes
            )
        )
    }
}
