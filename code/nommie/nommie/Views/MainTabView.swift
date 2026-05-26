import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        TabView {
            HomeFeedView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(.nommieGreen)
    }
}

struct ProfilePlaceholderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("@\(authViewModel.currentNommieUser?.username ?? "")")
                    .font(NommieFont.titleMedium.font())
                    .foregroundColor(.nommieBrown)
                
                Text("Profile coming in Section 6")
                    .font(NommieFont.bodyRegular.font())
                    .foregroundColor(.nommieBrown.opacity(0.5))
                
                NommieButton(title: "Sign Out", style: .secondary) {
                    authViewModel.signOut()
                }
                .padding(.top, 24)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
