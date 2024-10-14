//  Copyright © Audulus LLC. All rights reserved.

import SwiftUI

let toolbarButtonDiameter: CGFloat = 54
let selectedButtonPadding: CGFloat = 3

struct CustomToolbarButton: View {

    var image: Image
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            image
                .frame(width: toolbarButtonDiameter, height: toolbarButtonDiameter)
                .background(
                        .thinMaterial,
                        in: Circle())
        }
    }
}
