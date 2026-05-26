import SwiftUI

struct Step3_MacrosView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Estimate button
                VStack(spacing: 8) {
                    NommieButton(
                        title: "Estimate Macros",
                        style: .primary,
                        isLoading: viewModel.isEstimatingMacros
                    ) {
                        Task {
                            await viewModel.estimateMacros()
                        }
                    }
                    
                    Text("AI will estimate based on your ingredients")
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBrown.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, NommieTheme.Padding.medium)
                
                // Macro boxes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition")
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                        .padding(.horizontal, NommieTheme.Padding.large)
                    
                    HStack(spacing: 10) {
                        MacroBox(
                            label: "Calories",
                            value: $viewModel.macros.calories,
                            unit: "kcal",
                            color: .nommieYellow
                        )
                        MacroBox(
                            label: "Protein",
                            value: $viewModel.macros.protein,
                            unit: "g",
                            color: .nommieGreen
                        )
                        MacroBox(
                            label: "Carbs",
                            value: $viewModel.macros.carbs,
                            unit: "g",
                            color: .nommieBlush
                        )
                        MacroBox(
                            label: "Fat",
                            value: $viewModel.macros.fat,
                            unit: "g",
                            color: .nommieBrown
                        )
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                }
                
                // Tags
                if !viewModel.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(NommieFont.bodySemiBold.font())
                            .foregroundColor(.nommieBrown)
                            .padding(.horizontal, NommieTheme.Padding.large)
                        
                        FlowLayout(items: viewModel.tags) { tag in
                            Text(tag)
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieGreen)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.nommieGreen.opacity(0.1))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.nommieGreen.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                    }
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBlush)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NommieTheme.Padding.large)
                }
                
                Spacer(minLength: 120)
            }
        }
    }
}

// MARK: - Macro Box
struct MacroBox: View {
    let label: String
    @Binding var value: Int
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(NommieFont.caption.font())
                .foregroundColor(.nommieBrown.opacity(0.6))
            
            TextField("0", value: $value, format: .number)
                .font(NommieFont.bodySemiBold.font())
                .foregroundColor(.nommieBrown)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
            
            Text(unit)
                .font(NommieFont.caption.font())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NommieTheme.Padding.medium)
        .background(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Flow Layout for tags
struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }
    
    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geometry.size.width {
                                width = 0
                                height -= d.height + 8
                            }
                            let result = width
                            if item == items.last {
                                width = 0
                            } else {
                                width -= d.width + 8
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if item == items.last {
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
        .frame(height: calculateHeight(itemCount: items.count))
    }
    
    private func calculateHeight(itemCount: Int) -> CGFloat {
        let estimatedTagWidth: CGFloat = 108
        let availableWidth = UIScreen.main.bounds.width - 48
        let tagsPerRow = max(1, Int(availableWidth / (estimatedTagWidth + 8)))
        let rowCount = ceil(Double(itemCount) / Double(tagsPerRow))
        return rowCount * 36
    }
}
