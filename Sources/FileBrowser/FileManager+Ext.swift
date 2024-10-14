//  Copyright © 2024 Audulus LLC. All rights reserved.

import Foundation

public extension FileManager {

    func fileExists(atURL: URL) -> Bool {
        fileExists(atPath: atURL.path(percentEncoded: false))
    }
}
