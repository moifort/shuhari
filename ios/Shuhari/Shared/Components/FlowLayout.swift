import SwiftUI

/// Left-aligned flow layout: subviews keep their ideal size and wrap onto new
/// lines when the available width runs out — chips and badges never squeeze or
/// break inside themselves.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            if x > 0 { x += spacing }
            x += size.width
            maxX = max(maxX, x)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            if x > 0 { x += spacing }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    FlowLayout(spacing: 6) {
        ForEach(["14 min", "100 °C", "vitesse 1", "Inverse", "Varoma", "pétrin"], id: \.self) { text in
            Text(text)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemFill), in: Capsule())
        }
    }
    .padding()
}
