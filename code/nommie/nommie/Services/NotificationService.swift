import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private let db = Firestore.firestore()
    private var tokenObserver: NSObjectProtocol?

    private init() {}

    // Call after the user signs in. Prompts if not yet asked; silently registers if already allowed.
    func registerIfPermitted() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                self?.fetchAndSaveToken()
            case .notDetermined:
                self?.requestPermission()
            default:
                break
            }
        }
        observeTokenRefresh()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            self?.fetchAndSaveToken()
        }
    }

    // Call on sign-out so stale tokens don't send notifications to the wrong person
    func clearToken() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).updateData(["fcmToken": FieldValue.delete()])
        if let observer = tokenObserver {
            NotificationCenter.default.removeObserver(observer)
            tokenObserver = nil
        }
    }

    private func observeTokenRefresh() {
        guard tokenObserver == nil else { return }
        tokenObserver = NotificationCenter.default.addObserver(
            forName: .fcmTokenRefreshed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let token = notification.userInfo?["token"] as? String {
                self?.saveToken(token)
            }
        }
    }

    private func fetchAndSaveToken() {
        Messaging.messaging().token { [weak self] token, _ in
            guard let token else { return }
            self?.saveToken(token)
        }
    }

    private func saveToken(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).updateData(["fcmToken": token])
    }
}
