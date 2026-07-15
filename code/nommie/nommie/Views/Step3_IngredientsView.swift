import SwiftUI

// Step 3 — "Ingredients": the AI drafts this list from the user's steps.
// Every AI-filled field glows until the user either edits it (that field's
// glow dies) or taps Confirm (all glows die, list is blessed). Confirming is
// required to proceed — ingredients should feel intentional, never skipped.
struct Step3_IngredientsView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    var footer: AnyView = AnyView(EmptyView())
    @FocusState private var focusedField: String?
    @State private var showingRedraftConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Heading
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingredients")
                        .font(NommieFont.titleSmall.font())
                        .foregroundColor(.nommieBrown)
                    Text(headingSubtext)
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown.opacity(0.5))
                }
                .padding(.horizontal, NommieTheme.Padding.large)

                if viewModel.isExtractingIngredients {
                    VStack(spacing: 14) {
                        NommieSpinningLogo(size: 36)
                        Text("Reading your steps...")
                            .font(Font.custom("Nunito-Regular", size: 14))
                            .foregroundColor(.nommieBrown.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    // Ingredient rows
                    VStack(spacing: 8) {
                        ForEach($viewModel.ingredients) { $ingredient in
                            IngredientConfirmRow(
                                ingredient: $ingredient,
                                canDelete: viewModel.ingredients.count > 1,
                                onDelete: { viewModel.removeIngredient(id: ingredient.id) },
                                nameFocusId: "name_\(ingredient.id)",
                                qtyFocusId: "qty_\(ingredient.id)",
                                focusedField: $focusedField
                            )
                            .padding(.horizontal, NommieTheme.Padding.large)
                        }
                    }

                    // Add + re-draft actions
                    HStack {
                        Button(action: { viewModel.ingredients.append(Ingredient()) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13))
                                Text("Add ingredient")
                                    .font(NommieFont.bodyRegular.font())
                            }
                            .foregroundColor(.nommieGreen)
                        }

                        Spacer()

                        if !viewModel.cleanedSteps.isEmpty {
                            Button(action: { showingRedraftConfirm = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12))
                                    Text("Re-draft from steps")
                                        .font(Font.custom("Nunito-Regular", size: 13))
                                }
                                .foregroundColor(.nommieBrown.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.top, 4)

                    // Confirm gate
                    if viewModel.ingredientsConfirmed {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                            Text("Ingredients confirmed")
                                .font(Font.custom("Nunito-SemiBold", size: 14))
                        }
                        .foregroundColor(.nommieGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.nommieGreen.opacity(0.1)))
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.top, 8)
                    } else {
                        VStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    viewModel.confirmIngredients()
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Confirm Ingredients")
                                        .font(Font.custom("Nunito-SemiBold", size: 16))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.nommieGreen))
                            }

                            Text("Give the list a once-over — glowing fields came from AI and haven't been checked yet.")
                                .font(Font.custom("Nunito-Regular", size: 11))
                                .foregroundColor(.nommieBrown.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.top, 8)
                    }
                }

                footer
            }
            .padding(.top, NommieTheme.Padding.small)
        }
        .onTapGesture { focusedField = nil }
        .alert("Re-draft ingredients?", isPresented: $showingRedraftConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Re-draft", role: .destructive) {
                Task { await viewModel.redraftIngredients() }
            }
        } message: {
            Text("This replaces your current list with a fresh AI draft from your steps.")
        }
    }

    private var headingSubtext: String {
        if viewModel.isExtractingIngredients { return "Drafting from your steps..." }
        if viewModel.ingredientsConfirmed { return "Locked in — still editable anytime." }
        return "Drafted from your steps. Check everything, then confirm."
    }
}

// MARK: - Ingredient Confirm Row

// Name + quantity fields with per-field AI provenance glow. Touching a field
// clears its glow; the Confirm button clears all of them at once.
struct IngredientConfirmRow: View {
    @Binding var ingredient: Ingredient
    let canDelete: Bool
    let onDelete: () -> Void
    let nameFocusId: String
    let qtyFocusId: String
    var focusedField: FocusState<String?>.Binding

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $ingredient.name, prompt: Text("e.g. Rigatoni").foregroundColor(.nommieBrown.opacity(0.45)))
                .font(NommieFont.bodyRegular.font())
                .foregroundColor(.nommieBrown)
                .padding(NommieTheme.Padding.medium)
                .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).fill(Color.white.opacity(0.7)))
                .overlay(glowBorder(active: ingredient.aiName))
                .shadow(color: ingredient.aiName ? Color.nommieGreen.opacity(0.35) : .clear, radius: 5)
                .focused(focusedField, equals: nameFocusId)
                .onChange(of: ingredient.name) { _, _ in
                    if ingredient.aiName {
                        withAnimation(.easeOut(duration: 0.25)) { ingredient.aiName = false }
                    }
                }

            TextField("", text: $ingredient.quantity, prompt: Text("1 lb").foregroundColor(.nommieBrown.opacity(0.45)))
                .font(NommieFont.bodyRegular.font())
                .foregroundColor(.nommieBrown)
                .frame(width: 70)
                .multilineTextAlignment(.center)
                .padding(NommieTheme.Padding.medium)
                .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).fill(Color.white.opacity(0.7)))
                .overlay(glowBorder(active: ingredient.aiQuantity))
                .shadow(color: ingredient.aiQuantity ? Color.nommieGreen.opacity(0.35) : .clear, radius: 5)
                .focused(focusedField, equals: qtyFocusId)
                .onChange(of: ingredient.quantity) { _, _ in
                    if ingredient.aiQuantity {
                        withAnimation(.easeOut(duration: 0.25)) { ingredient.aiQuantity = false }
                    }
                }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.nommieBrown.opacity(0.3))
                    .font(.system(size: 16))
            }
            .opacity(canDelete ? 1.0 : 0.2)
            .disabled(!canDelete)
        }
    }

    private func glowBorder(active: Bool) -> some View {
        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small)
            .stroke(
                active ? Color.nommieGreen.opacity(0.65) : Color.nommieBrown.opacity(0.15),
                lineWidth: active ? 1.5 : 1
            )
    }
}
