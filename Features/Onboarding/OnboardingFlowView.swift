import SwiftUI

private enum OnboardingStep: Int, Equatable {
    case cameraExplain
    case capture
    case editor
    case naming
}

struct OnboardingFlowView: View {
    @Bindable var appModel: AppModel

    @State private var step: OnboardingStep = .cameraExplain
    @State private var route: CaptureRoute = FaceCaptureCapability.preferredRoute
    @State private var configuration: AvatarConfiguration = .default
    @State private var petName: String = ""
    @State private var statusMessage: String?
    @State private var isCapturing = false
    @State private var showSelfiePicker = false
    @State private var showMemojiStickerPicker = false
    @State private var arkitService = ARKitFaceCaptureService()
    @State private var liveEstimate: AvatarParameterMapper.FaceEstimate = .average
    /// Bumped on Retry so `ARFaceLivePreviewView` remounts and restarts the session.
    @State private var captureSessionID = UUID()

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showSelfiePicker) {
            SelfieCaptureView(
                onCapture: { image in
                    showSelfiePicker = false
                    applyLikenessImage(image, sourceLabel: "Selfie")
                },
                onCancel: {
                    showSelfiePicker = false
                    statusMessage = "Selfie cancelled — you can edit manually."
                    step = .editor
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMemojiStickerPicker) {
            MemojiStickerCaptureView(
                onCapture: { image in
                    showMemojiStickerPicker = false
                    applyStickerImage(image)
                },
                onCancel: {
                    showMemojiStickerPicker = false
                    statusMessage = "Sticker cancelled — you can edit manually."
                    step = .editor
                }
            )
        }
        .onDisappear {
            arkitService.tearDown()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("TAMA\"LO\"CI")
                .font(.headline.weight(.heavy))
                .tracking(1)
            Text(stepTitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var stepTitle: String {
        switch step {
        case .cameraExplain: return "Camera"
        case .capture: return "Face capture"
        case .editor: return "Preview & edit"
        case .naming: return "Name your pet"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .cameraExplain:
            CameraExplainStep(
                preferredRoute: FaceCaptureCapability.preferredRoute,
                onContinue: beginCaptureFlow,
                onUseMemojiSticker: beginMemojiStickerFlow,
                onSkipManual: {
                    route = .manual
                    configuration = .default
                    step = .editor
                }
            )
        case .capture:
            CaptureInProgressStep(
                route: route,
                isCapturing: isCapturing,
                statusMessage: statusMessage,
                liveEstimate: $liveEstimate,
                captureSessionID: captureSessionID,
                onUseLiveEstimate: {
                    arkitService.tearDown()
                    configuration = AvatarParameterMapper.makeConfiguration(from: liveEstimate)
                    step = .editor
                },
                onRetry: retryCapture,
                onManual: {
                    arkitService.tearDown()
                    route = .manual
                    configuration = .default
                    step = .editor
                },
                onLiveFailed: { message in
                    statusMessage = message
                    route = .selfie
                    showSelfiePicker = true
                }
            )
        case .editor:
            AvatarEditorView(
                configuration: $configuration,
                onContinue: { step = .naming }
            )
        case .naming:
            PetNamingView(
                name: $petName,
                configuration: configuration,
                onCreate: finish
            )
        }
    }

    private func beginCaptureFlow() {
        Task {
            statusMessage = nil
            let granted = await CameraPermission.requestAccess()
            if !granted {
                route = .manual
                statusMessage = "Camera unavailable — customize your pet manually."
                configuration = .default
                step = .editor
                return
            }

            if FaceCaptureCapability.isARFaceTrackingSupported {
                route = .arkit
                isCapturing = false
                liveEstimate = .average
                captureSessionID = UUID()
                statusMessage = "Align your face — tap Use this look when ready."
                step = .capture
            } else {
                route = .selfie
                step = .capture
                showSelfiePicker = true
            }
        }
    }

    private func beginMemojiStickerFlow() {
        arkitService.tearDown()
        route = .memojiSticker
        statusMessage = nil
        step = .capture
        showMemojiStickerPicker = true
    }

    private func retryCapture() {
        arkitService.tearDown()
        liveEstimate = .average
        captureSessionID = UUID()
        statusMessage = "Restarting capture…"
        if route == .memojiSticker {
            step = .capture
            showMemojiStickerPicker = true
        } else if route == .arkit || FaceCaptureCapability.isARFaceTrackingSupported {
            route = .arkit
            step = .capture
            statusMessage = "Align your face — tap Use this look when ready."
        } else {
            route = .selfie
            step = .capture
            showSelfiePicker = true
        }
    }

    /// Maps an ephemeral likeness image (selfie) into avatar morphs.
    private func applyLikenessImage(_ image: UIImage, sourceLabel: String) {
        let estimate = AvatarParameterMapper.estimate(fromSelfie: image)
        configuration = AvatarParameterMapper.makeConfiguration(from: estimate)
        // Ephemeral: drop image reference after mapping (no disk save).
        statusMessage = "\(sourceLabel) mapped — tweak anything you like."
        step = .editor
    }

    /// Memoji/Genmoji stickers: color/silhouette mapping (Vision rarely detects cartoon faces).
    private func applyStickerImage(_ image: UIImage) {
        let estimate = AvatarParameterMapper.estimate(fromSticker: image)
        configuration = AvatarParameterMapper.makeConfiguration(from: estimate)
        let tinted = estimate.skinTint != nil || estimate.hairColor != nil
        statusMessage = tinted
            ? "Sticker colors applied — tweak anything you like."
            : "Sticker captured, but colors were unclear — tweak manually."
        step = .editor
    }

    private func finish() {
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        arkitService.tearDown()
        appModel.finishOnboarding(
            name: String(trimmed.prefix(24)),
            avatarConfiguration: configuration.clamped()
        )
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.96, blue: 0.98),
                Color(red: 0.88, green: 0.92, blue: 0.90),
                Color(red: 0.96, green: 0.93, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct CameraExplainStep: View {
    let preferredRoute: CaptureRoute
    let onContinue: () -> Void
    let onUseMemojiSticker: () -> Void
    let onSkipManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create a pet that feels like you")
                .font(.title2.weight(.bold))

            Text("We’ll use a short face scan (or an optional Memoji sticker from the keyboard) to style a custom floating head. Images aren’t kept after setup — only stylized look parameters.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    preferredRoute == .arkit
                        ? "This device supports Face Tracking (ARKit)."
                        : "This device will use a selfie + landmarks (or manual).",
                    systemImage: "face.dashed"
                )
                Label("Or insert a Memoji sticker from the emoji keyboard.", systemImage: "face.smiling")
                Label("You can skip and edit looks by hand.", systemImage: "slider.horizontal.3")
                Label("Face tracking stops after setup — mood comes from pet care later.", systemImage: "hand.raised")
            }
            .font(.subheadline)
            .foregroundStyle(.primary)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Button("Use Memoji sticker instead", action: onUseMemojiSticker)
                .frame(maxWidth: .infinity)

            Button("Skip camera — edit manually", action: onSkipManual)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
        }
        .padding(24)
    }
}

private struct CaptureInProgressStep: View {
    let route: CaptureRoute
    let isCapturing: Bool
    let statusMessage: String?
    @Binding var liveEstimate: AvatarParameterMapper.FaceEstimate
    let captureSessionID: UUID
    let onUseLiveEstimate: () -> Void
    let onRetry: () -> Void
    let onManual: () -> Void
    let onLiveFailed: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if route == .arkit {
                ARFaceLivePreviewView(
                    latestEstimate: $liveEstimate,
                    onSessionFailed: onLiveFailed
                )
                .id(captureSessionID)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)

                Text("Live likeness — skin, hair, eyes, and face shape update from your face (stylized floating head).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button("Use this look", action: onUseLiveEstimate)
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
            } else if route == .memojiSticker {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Text("Waiting for Memoji sticker…")
                    .font(.title3.weight(.semibold))
                Text("Insert a sticker from the emoji keyboard in the sheet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .opacity(isCapturing ? 1 : 0)
                Text("Selfie capture")
                    .font(.title3.weight(.semibold))
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 8)
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
            Button("Edit manually instead", action: onManual)
                .padding(.bottom, 28)
        }
    }
}
