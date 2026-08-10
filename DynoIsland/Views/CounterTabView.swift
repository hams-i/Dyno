import SwiftUI

struct CounterTabView: View {
    @ObservedObject var service: CounterService
    @FocusState private var isNoteFocused: Bool

    private static let spaceBlack = Color(red: 0.17, green: 0.17, blue: 0.18)
    private static let bounce = Animation.spring(response: 0.28, dampingFraction: 0.78)

    var body: some View {
        HStack(spacing: 0) {
            notePane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 4)

            clickPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notePane: some View {
        ZStack(alignment: .topLeading) {
            if service.note.isEmpty, !isNoteFocused {
                Text("Not yaz…")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.28))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: noteBinding)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($isNoteFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.trailing, 14)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            isNoteFocused = true
        }
        .accessibilityLabel(L10n.counterNote)
    }

    private var clickPane: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            // Adet ve + butonu morph katmanında çizilir.
            Text("\(service.count)")
                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .morphSlot(.counterValue)
                .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                Button {
                    withAnimation(Self.bounce) {
                        service.decrement()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(L10n.t("Bir azalt", "Decrease by one"))
                .disabled(service.count == 0)
                .opacity(service.count == 0 ? 0.35 : 1)

                Color.clear
                    .frame(width: 56, height: 56)
                    .morphSlot(.counterPlus)

                Button {
                    withAnimation(Self.bounce) {
                        service.reset()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(L10n.reset)
                .disabled(service.count == 0)
                .opacity(service.count == 0 ? 0.35 : 1)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { service.note },
            set: { service.updateNote($0) }
        )
    }
}
