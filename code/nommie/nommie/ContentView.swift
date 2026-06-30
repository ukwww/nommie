import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
        switch authViewModel.currentFlow {
        case .splash:
            SplashView()
        case .welcome:
            WelcomeView()
        case .signUp:
            SignUpView()
        case .logIn:
            LogInView()
        case .usernameSetup:
            UsernameSetupView()
        case .home:
            MainTabView()
        }
        }
        .onOpenURL { url in
            authViewModel.handleDeepLink(url)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
