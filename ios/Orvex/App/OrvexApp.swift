import SwiftUI

@main
struct OrvexApp: App {
    var body: some Scene {
        WindowGroup {
            SkeletonView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct SkeletonView: View {
    @State private var on = false
    var body: some View {
        ZStack {
            Color(red: 0.043, green: 0.047, blue: 0.055).ignoresSafeArea()
            VStack(spacing: 20) {
                Image("OrvexSymbol").resizable().renderingMode(.template).foregroundStyle(.white).frame(width: 90, height: 90)
                Text("أورفيكس").font(.largeTitle.bold()).foregroundStyle(.white)
                Group {
                    if #available(iOS 26.0, *) {
                        GlassEffectContainer {
                            Text("Liquid Glass").padding().glassEffect(.regular.interactive(), in: .capsule)
                        }
                        Button("زر زجاجي") { on.toggle() }.buttonStyle(.glass)
                    } else {
                        Text("Material").padding().background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .foregroundStyle(.white)
                Button("بدّل الأيقونة") { UIApplication.shared.setAlternateIconName("IconWhite") }
                    .accessibilityIdentifier("iconBtn")
            }
        }
    }
}
