import SwiftUI
import UIKit

struct PetHomeView: View {
    @Bindable var appModel: AppModel
    @State private var expression: PetExpression = .neutral
    @State private var characterViewID = UUID()
    @State private var lastAvatarConfiguration: AvatarConfiguration?
    @State private var showDebugHUD = false
    @State private var showSettings = false
    @State private var showAvatarEditor = false
    @State private var editingConfiguration = AvatarConfiguration.default
    @State private var carePulse = false
    @State private var statusMessage: String?
    @State private var careFXVisual: CareFXVisual?
    @State private var careFXToken = UUID()
    @State private var lifeOffsetY: CGFloat = 0
    @State private var lifeScale: CGFloat = 1
    @State private var lifeRotation: Double = 0
    @State private var expressionRestoreTask: DispatchWorkItem?
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
                    Menu {
                        Button("Settings") { showSettings = true }
                        Button("Edit look") {
                            editingConfiguration = avatarConfiguration
                            showAvatarEditor = true
                        }
                        Button("Memorial") { appModel.showMemorial() }
                    } label: {
                        Text("Menu")
                            .font(.caption.weight(.semibold))
                    }
                    .accessibilityLabel("Menu")
                    .accessibilityHint("Settings, edit look, or memorial")
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
                    .accessibilityAddTraits(.isHeader)

                if let pet {
                    Text("\(pet.lifeStage.displayName) · \(ageLabel(pet.ageDays))")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                        .accessibilityLabel("\(pet.lifeStage.displayName), \(ageLabel(pet.ageDays)) old")
                }

                statusBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .accessibilityElement(children: .combine)

                ZStack {
                    PetCharacterView(
                        expression: $expression,
                        avatarConfiguration: avatarConfiguration,
                        reduceMotion: reduceMotion
                    )
                    .id(characterViewID)
                    .offset(y: lifeOffsetY)
                    .scaleEffect(lifeScale * (carePulse ? 1.06 : 1.0))
                    .rotationEffect(.degrees(lifeRotation))
                    .opacity(carePulse ? 0.92 : 1.0)
                    .accessibilityLabel("Pet avatar, \(expression.displayName) expression")

                    if carePulse {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.45), lineWidth: 3)
                            .frame(width: 160, height: 160)
                            .scaleEffect(carePulse ? 1.25 : 0.85)
                            .opacity(carePulse ? 0 : 0.7)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .overlay {
                    if let careFXVisual {
                        CareFXBurstView(
                            visual: careFXVisual,
                            reduceMotion: reduceMotion
                        ) {
                            self.careFXVisual = nil
                        }
                        .id(careFXToken)
                    }
                }

