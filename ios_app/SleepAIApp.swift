import SwiftUI

@main
struct SleepAIApp: App {
    @StateObject private var store = StoreManager()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store) }
    }
}
