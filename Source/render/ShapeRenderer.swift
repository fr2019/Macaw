import Foundation

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

class ShapeRenderer: NodeRenderer {
  var shape: Shape

  init(shape: Shape, view: DrawingView?, parentRenderer: GroupRenderer? = nil) {
    self.shape = shape
    super.init(node: shape, view: view, parentRenderer: parentRenderer)
  }

  deinit {
    dispose()
  }

  override var node: Node {
    return shape
  }

  override func doAddObservers() {
    super.doAddObservers()
    observe(shape.formVar)
    observe(shape.fillVar)
    observe(shape.strokeVar)
    observe(shape.overlayPatternVar)
    observe(shape.useOverlayPatternVar)
  }

  override func doRender(in context: CGContext, force: Bool, opacity: Double, coloringMode: ColoringMode = .rgb) {
    if shape.fill == nil && shape.stroke == nil {
      return
    }

    RenderUtils.setGeometry(shape.form, ctx: context)

    var fillRule = FillRule.nonzero
    if let path = shape.form as? Path {
      fillRule = path.fillRule
    }

    switch coloringMode {
    case .rgb:
      drawPath(fill: shape.fill, stroke: shape.stroke, ctx: context, opacity: opacity, fillRule: fillRule)
    case .greyscale:
      drawPath(fill: shape.fill?.fillUsingGrayscaleNoAlpha(), stroke: shape.stroke?.strokeUsingGrayscaleNoAlpha(), ctx: context, opacity: opacity, fillRule: fillRule)
    case .alphaOnly:
      drawPath(fill: shape.fill?.fillUsingAlphaOnly(), stroke: shape.stroke?.strokeUsingAlphaOnly(), ctx: context, opacity: opacity, fillRule: fillRule)
    }
  }

  override func doFindNodeAt(path: NodePath, ctx: CGContext) -> NodePath? {
    RenderUtils.setGeometry(shape.form, ctx: ctx)
    var drawingMode: CGPathDrawingMode?
    if let stroke = shape.stroke {
      RenderUtils.setStrokeAttributes(stroke, ctx: ctx)
      if shape.fill != nil {
        drawingMode = .fillStroke
      } else {
        drawingMode = .stroke
      }
    } else {
      drawingMode = .fill
    }

    var contains = false
    if let mode = drawingMode {
      contains = ctx.pathContains(path.location, mode: mode)
      if contains {
        return path
      }
    }

    ctx.beginPath()
    return .none
  }

  fileprivate func drawPath(fill: Fill?, stroke: Stroke?, ctx: CGContext?, opacity: Double, fillRule: FillRule) {
    guard let ctx = ctx else { return }

    var shouldStrokePath = false
    if fill is Gradient || stroke?.fill is Gradient {
      shouldStrokePath = true
    }

    // Handle pattern fill with stroke
    if let patternFill = fill as? Pattern, let stroke = stroke {
      ctx.saveGState()
      guard let path = ctx.path else { return }
      setFill(patternFill, ctx: ctx, opacity: opacity)
      ctx.restoreGState()

      ctx.addPath(path)
      RenderUtils.setStrokeAttributes(stroke, ctx: ctx)
      colorStroke(stroke, ctx: ctx, opacity: opacity)
      ctx.strokePath()
      return
    }

    // Save the current path for later use
    guard let currentPath = ctx.path?.copy() else { return }

    // Base fill rendering
    if let fill = fill {
      ctx.saveGState()
      setFill(fill, ctx: ctx, opacity: opacity)
      if fill is Gradient || fill is MultiColorFill, !(stroke?.fill is Gradient) {
        ctx.drawPath(using: fillRule == .nonzero ? .fill : .eoFill)
      } else if stroke != nil {
        drawWithStroke(stroke!, ctx: ctx, opacity: opacity, shouldStrokePath: shouldStrokePath, mode: fillRule == .nonzero ? .fillStroke : .eoFillStroke)
      } else {
        ctx.drawPath(using: fillRule == .nonzero ? .fill : .eoFill)
      }
      ctx.restoreGState()
    } else if let stroke = stroke {
      drawWithStroke(stroke, ctx: ctx, opacity: opacity, shouldStrokePath: shouldStrokePath, mode: .stroke)
    }

    // Overlay pattern if specified
    if let overlayPattern = shape.overlayPattern, shape.useOverlayPattern {
      ctx.saveGState()
      ctx.addPath(currentPath) // Re-apply the original path for clipping
      ctx.clip()
      drawPattern(overlayPattern, ctx: ctx, opacity: opacity)
      ctx.restoreGState()
    }
  }