                if let pet {
                    NeedsMetersView(needs: pet.needs)
                        .padding(.horizontal, 16)
                    Text("High bars = healthy needs")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .accessibilityHidden(true)

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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAvatarEditor) {
            NavigationStack {
                AvatarEditorView(
                    configuration: $editingConfiguration,
                    continueTitle: "Save look"
                ) {
                    saveEditedAvatar()
                }
                .navigationTitle("Edit look")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAvatarEditor = false }
                    }
                }
            }
        }
        .onAppear {
            remountHeadIfAvatarChanged()
            Task { await runDeviceTickAndSyncExpression() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await runDeviceTickAndSyncExpression() }
            }
        }
        .onChange(of: avatarConfiguration) { _, _ in
            remountHeadIfAvatarChanged()
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
                    .accessibilityLabel("Needs medicine, feeling ill")
            } else if pet.needs.health <= config.criticalHealthThreshold {
                Text("Health is low — care soon")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.96, green: 0.88, blue: 0.72).opacity(0.95), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Health is low, care soon")
            } else if pet.state.isSleeping {
                Text("Sleeping — energy recovering")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Sleeping, energy recovering")
            } else if pet.needs.energy <= config.criticalThreshold {
                Text("Low energy — Sleep to recover")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.25, green: 0.35, blue: 0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.86, green: 0.90, blue: 0.96).opacity(0.95), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Low energy, sleep to recover")
            } else if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("High bars = healthy needs. Feed fills Food.")
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isIllOrCritical)
    }

    private func ageLabel(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    private func remountHeadIfAvatarChanged() {
        let current = avatarConfiguration
        if lastAvatarConfiguration != current {
            lastAvatarConfiguration = current
            characterViewID = UUID()
        }
    }

    private func saveEditedAvatar() {
        do {
            try appModel.repository.updateAvatar(editingConfiguration.clamped())
            remountHeadIfAvatarChanged()
            showAvatarEditor = false
            statusMessage = "Look saved"
        } catch {
            appModel.userFacingError = "Couldn’t save the new look."
        }
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
            statusMessage = "\(type.displayName) ✓"
            triggerCareFeedback(for: type)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if statusMessage?.hasPrefix(type.displayName) == true {
                    statusMessage = nil
                }
            }
        } catch {
            statusMessage = "Couldn’t apply care"
        }
    }

    private func triggerCareFeedback(for type: CareEventType) {
        CareSoundPlayer.playCareSuccessIfEnabled()
        if AppPreferences.hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        if let visual = CareFXCatalog.visual(for: type) {
            careFXToken = UUID()
            careFXVisual = visual
        }

        expressionRestoreTask?.cancel()
        expression = CareFXCatalog.flashExpression(for: type)
        let restore = DispatchWorkItem {
            syncExpressionFromPet()
        }
        expressionRestoreTask = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: restore)

        // Soft glow pulse for medicine always; for others when motion allowed.
        let shouldPulse = type == .medicine || !reduceMotion
        if shouldPulse {
            withAnimation(.easeOut(duration: 0.18)) {
                carePulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeIn(duration: 0.28)) {
                    carePulse = false
                }
            }
        }

        guard !reduceMotion else { return }
        playLifeMotion(for: type)
    }

    private func playLifeMotion(for type: CareEventType) {
        lifeOffsetY = 0
        lifeScale = 1
        lifeRotation = 0
        switch type {
        case .feed, .water:
            withAnimation(.easeInOut(duration: 0.12)) { lifeOffsetY = 8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.12)) { lifeOffsetY = -4 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(.easeInOut(duration: 0.12)) { lifeOffsetY = 6 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                withAnimation(.easeOut(duration: 0.14)) { lifeOffsetY = 0 }
            }
        case .play:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
                lifeScale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                    lifeScale = 1
                }
            }
        case .clean:
            withAnimation(.easeInOut(duration: 0.06)) { lifeRotation = -6 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.easeInOut(duration: 0.06)) { lifeRotation = 6 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.06)) { lifeRotation = -4 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeOut(duration: 0.08)) { lifeRotation = 0 }
            }
        case .medicine, .sleep, .wake:
            break
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
            ("Food", needs.hunger),
            ("Water", needs.hydration),
            ("Happy", needs.happiness),
            ("Health", needs.health),
            ("Clean", needs.cleanliness),
            ("Energy", needs.energy)
        ]
    }

    private var summary: String {
        rows.map { "\($0.0) \(Int($0.1.rounded())) percent" }.joined(separator: ", ")
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(label) \(Int(value.rounded())) percent")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Need meters. High bars mean healthy needs.")
        .accessibilityValue(summary)
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
                .accessibilityLabel(type.displayName)
                .accessibilityHint(hint(for: type))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Care actions")
    }

    private func hint(for type: CareEventType) -> String {
        switch type {
        case .feed: return "Fills Food bar"
        case .water: return "Fills Water bar"
        case .play: return "Fun but tiring — uses Energy, Food, Water, Clean"
        case .clean: return "Fills Clean bar"
        case .medicine: return "Raises health and clears illness"
        case .sleep: return "Recovers Energy while sleeping"
        case .wake: return "Wakes the pet"
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
