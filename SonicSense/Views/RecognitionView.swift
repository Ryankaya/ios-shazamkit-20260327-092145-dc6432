import SwiftUI

// MARK: - RecognitionView

struct RecognitionView: View {
    @EnvironmentObject private var viewModel: ShazamViewModel
    @State private var showingDetail = false

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 48) {
                    Spacer()

                    stateHeaderView

                    ZStack {
                        if viewModel.recognitionState.isListening {
                            PulsingRingsView(audioLevel: viewModel.audioLevel)
                        }
                        listenButton
                    }
                    .frame(width: 220, height: 220)

                    matchBannerSection

                    Spacer()
                }
                .animation(.easeInOut(duration: 0.4), value: viewModel.recognitionState)
            }
            .navigationTitle("SonicSense")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDetail) {
                if let track = viewModel.currentTrack {
                    TrackDetailView(track: track)
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.8), value: viewModel.recognitionState)
    }

    private var gradientColors: [Color] {
        switch viewModel.recognitionState {
        case .listening, .processing:
            return [Color(red: 0.4, green: 0.1, blue: 0.8), Color(red: 0.2, green: 0.1, blue: 0.6)]
        case .matched:
            return [Color(red: 0.1, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.4, blue: 0.5)]
        case .noMatch:
            return [Color(red: 0.8, green: 0.4, blue: 0.1), Color(red: 0.7, green: 0.2, blue: 0.2)]
        case .error:
            return [Color(red: 0.7, green: 0.1, blue: 0.1), Color(red: 0.5, green: 0.0, blue: 0.2)]
        default:
            return [Color(red: 0.15, green: 0.05, blue: 0.25), Color(red: 0.05, green: 0.05, blue: 0.2)]
        }
    }

    // MARK: - State Header

    private var stateHeaderView: some View {
        VStack(spacing: 8) {
            Text(viewModel.recognitionState.statusMessage)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            if viewModel.recognitionState.isListening {
                Text("Hold still for best results")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .transition(.opacity)
            } else if case .error(let msg) = viewModel.recognitionState {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Listen Button

    private var listenButton: some View {
        Button(action: handleButtonTap) {
            ZStack {
                Circle()
                    .fill(buttonFill)
                    .frame(width: 130, height: 130)
                    .shadow(color: buttonShadow, radius: 24, y: 8)

                buttonIcon
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.recognitionState == .processing)
        .scaleEffect(viewModel.recognitionState == .processing ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.recognitionState)
    }

    private var buttonFill: some ShapeStyle {
        switch viewModel.recognitionState {
        case .listening:
            return AnyShapeStyle(Color.red)
        case .matched:
            return AnyShapeStyle(Color(red: 0.1, green: 0.8, blue: 0.5))
        case .noMatch:
            return AnyShapeStyle(Color.orange)
        default:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.white.opacity(0.95), Color.white.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        }
    }

    private var buttonShadow: Color {
        switch viewModel.recognitionState {
        case .listening: return .red.opacity(0.6)
        case .matched:   return Color(red: 0.1, green: 0.8, blue: 0.5).opacity(0.6)
        default:         return .purple.opacity(0.4)
        }
    }

    @ViewBuilder
    private var buttonIcon: some View {
        switch viewModel.recognitionState {
        case .idle, .error:
            Image(systemName: "waveform")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom)
                )
        case .listening:
            Image(systemName: "stop.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
        case .processing:
            ProgressView()
                .scaleEffect(1.8)
                .tint(.white)
        case .matched:
            Image(systemName: "checkmark")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
        case .noMatch:
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Match Banner

    @ViewBuilder
    private var matchBannerSection: some View {
        if case .matched = viewModel.recognitionState, let track = viewModel.currentTrack {
            TrackCardView(track: track, style: .banner)
                .padding(.horizontal, 20)
                .onTapGesture { showingDetail = true }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func handleButtonTap() {
        switch viewModel.recognitionState {
        case .matched, .noMatch:
            viewModel.resetState()
        default:
            viewModel.toggleListening()
        }
    }
}

// MARK: - PulsingRingsView

struct PulsingRingsView: View {
    let audioLevel: Float
    @State private var animating = false

    private let ringCount = 3

    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { index in
                let delay = Double(index) * 0.25
                let baseSize: CGFloat = 130 + CGFloat(index) * 44
                let audioBoost = CGFloat(audioLevel) * 30

                Circle()
                    .stroke(
                        Color.white.opacity(0.25 - Double(index) * 0.06),
                        lineWidth: 1.5
                    )
                    .frame(width: baseSize + audioBoost, height: baseSize + audioBoost)
                    .scaleEffect(animating ? 1.12 + Double(index) * 0.08 : 0.88)
                    .animation(
                        .easeInOut(duration: 1.4 + delay * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

#Preview {
    RecognitionView()
        .environmentObject(ShazamViewModel())
}
