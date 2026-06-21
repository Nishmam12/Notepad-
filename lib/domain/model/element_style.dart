// Styling enums shared by scene shapes (and stored by Isar via @enumerated).
// Append-only — never reorder; the index is persisted.

/// How a shape's interior is filled.
enum FillStyle { hachure, crossHatch, solid }

/// How a shape's outline is stroked.
enum StrokeStyle { solid, dashed, dotted }

/// Corner treatment for box-like shapes.
enum EdgeStyle { sharp, round }

/// Arrowhead decoration at a line/arrow endpoint.
enum Arrowhead { none, triangle, dot, bar }

/// Horizontal text alignment.
enum TextAlignKind { left, center, right }
