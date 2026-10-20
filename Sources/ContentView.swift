import SwiftUI

struct ContentView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var events = DshEventsClient()
    @StateObject private var activity = LiveActivityManager()

    @State private var showSettings = false
    @State private var reloadToken = 0
    @State private var goBackToken = 0
    @State private var canGoBack = false
    @State private var isLoading = false

    var body: some View {
        Group {
            if let url = settings.serverURL {
                ZStack(alignment: .top) {
                    WebView(
                        url: url,
                        reloadToken: $reloadToken,
                        goBackToken: $goBackToken,
                        canGoBack: $canGoBack,
                        isLoading: $isLoading
                    )
                    .ignoresSafeArea(edges: .bottom)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .padding(.top, 1)
                    }
                }
                .safeAreaInset(edge: .top) {
                    toolbar
                }
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            if !settings.isConfigured { showSettings = true }
            NotificationManager.requestAuthorizationIfNeeded()
            if let url = settings.serverURL { events.start(serverURL: url) }
        }
        .onChange(of: settings.serverURLString) { _ in
            if let url = settings.serverURL { events.start(serverURL: url) }
        }
        .onChange(of: events.state) { newState in
            activity.handle(newState)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 20) {
            Button {
                goBackToken += 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoBack)

            Button {
                reloadToken += 1
            } label: {
                Image(systemName: "arrow.clockwise")
            }

            Spacer()

            Text("dsh")
                .font(.headline)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Адрес dsh web не задан")
                .font(.title3)
            Text("Открой настройки и вставь строку, которую печатает `dsh web` (http://.../?token=...)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Настройки") { showSettings = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Адрес dsh web") {
                    TextField("http://100.x.x.x:3080/?token=...", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section {
                    Text("Токен меняется при каждом перезапуске `dsh web` на компе — вставляй новую строку сюда же, пересобирать приложение не нужно.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        settings.serverURLString = draft
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onAppear { draft = settings.serverURLString }
        }
    }
}
