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

  // Add a new property for pattern color
  public let patternColorVar: AnimatableVariable<Color?>
  open var patternColor: Color? {
    get { return patternColorVar.value }
    set(val) {
      patternColorVar.value = val

      // If we have a pattern and we're setting a color, update the pattern with this color
      if let pattern = overlayPattern, let newColor = val {
        let updatedPattern = updatePatternWithColor(pattern, newColor: newColor)
        overlayPatternVar.value = updatedPattern
      }
    }
  }

  public init(form: Locus,
              fill: Fill? = nil,
              stroke: Stroke? = nil,
              overlayPattern: Pattern? = nil,
              useOverlayPattern: Bool = false,
              patternColor: Color? = nil,
              place: Transform = Transform.identity,
              opaque: Bool = true,
              opacity: Double = 1,
              clip: Locus? = nil,
              mask: Node? = nil,
              effect: Effect? = nil,
              visible: Bool = true,
              tag: [String] = [])
  {
    self.formVar = AnimatableVariable<Locus>(form)
    self.fillVar = AnimatableVariable<Fill?>(fill)
    self.strokeVar = StrokeAnimatableVariable(stroke)
    self.overlayPatternVar = AnimatableVariable<Pattern?>(overlayPattern)
    self.useOverlayPatternVar = AnimatableVariable<Bool>(useOverlayPattern)
    self.patternColorVar = AnimatableVariable<Color?>(patternColor)

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

    formVar.node = self
    fillVar.node = self
    strokeVar.node = self
    overlayPatternVar.node = self
    useOverlayPatternVar.node = self
    patternColorVar.node = self
  }

  // Add a convenience method to set both base fill and pattern
  open func setFillWithOverlay(baseFill: Fill, overlayPattern: Pattern, patternColor: Color? = nil) {
    fill = baseFill
    self.overlayPattern = overlayPattern
    useOverlayPattern = true
    if let color = patternColor {
      self.patternColor = color
    }
  }

  // Create multicolor fill with colors and optional star overlay
  open func setMultiColorFill(colors: [Color], overlayPattern: Pattern? = nil, patternColor: Color? = nil) {
    if colors.count > 1 {
      fill = MultiColorFill(colors: colors)
    } else if let color = colors.first {
      fill = color
    }

    if let pattern = overlayPattern {
      self.overlayPattern = pattern
      useOverlayPattern = true
      if let color = patternColor {
        self.patternColor = color
      }
    } else {
      self.overlayPattern = nil
      useOverlayPattern = false
      self.patternColor = nil
    }
  }

  // Helper method to update a pattern with a new color
  private func updatePatternWithColor(_ pattern: Pattern, newColor: Color) -> Pattern {
    // Create a copy of the pattern with our new color
    // We'll need to traverse the pattern's content and update star colors
    if let group = pattern.content as? Group {
      let newGroup = updateGroupWithColor(group, newColor: newColor)
      return Pattern(
        content: newGroup,
        bounds: pattern.bounds,
        userSpace: pattern.userSpace
      )
    }

    return pattern // Return original if we can't modify
  }

  // Helper to update a Group node with a new color
  private func updateGroupWithColor(_ group: Group, newColor: Color) -> Group {
    let newContents = group.contents.map { node -> Node in
      if let shape = node as? Shape {
        // If this is a star shape, update its fill color
        if let path = shape.form as? Path {
          // Check if this looks like a star (has at least 5 points)
          if path.segments.count >= 5 {
            let newShape = Shape(
              form: shape.form,
              fill: newColor, // Use our new color
              stroke: shape.stroke,
              overlayPattern: shape.overlayPattern,
              useOverlayPattern: shape.useOverlayPattern,
              patternColor: shape.patternColor,
              place: shape.place,
              opaque: shape.opaque,
              opacity: shape.opacity,
              clip: shape.clip,
              mask: shape.mask,
              effect: shape.effect,
              visible: shape.visible,
              tag: shape.tag
            )
            return newShape
          }
        }
        return shape
      } else if let childGroup = node as? Group {
        return updateGroupWithColor(childGroup, newColor: newColor)
      }
      return node
    }

    let newGroup = Group(
      contents: newContents,
      place: group.place,
      opaque: group.opaque,
      opacity: group.opacity,
      clip: group.clip,
      mask: group.mask,
      effect: group.effect,
      visible: group.visible,
      tag: group.tag
    )

    return newGroup
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

    RenderUtils.setGeometry(form, ctx: ctx)
    RenderUtils.setClip(clip, ctx: ctx)

    let point = ctx.currentPointOfPath

    if shouldStrokePath {
      ctx.replacePathWithStrokedPath()
    }

    var rect = ctx.boundingBoxOfPath

    if rect.height == 0,
       rect.width == 0 && (rect.origin.x == CGFloat.infinity || rect.origin.y == CGFloat.infinity)
    {
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
