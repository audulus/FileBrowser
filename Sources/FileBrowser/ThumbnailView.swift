//  Copyright © Audulus LLC. All rights reserved.

import SwiftUI

/// View for a thumbnail loaded by QLThumbnailGenerator.
struct ThumbnailView: View {
    var url: URL
    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color("BrowserThumbnailBorder"), lineWidth: 1)
                    )
                #else
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(4)
                #endif
            } else {
                Rectangle()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.black)
                    .cornerRadius(4)
            }
        }
        .onAppear { loader.load(url: url) }
    }
}
