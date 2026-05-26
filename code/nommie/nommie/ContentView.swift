import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
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
        case .themeSelection:
            ThemeSelectionView()
        case .home:
            MainTabView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
