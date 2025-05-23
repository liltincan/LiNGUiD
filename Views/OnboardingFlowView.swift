import SwiftUI

struct OnboardingFlowView: View {
    let onComplete: () -> Void
    @State private var page = 0
    private let total = 3  // number of pages

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(0..<total, id: \.self) { idx in
                    OnboardingPageView(index: idx)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page)

            Button(page == total - 1 ? "Get Started" : "Next") {
                if page < total - 1 { page += 1 }
                else { onComplete() }
            }
            .padding()
        }
    }
}