  fileprivate func setFill(_ fill: Fill?, ctx: CGContext?, opacity: Double) {
    guard let fill = fill, let ctx = ctx else { return }

    if let fillColor = fill as? Color {
      let color = RenderUtils.applyOpacity(fillColor, opacity: opacity)
      ctx.setFillColor(color.toCG())
    } else if let gradient = fill as? Gradient {
      drawGradient(gradient, ctx: ctx, opacity: opacity)
    } else if let multiColorFill = fill as? MultiColorFill {
      drawMultiColorStripes(multiColorFill, ctx: ctx, opacity: opacity)
    } else if let pattern = fill as? Pattern {
      drawPattern(pattern, ctx: ctx, opacity: opacity)
    } else {
      print("Unsupported fill: \(fill)")
    }
  }

  fileprivate func drawWithStroke(_ stroke: Stroke, ctx: CGContext?, opacity: Double, shouldStrokePath: Bool = false, path: CGPath? = nil, mode: CGPathDrawingMode) {
    guard let ctx = ctx else { return }
    if shouldStrokePath {
      if let path = path {
        ctx.addPath(path)
      } else if let currentPath = ctx.path {
        ctx.addPath(currentPath)
      }
    }

    RenderUtils.setStrokeAttributes(stroke, ctx: ctx)

    if stroke.fill is Gradient {
      gradientStroke(stroke, ctx: ctx, opacity: opacity)
    } else if stroke.fill is Color {
      colorStroke(stroke, ctx: ctx, opacity: opacity)
      if shouldStrokePath {
        ctx.strokePath()
      } else {
        ctx.drawPath(using: mode)
      }
    }
  }

  fileprivate func colorStroke(_ stroke: Stroke, ctx: CGContext?, opacity: Double) {
    guard let strokeColor = stroke.fill as? Color, let ctx = ctx else { return }
    let color = RenderUtils.applyOpacity(strokeColor, opacity: opacity)
    ctx.setStrokeColor(color.toCG())
  }

  fileprivate func gradientStroke(_ stroke: Stroke, ctx: CGContext?, opacity: Double) {
    guard let gradient = stroke.fill as? Gradient, let ctx = ctx else { return }
    ctx.replacePathWithStrokedPath()
    drawGradient(gradient, ctx: ctx, opacity: opacity)
  }

  fileprivate func drawPattern(_ pattern: Pattern, ctx: CGContext?, opacity: Double) {
    guard let ctx = ctx else { return }
    ctx.saveGState()
    defer { ctx.restoreGState() }

    var patternNode = pattern.content
    if !pattern.userSpace, let node = BoundsUtils.createNodeFromRespectiveCoords(respectiveNode: pattern.content, absoluteLocus: shape.form) {
      patternNode = node
    }
    let renderer = RenderUtils.createNodeRenderer(patternNode, view: view)

    var patternBounds = pattern.bounds
    if !pattern.userSpace {
      let boundsTransform = BoundsUtils.transformForLocusInRespectiveCoords(respectiveLocus: pattern.bounds, absoluteLocus: shape.form)
      patternBounds = pattern.bounds.applying(boundsTransform)
    }

    guard let tileCGImage = renderer.renderToImage(bounds: patternBounds, inset: 0)?.cgImage else { return }
    ctx.draw(tileCGImage, in: patternBounds.toCG(), byTiling: true)
  }

  fileprivate func drawGradient(_ gradient: Gradient, ctx: CGContext?, opacity: Double) {
    guard let ctx = ctx else { return }
    ctx.saveGState()
    var colors: [CGColor] = []
    var stops: [CGFloat] = []
    for stop in gradient.stops {
      stops.append(CGFloat(stop.offset))
      let color = RenderUtils.applyOpacity(stop.color, opacity: opacity)
      colors.append(color.toCG())
    }

    if let gradient = gradient as? LinearGradient {
      var start = CGPoint(x: CGFloat(gradient.x1), y: CGFloat(gradient.y1))
      var end = CGPoint(x: CGFloat(gradient.x2), y: CGFloat(gradient.y2))
      if !gradient.userSpace {
        let bounds = ctx.boundingBoxOfPath
        start = CGPoint(x: start.x * bounds.width + bounds.minX, y: start.y * bounds.height + bounds.minY)
        end = CGPoint(x: end.x * bounds.width + bounds.minX, y: end.y * bounds.height + bounds.minY)
      }
      ctx.clip()
      let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: stops)
      ctx.drawLinearGradient(cgGradient!, start: start, end: end, options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    } else if let gradient = gradient as? RadialGradient {
      var innerCenter = CGPoint(x: CGFloat(gradient.fx), y: CGFloat(gradient.fy))
      var outerCenter = CGPoint(x: CGFloat(gradient.cx), y: CGFloat(gradient.cy))
      var radius = CGFloat(gradient.r)
      if !gradient.userSpace {
        var bounds = ctx.boundingBoxOfPath
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        if bounds.width > bounds.height {
          scaleY = bounds.height / bounds.width
        } else {
          scaleX = bounds.width / bounds.height
        }
        ctx.scaleBy(x: scaleX, y: scaleY)
        bounds = ctx.boundingBoxOfPath
        innerCenter = CGPoint(x: innerCenter.x * bounds.width + bounds.minX, y: innerCenter.y * bounds.height + bounds.minY)
        outerCenter = CGPoint(x: outerCenter.x * bounds.width + bounds.minX, y: outerCenter.y * bounds.height + bounds.minY)
        radius = min(radius * bounds.width, radius * bounds.height)
      }
      ctx.clip()
      let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: stops)
      ctx.drawRadialGradient(cgGradient!, startCenter: innerCenter, startRadius: 0, endCenter: outerCenter, endRadius: radius, options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    }
    ctx.restoreGState()
  }

