import FirebaseAnalytics

enum NommieAnalytics {

    // MARK: - Creation Flow

    static func stepPhotoCompleted() {
        Analytics.logEvent("step_photo_completed", parameters: nil)
    }

    static func stepDetailsCompleted(ingredientCount: Int) {
        Analytics.logEvent("step_details_completed", parameters: [
            "ingredient_count": ingredientCount
        ])
    }

    static func macroEstimateTapped() {
        Analytics.logEvent("macro_estimate_tapped", parameters: nil)
    }

    static func macroEstimateSuccess(ingredientCount: Int) {
        Analytics.logEvent("macro_estimate_success", parameters: [
            "ingredient_count": ingredientCount
        ])
    }

    static func macroEstimateFailed() {
        Analytics.logEvent("macro_estimate_failed", parameters: nil)
    }

    static func cardCreated(ingredientCount: Int, hasNotes: Bool, usedAIEstimate: Bool, isReplate: Bool) {
        Analytics.logEvent("card_created", parameters: [
            "ingredient_count": ingredientCount,
            "has_notes": hasNotes ? 1 : 0,
            "used_ai_estimate": usedAIEstimate ? 1 : 0,
            "is_replate": isReplate ? 1 : 0
        ])
    }

    // MARK: - Social

    static func replateTapped() {
        Analytics.logEvent("replate_tapped", parameters: nil)
    }

    static func saveTapped() {
        Analytics.logEvent("save_tapped", parameters: nil)
    }

    static func followTapped() {
        Analytics.logEvent("follow_tapped", parameters: nil)
    }

    static func otherProfileViewed() {
        Analytics.logEvent("other_profile_viewed", parameters: nil)
    }

    // MARK: - Sharing & Export

    static func exportSheetOpened() {
        Analytics.logEvent("export_sheet_opened", parameters: nil)
    }

    static func cardExported(format: String) {
        Analytics.logEvent("card_exported", parameters: [
            "format": format
        ])
    }

    // MARK: - Profile & QR

    static func qrProfileViewed() {
        Analytics.logEvent("qr_profile_viewed", parameters: nil)
    }

    // MARK: - Lifecycle

    static func cardDeleted() {
        Analytics.logEvent("card_deleted", parameters: nil)
    }
}
