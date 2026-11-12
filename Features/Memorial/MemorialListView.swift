import SwiftUI

struct MemorialListView: View {
    @Bindable var appModel: AppModel

    private var memorials: [PetMemorialRecord] {
        appModel.repository.memorials
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                HStack {
                    Button("Back") {
                        appModel.showPetHome()
                    }
                    .accessibilityHint("Returns to pet home or welcome")
                    Spacer()
                    Text("Memorial")
                        .font(.headline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Color.clear.frame(width: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if memorials.isEmpty {
                    Spacer()
                    Text("No memorials yet")
                        .font(.title3.weight(.semibold))
                    Text("When a pet’s journey ends, they’ll be remembered here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                } else {
                    List(memorials) { entry in
                        HStack(spacing: 14) {
                            AvatarThumbnailView(configuration: entry.avatarConfiguration)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name)
                                    .font(.headline)
                                Text("Passed \(entry.deathDate.formatted(date: .abbreviated, time: .omitted)) · \(entry.ageDays) days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(entry.finalCondition.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.name), passed \(entry.deathDate.formatted(date: .abbreviated, time: .omitted)), lived \(entry.ageDays) days, \(entry.finalCondition)")
                    }
                    .scrollContentBackground(.hidden)
                }

                if !appModel.repository.hasCompletedOnboarding {
                    Button {
                        appModel.startOnboarding()
                    } label: {
                        Text("Create new pet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(24)
                    .accessibilityHint("Starts creating a new companion")
                } else {
                    Button("Back to pet") {
                        appModel.showPetHome()
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            appModel.repository.refresh()
        }
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
