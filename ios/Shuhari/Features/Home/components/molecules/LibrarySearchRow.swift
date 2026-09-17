import SwiftUI

/// A title-search result: what the recipe is filed by, its name, and its heart. It
/// says nothing about versions or ratings — the index it comes from holds none, and
/// a name is all it takes to recognise the recipe one was looking for.
struct LibrarySearchRow: View {
    let title: String
    let icon: Image
    let iconLabel: String
    var favorite: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            icon
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityLabel(iconLabel)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if favorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Theme.Status.favorite)
                    .accessibilityLabel("Favori")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        LibrarySearchRow(title: "Crème brûlée", icon: DishCategory.dessert.iconImage, iconLabel: "Dessert", favorite: true)
        LibrarySearchRow(title: "Crème de courgettes", icon: DishCategory.soup.iconImage, iconLabel: "Soupe")
    }
}
