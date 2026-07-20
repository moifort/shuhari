import SwiftUI

/// A `Form` row picking one value out of a fixed set, each shown with its icon.
/// Driven by a `Menu` rather than a bare `Picker`: a `Picker` renders its collapsed
/// value through the system and drops every modifier — `.imageScale`, `.font`, even
/// `.resizable().frame()` are ignored there, leaving an icon far larger than the
/// dropdown's. A `Menu` label is what makes the icon sizable at all.
struct IconPicker<Value: Hashable & Identifiable>: View {
    let title: String
    let systemImage: String
    let options: [Value]
    let icon: (Value) -> Image
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        LabeledContent {
            Menu {
                Picker(title, selection: $selection) {
                    ForEach(options) { option in
                        Label { Text(label(option)) } icon: { icon(option) }
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 6) {
                    icon(selection).imageScale(.small)
                    Text(label(selection))
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
            }
            .tint(.secondary)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

#Preview {
    @Previewable @State var category: DishCategory = .dessert
    @Previewable @State var type: RecipeType = .dish

    Form {
        IconPicker(
            title: "Type",
            systemImage: "square.grid.2x2",
            options: RecipeType.allCases,
            icon: { $0.iconImage(filled: false) },
            label: \.label,
            selection: $type
        )
        IconPicker(
            title: "Catégorie",
            systemImage: "tag",
            options: DishCategory.allCases,
            icon: \.iconImage,
            label: \.label,
            selection: $category
        )
    }
}
