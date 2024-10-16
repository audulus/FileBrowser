//  Copyright © Audulus LLC. All rights reserved.

import Foundation
import QuickLookThumbnailing
import SwiftUI

/// Data model for thumbnails with async loading.
@MainActor
final class ThumbnailLoader: ObservableObject {
    #if os(iOS)
    @Published var image: UIImage?
    #else
    @Published var image: NSImage?
    #endif

    var loadingTask = Task { }

    func load(url: URL, thumbnailName: String?) {

        // Cancel any in-progress task.
        loadingTask.cancel()

        let thumbnailScale: CGFloat = UIScreen.main.scale

        loadingTask = Task.detached {

            if let thumbnailName {

                print("💬 getting thumbnail for \(url.lastPathComponent)")

                let thumbURL = url.appendingPathComponent(thumbnailName, conformingTo: .png)

                do {
                    let data = try Data(contentsOf: thumbURL)

                    Task { @MainActor in
#if os(iOS)
                        self.image = UIImage(data: data)
#else
                        self.image = NSImage(data: data)
#endif
                    }

                } catch {
                    print("error loading thumbnail: \(error)")
                }

            } else {

                let thumbnailSize: CGSize = CGSize(width: 200, height: 200)

                // Create the thumbnail request.
                let thumbnailRequest = QLThumbnailGenerator.Request(fileAt: url,
                                                                    size: thumbnailSize,
                                                                    scale: thumbnailScale,
                                                                    representationTypes: .thumbnail)

                do {
                    let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: thumbnailRequest)
                    let image = thumbnail.cgImage
                    try await MainActor.run {

                        try Task.checkCancellation()
#if os(iOS)
                        self.image = UIImage(cgImage: image)
#else
                        self.image = NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
#endif
                    }

                } catch let error {
                    print("error generating thumbnail for \"\(url.lastPathComponent)\": \(error)")
                }
            }

        }
    }
}
