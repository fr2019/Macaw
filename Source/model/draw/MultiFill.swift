import Foundation
#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif
import Macaw

class MultiColorFill: Fill {
    let colors: [Color]
    let direction: CGPoint

    init(colors: [Color], direction: CGPoint = CGPoint(x: 1, y: 0)) {
        self.colors = colors
        self.direction = direction
    }

    override func equals(_ other: Fill) -> Bool {
        guard let otherFill = other as? MultiColorFill else { return false }
        return colors == otherFill.colors && direction == otherFill.direction
    }
}