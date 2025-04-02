import Foundation
import Macaw

/// A pattern that combines multiple patterns into one
public class CompositePattern: Pattern {
    private let patterns: [Pattern]
    
    /// Create a composite pattern from multiple patterns
    /// - Parameters:
    ///   - patterns: Array of patterns to compose (first pattern is at the bottom, subsequent patterns are layered on top)
    ///   - bounds: The bounds of the composite pattern
    ///   - userSpace: Whether the pattern is defined in user space
    public init(patterns: [Pattern], bounds: Rect, userSpace: Bool = true) {
        self.patterns = patterns
        
        // Create a group that will contain all pattern contents
        let compositeGroup = Group()
        
        // Add each pattern's content to the group
        for pattern in patterns {
            compositeGroup.contents.append(pattern.content)
        }
        
        // Initialize the Pattern with the composite group
        super.init(content: compositeGroup, bounds: bounds, userSpace: userSpace)
    }
    
    /// Convenient initializer for creating a composite pattern from two patterns
    /// - Parameters:
    ///   - basePattern: The base pattern (bottom layer)
    ///   - overlayPattern: The overlay pattern (top layer)
    public convenience init(basePattern: Pattern, overlayPattern: Pattern) {
        self.init(patterns: [basePattern, overlayPattern], bounds: basePattern.bounds)
    }
}