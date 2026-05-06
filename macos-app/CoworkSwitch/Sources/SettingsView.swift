import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MenuBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("settings.title"))
                        .font(.title3.weight(.semibold))
                    Text(L10n.tr("settings.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack {
                Text(L10n.tr("settings.gateway_endpoint"))
                    .foregroundStyle(.secondary)
                Text(model.endpointDescription)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    L10n.tr("launch_at_login.toggle"),
                    isOn: Binding(
                        get: { model.launchAtLogin.isEnabled },
                        set: { newValue in
                            Task {
                                await model.launchAtLogin.toggle(newValue)
                            }
                        }
                    )
                )

                Text(model.launchAtLogin.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(L10n.tr("launch_at_login.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !model.launchAtLogin.errorMessage.isEmpty {
                    Text(model.launchAtLogin.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Picker(L10n.tr("settings.active_provider"), selection: $model.draftConfig.activeProviderId) {
                    ForEach(model.draftConfig.providers) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .frame(maxWidth: 280)

                Menu(L10n.tr("settings.add_provider")) {
                    Button(L10n.tr("settings.add_provider_deepseek")) {
                        model.addDeepSeekProvider()
                    }

                    Button(L10n.tr("settings.add_provider_openrouter")) {
                        model.addOpenRouterProvider()
                    }

                    Button(L10n.tr("settings.add_provider_custom")) {
                        model.addCustomProvider()
                    }
                }

                Button(L10n.tr("settings.remove_provider")) {
                    model.removeSelectedProvider()
                }
                .disabled(model.draftConfig.providers.count <= 1)
            }

            if let index = model.selectedProviderIndex {
                Form {
                    TextField(
                        L10n.tr("settings.provider_name"),
                        text: Binding(
                            get: { model.draftConfig.providers[index].name },
                            set: { model.updateSelectedProviderName($0) }
                        )
                    )

                    TextField(
                        L10n.tr("settings.base_url"),
                        text: Binding(
                            get: { model.draftConfig.providers[index].baseUrl },
                            set: { model.updateSelectedProviderBaseURL($0) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    SecureField(
                        L10n.tr("settings.api_key"),
                        text: Binding(
                            get: { model.draftConfig.providers[index].apiKey },
                            set: { model.updateSelectedProviderAPIKey($0) }
                        )
                    )

                    Toggle(
                        L10n.tr("settings.fake_models_toggle"),
                        isOn: Binding(
                            get: { model.draftConfig.providers[index].useFakeModels },
                            set: { model.updateSelectedProviderUseFakeModels($0) }
                        )
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("settings.fake_model_ids"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(
                            text: Binding(
                                get: { model.fakeModelsText },
                                set: { model.updateFakeModelsText($0) }
                            )
                        )
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .formStyle(.grouped)
            }

            if !model.lastErrorMessage.isEmpty {
                Text(model.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(L10n.tr("settings.reload")) {
                    Task {
                        await model.refreshAll()
                    }
                }

                Spacer()

                Button(model.isSaving ? L10n.tr("settings.saving") : L10n.tr("settings.save")) {
                    Task {
                        await model.saveConfig()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isSaving)
            }
        }
        .padding(20)
        .frame(width: 620, height: 520)
    }
}
