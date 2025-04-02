#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

// Class for multiple colors in a fill (for striped patterns)
open class MultiColorFill: Fill {
    public let colors: [Color]
    
    public init(colors: [Color]) {
        self.colors = colors
    }
}

open class Shape: Node {
    // Original properties
    public let formVar: AnimatableVariable<Locus>
    open var form: Locus {
        get { return formVar.value }
        set(val) { formVar.value = val }
    }

    public let fillVar: AnimatableVariable<Fill?>
    open var fill: Fill? {
        get { return fillVar.value }
        set(val) { fillVar.value = val }
    }

    public let strokeVar: StrokeAnimatableVariable
    open var stroke: Stroke? {
        get { return strokeVar.value }
        set(val) { strokeVar.value = val }
    }
    
    // New properties for pattern support
    public let overlayPatternVar: AnimatableVariable<Pattern?>
    open var overlayPattern: Pattern? {
        get { return overlayPatternVar.value }
        set(val) { overlayPatternVar.value = val }
    }
    
    public let useOverlayPatternVar: AnimatableVariable<Bool>
    open var useOverlayPattern: Bool {
        get { return useOverlayPatternVar.value }
        set(val) { useOverlayPatternVar.value = val }
    }

    public init(form: Locus, 
                fill: Fill? = nil, 
                stroke: Stroke? = nil,
                overlayPattern: Pattern? = nil,
                useOverlayPattern: Bool = false,
                place: Transform = Transform.identity, 
                opaque: Bool = true, 
                opacity: Double = 1, 
                clip: Locus? = nil, 
                mask: Node? = nil, 
                effect: Effect? = nil, 
                visible: Bool = true, 
                tag: [String] = []) {
        
        self.formVar = AnimatableVariable<Locus>(form)
        self.fillVar = AnimatableVariable<Fill?>(fill)
        self.strokeVar = StrokeAnimatableVariable(stroke)
        self.overlayPatternVar = AnimatableVariable<Pattern?>(overlayPattern)
        self.useOverlayPatternVar = AnimatableVariable<Bool>(useOverlayPattern)
        
        super.init(
            place: place,
            opaque: opaque,
            opacity: opacity,
            clip: clip,
            mask: mask,
            effect: effect,
            visible: visible,
            tag: tag
        )

        self.formVar.node = self
        self.fillVar.node = self
        self.strokeVar.node = self
        self.overlayPatternVar.node = self
        self.useOverlayPatternVar.node = self
    }
    
    // Add a convenience method to set both base fill and pattern
    open func setFillWithOverlay(baseFill: Fill, overlayPattern: Pattern) {
        self.fill = baseFill
        self.overlayPattern = overlayPattern
        self.useOverlayPattern = true
    }
    
    // Create multicolor fill with colors and optional star overlay
    open func setMultiColorFill(colors: [Color], overlayPattern: Pattern? = nil) {
        if colors.count > 1 {
            self.fill = MultiColorFill(colors: colors)
        } else if let color = colors.first {
            self.fill = color
        }
        
        if let pattern = overlayPattern {
            self.overlayPattern = pattern
            self.useOverlayPattern = true
        } else {
            self.overlayPattern = nil
            self.useOverlayPattern = false
        }
    }

    override open var bounds: Rect? {
        guard let ctx = createContext() else {
            return .none
        }

        var shouldStrokePath = false

        if let stroke = stroke {
            RenderUtils.setStrokeAttributes(stroke, ctx: ctx)
            shouldStrokePath = true
        }

        RenderUtils.setGeometry(self.form, ctx: ctx)
        RenderUtils.setClip(self.clip, ctx: ctx)

        let point = ctx.currentPointOfPath

        if shouldStrokePath {
            ctx.replacePathWithStrokedPath()
        }

        var rect = ctx.boundingBoxOfPath

        if rect.height == 0,
           rect.width == 0 && (rect.origin.x == CGFloat.infinity || rect.origin.y == CGFloat.infinity) {

            rect.origin = point
        }

        // TO DO: Remove after fixing bug with boundingBoxOfPath - https://openradar.appspot.com/6468254639
        if rect.width.isInfinite || rect.height.isInfinite {
            rect.size = CGSize.zero
        }

        endContext()

        return rect.toMacaw()
    }

    fileprivate func createContext() -> CGContext? {
        let screenScale: CGFloat = MMainScreen()?.mScale ?? 1.0
        let smallSize = CGSize(width: 1.0, height: 1.0)

        MGraphicsBeginImageContextWithOptions(smallSize, false, screenScale)

        return MGraphicsGetCurrentContext()
    }

    fileprivate func endContext() {
        MGraphicsEndImageContext()
    }
}
