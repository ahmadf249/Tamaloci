import SwiftUI
import UIKit

struct PetHomeView: View {
    @Bindable var appModel: AppModel
    @State private var expression: PetExpression = .neutral
    @State private var characterViewID = UUID()
    @State private var showDebugHUD = false
    @State private var carePulse = false
    @State private var statusMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let brandTitle = "TAMA\"LO\"CI"
    private let config = SimulationConfig.default

    private var pet: PetRecord? { appModel.repository.activePet }

    private var avatarConfiguration: AvatarConfiguration {
        pet?.avatarConfiguration ?? .default
    }

    private var isIllOrCritical: Bool {
        guard let pet else { return false }
        return pet.state.isIll || pet.needs.health <= config.criticalHealthThreshold
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                HStack {
                    Button("Memorial") {
                        appModel.showMemorial()
                    }
                    .font(.caption.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Text(brandTitle)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .onLongPressGesture(minimumDuration: 1.2) {
                        #if DEBUG
                        showDebugHUD.toggle()
                        #endif
                    }

                Text(pet.map(\.name) ?? "Your pet")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 4)

                if let pet {
                    Text("\(pet.lifeStage.displayName) · \(ageLabel(pet.ageDays))")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                statusBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                ZStack {
                    PetCharacterView(
                        expression: $expression,
                        avatarConfiguration: avatarConfiguration,
                        reduceMotion: reduceMotion
                    )
                    .id(characterViewID)
                    .scaleEffect(carePulse ? 1.06 : 1.0)
                    .opacity(carePulse ? 0.92 : 1.0)

                    if carePulse {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.45), lineWidth: 3)
                            .frame(width: 160, height: 160)
                            .scaleEffect(carePulse ? 1.25 : 0.85)
                            .opacity(carePulse ? 0 : 0.7)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)

                if let pet {
                    NeedsMetersView(needs: pet.needs)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    CareControlsView(
                        isSleeping: pet.state.isSleeping,
                        isIll: pet.state.isIll,
                        onCare: { type in
                            performCare(type)
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }

                if showDebugHUD {
                    debugPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            characterViewID = UUID()
            Task { await runDeviceTickAndSyncExpression() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await runDeviceTickAndSyncExpression() }
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let pet {
            if pet.state.isIll {
                Text("Needs medicine — feeling ill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.18, blue: 0.16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.95, green: 0.82, blue: 0.80).opacity(0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if pet.needs.health <= config.criticalHealthThreshold {
                Text("Health is low — care soon")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.96, green: 0.88, blue: 0.72).opacity(0.95), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if pet.state.isSleeping {
                Text("Sleeping — energy recovering")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Your stylized companion — saved on device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No active pet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: isIllOrCritical
                ? [
                    Color(red: 0.94, green: 0.88, blue: 0.88),
                    Color(red: 0.90, green: 0.86, blue: 0.84),
                    Color(red: 0.95, green: 0.90, blue: 0.86)
                ]
                : [
                    Color(red: 0.93, green: 0.96, blue: 0.98),
                    Color(red: 0.88, green: 0.92, blue: 0.90),
                    Color(red: 0.96, green: 0.93, blue: 0.88)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: isIllOrCritical)
    }

    private func ageLabel(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    private func runDeviceTickAndSyncExpression() async {
        appModel.repository.refresh()
        if let result = await appModel.refreshDeviceIntegrationsAndTick() {
            if case .deceased = result { return }
        }
        syncExpressionFromPet()
    }

    private func syncExpressionFromPet() {
        guard let pet = appModel.repository.activePet else { return }
        expression = PetSimulation.suggestedExpression(needs: pet.needs, state: pet.state, config: config)
    }

    private func performCare(_ type: CareEventType) {
        do {
            let context = SimulationContext(
                environment: appModel.repository.latestEnvironmentSnapshot(),
                batteryCharging: BatterySleepMonitor.shared.isCharging
            )
            let result = try appModel.repository.performCare(type, context: context)
            appModel.applyTickResult(result)
            if case .deceased = result { return }
            Task { await CareNotificationScheduler.shared.sync(pet: appModel.repository.activePet) }
            syncExpressionFromPet()
            statusMessage = "\(type.displayName) ✓"
            triggerCareFeedback()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if statusMessage?.hasPrefix(type.displayName) == true {
                    statusMessage = nil
                }
            }
        } catch {
            statusMessage = "Couldn’t apply care"
        }
    }

    private func triggerCareFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            carePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeIn(duration: 0.28)) {
                carePulse = false
            }
        }
    }

    #if DEBUG
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBUG · expressions / time")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                spacing: 8
            ) {
                ForEach(PetExpression.allCases) { item in
                    Button {
                        expression = item
                    } label: {
                        Text(item.displayName)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(expression == item ? Color.accentColor : Color.secondary.opacity(0.35))
                }
            }

            HStack {
                Button("Advance 6h") {
                    appModel.advanceSimulationHoursForDebug(6)
                    if appModel.route == .petHome {
                        syncExpressionFromPet()
                    }
                }
                Button("Mark deceased") {
                    appModel.markDeceasedForDebug()
                }
                Button("Reset all") {
                    appModel.resetOnboardingForDebug()
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    #else
    private var debugPanel: some View { EmptyView() }
    #endif
}

// MARK: - Needs meters

private struct NeedsMetersView: View {
    let needs: PetNeeds

    private var rows: [(String, Double)] {
        [
            ("Hunger", needs.hunger),
            ("Hydration", needs.hydration),
            ("Happy", needs.happiness),
            ("Health", needs.health),
            ("Clean", needs.cleanliness),
            ("Energy", needs.energy)
        ]
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.0) { label, value in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .frame(width: 62, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(meterColor(value))
                                .frame(width: max(4, geo.size.width * CGFloat(value / 100)))
                        }
                    }
                    .frame(height: 8)
                    Text("\(Int(value.rounded()))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func meterColor(_ value: Double) -> Color {
        if value <= 25 {
            return Color(red: 0.75, green: 0.28, blue: 0.24)
        }
        if value <= 50 {
            return Color(red: 0.82, green: 0.58, blue: 0.22)
        }
        return Color(red: 0.28, green: 0.58, blue: 0.48)
    }
}

// MARK: - Care controls

private struct CareControlsView: View {
    let isSleeping: Bool
    let isIll: Bool
    let onCare: (CareEventType) -> Void

    private var actions: [CareEventType] {
        var list: [CareEventType] = [.feed, .water, .play, .clean, .medicine]
        list.append(isSleeping ? .wake : .sleep)
        return list
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
            spacing: 8
        ) {
            ForEach(actions, id: \.self) { type in
                Button {
                    onCare(type)
                } label: {
                    Text(type.displayName)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint(for: type))
            }
        }
    }

    private func tint(for type: CareEventType) -> Color {
        switch type {
        case .medicine:
            return isIll
                ? Color(red: 0.62, green: 0.28, blue: 0.32)
                : Color.secondary.opacity(0.55)
        case .sleep, .wake:
            return Color(red: 0.35, green: 0.45, blue: 0.62)
        default:
            return Color(red: 0.28, green: 0.52, blue: 0.48)
        }
    }
}
