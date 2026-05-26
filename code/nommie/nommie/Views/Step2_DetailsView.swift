import SwiftUI

struct Step2_DetailsView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    @FocusState private var focusedField: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Dish name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dish Name")
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                        .padding(.horizontal, NommieTheme.Padding.large)
                    
                    TextField("e.g. Spaghetti Carbonara", text: $viewModel.dishName)
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown)
                        .padding(NommieTheme.Padding.medium)
                        .background(
                            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                                .fill(Color.white.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                                .stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .focused($focusedField, equals: "dishName")
                }
                
                // Ingredients
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredients")
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                        .padding(.horizontal, NommieTheme.Padding.large)
                    
                    VStack(spacing: 10) {
                        ForEach($viewModel.ingredients) { $ingredient in
                            HStack(spacing: 10) {
                                TextField("Quantity", text: $ingredient.quantity)
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                    .frame(width: 80)
                                    .padding(NommieTheme.Padding.medium)
                                    .background(
                                        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small)
                                            .fill(Color.white.opacity(0.7))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small)
                                            .stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1)
                                    )
                                
                                TextField("Ingredient name", text: $ingredient.name)
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                    .padding(NommieTheme.Padding.medium)
                                    .background(
                                        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small)
                                            .fill(Color.white.opacity(0.7))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small)
                                            .stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1)
                                    )
                                
                                Button(action: {
                                    viewModel.removeIngredient(id: ingredient.id)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.nommieBlush)
                                        .font(.system(size: 22))
                                }
                                .opacity(viewModel.ingredients.count > 1 ? 1.0 : 0.3)
                            }
                            .padding(.horizontal, NommieTheme.Padding.large)
                        }
                    }
                    
                    Button(action: {
                        viewModel.addIngredient()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.nommieGreen)
                            Text("Add ingredient")
                                .font(NommieFont.bodySemiBold.font())
                                .foregroundColor(.nommieGreen)
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.top, 4)
                    }
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (optional)")
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                        .padding(.horizontal, NommieTheme.Padding.large)
                    
                    TextField("Any cooking tips or steps...", text: $viewModel.notes, axis: .vertical)
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown)
                        .lineLimit(4...8)
                        .padding(NommieTheme.Padding.medium)
                        .background(
                            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                                .fill(Color.white.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                                .stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .focused($focusedField, equals: "notes")
                }
                
                Spacer(minLength: 120)
            }
            .padding(.top, NommieTheme.Padding.medium)
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}
