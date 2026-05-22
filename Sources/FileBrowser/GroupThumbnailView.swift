//  Copyright © Audulus LLC. All rights reserved.

import SwiftUI

struct GroupThumbnailView: View {

    let urls: [URL]
    let thumbnailName: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color("BrowserThumbnailBorder", bundle: Bundle.module), lineWidth: 1)
                )

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    thumbnail(at: 0)
                    thumbnail(at: 1)
                }
                HStack(spacing: 8) {
                    thumbnail(at: 2)
                    thumbnail(at: 3)
                }
            }.padding(12)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    func thumbnail(at index: Int) -> some View {
        if urls.indices.contains(index) {
            ThumbnailView(url: urls[index], thumbnailName: thumbnailName)
                .aspectRatio(1, contentMode: .fit)
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.08))
                .aspectRatio(1, contentMode: .fit)
        }
    }
}
