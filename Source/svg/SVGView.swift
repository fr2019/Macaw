import Foundation

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

open class SVGView: MacawView {
    // Completion handler for SVG loading
    public var onSVGLoaded: (() -> Void)?
    
    @IBInspectable open var fileName: String? {
        didSet {
            do {
                if let fileName = fileName {
                    let parsedNode = try SVGParser.parse(resource: fileName)
                    node = parsedNode
                    // Call the completion handler when SVG is successfully loaded
                    DispatchQueue.main.async { [weak self] in
                        self?.onSVGLoaded?()
                    }
                } else {
                    node = Group()
                }
            } catch {
                node = Group()
                print("Error loading SVG: \(error)")
            }
        }
    }

    public init(node: Node, frame: CGRect) {
        super.init(frame: frame)
        self.node = node
    }

    @objc override public init?(node: Node, coder aDecoder: NSCoder) {
        super.init(node: node, coder: aDecoder)
    }

    required public convenience init?(coder aDecoder: NSCoder) {
        self.init(node: Group(), coder: aDecoder)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    override func initializeView() {
        super.initializeView()
        self.contentLayout = ContentLayout.of(contentMode: contentMode)
    }
}