  fileprivate func drawMultiColorStripes(_ fill: MultiColorFill, ctx: CGContext, opacity: Double) {
    ctx.saveGState()
    defer { ctx.restoreGState() }

    let bounds = ctx.boundingBoxOfPath
    let stripeCount = fill.colors.count

    // For just one color, fill with solid color
    if stripeCount == 1, let singleColor = fill.colors.first {
      let color = RenderUtils.applyOpacity(singleColor, opacity: opacity)
      ctx.setFillColor(color.toCG())
      ctx.fillPath()
      return
    }

    // For multiple colors, create horizontal stripes
    let stripeHeight = bounds.height / CGFloat(stripeCount)

    ctx.clip() // Clip to the current path

    for (index, color) in fill.colors.enumerated() {
      let y = bounds.minY + (CGFloat(index) * stripeHeight)
      let rect = CGRect(x: bounds.minX, y: y, width: bounds.width, height: stripeHeight)

      let adjustedColor = RenderUtils.applyOpacity(color, opacity: opacity)
      ctx.setFillColor(adjustedColor.toCG())
      ctx.fill(rect)
    }
  }
}

// Extensions for color modes
extension Fill {
  func fillUsingAlphaOnly() -> Fill {
    if let color = self as? Color {
      return color.colorUsingAlphaOnly()
    } else if let multiColor = self as? MultiColorFill {
      let alphaColors = multiColor.colors.map { $0.colorUsingAlphaOnly() }
      return MultiColorFill(colors: alphaColors)
    }

    let gradient = self as! Gradient
    let newStops = gradient.stops.map { Stop(offset: $0.offset, color: $0.color.colorUsingAlphaOnly()) }
    if let radial = self as? RadialGradient {
      return RadialGradient(cx: radial.cx, cy: radial.cy, fx: radial.fx, fy: radial.fy, r: radial.r, userSpace: radial.userSpace, stops: newStops)
    }
    let linear = self as! LinearGradient
    return LinearGradient(x1: linear.x1, y1: linear.y1, x2: linear.x2, y2: linear.y2, userSpace: linear.userSpace, stops: newStops)
  }

  func fillUsingGrayscaleNoAlpha() -> Fill {
    if let color = self as? Color {
      return color.toGrayscaleNoAlpha()
    } else if let multiColor = self as? MultiColorFill {
      let grayColors = multiColor.colors.map { $0.toGrayscaleNoAlpha() }
      return MultiColorFill(colors: grayColors)
    }

    let gradient = self as! Gradient
    let newStops = gradient.stops.map { Stop(offset: $0.offset, color: $0.color.toGrayscaleNoAlpha()) }
    if let radial = self as? RadialGradient {
      return RadialGradient(cx: radial.cx, cy: radial.cy, fx: radial.fx, fy: radial.fy, r: radial.r, userSpace: radial.userSpace, stops: newStops)
    }
    let linear = self as! LinearGradient
    return LinearGradient(x1: linear.x1, y1: linear.y1, x2: linear.x2, y2: linear.y2, userSpace: linear.userSpace, stops: newStops)
  }
}

extension Stroke {
  func strokeUsingAlphaOnly() -> Stroke {
    return Stroke(fill: fill.fillUsingAlphaOnly(), width: width, cap: cap, join: join, dashes: dashes, offset: offset)
  }

  func strokeUsingGrayscaleNoAlpha() -> Stroke {
    return Stroke(fill: fill.fillUsingGrayscaleNoAlpha(), width: width, cap: cap, join: join, dashes: dashes, offset: offset)
  }
}

extension Color {
  func colorUsingAlphaOnly() -> Color {
    return Color.black.with(a: Double(a()) / 255.0)
  }

  func toGrayscaleNoAlpha() -> Color {
    let grey = Int(0.21 * Double(r()) + 0.72 * Double(g()) + 0.07 * Double(b()))
    return Color.rgb(r: grey, g: grey, b: grey)
  }
}
