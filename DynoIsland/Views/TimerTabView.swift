import SwiftUI

struct TimerTabView: View {
    @ObservedObject var service: TimerService

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            // Süre ve başlat/durdur butonu morph katmanında çizilir.
            Text(service.displayString)
                .font(.system(size: 42, weight: .semibold, design: .rounded).monospacedDigit())
                .fixedSize()
                .hidden()
                .morphSlot(.timerDisplay)
                .frame(maxWidth: .infinity)

            HStack(spacing: 22) {
                Button {
                    service.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(L10n.reset)

                Color.clear
                    .frame(width: 56, height: 56)
                    .morphSlot(.timerToggle)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
