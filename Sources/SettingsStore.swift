import Foundation
import Combine

/// Адрес dsh web (ровно та строка, которую печатает `dsh web`: http://<host>:3080/?token=...).
/// Токен в ней меняется при каждом перезапуске dsh web — обновляется тут же, в приложении,
/// без пересборки IPA (точно так же, как /token в Telegram-боте).
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let key = "dsh.serverURL"

    @Published var serverURLString: String {
        didSet { UserDefaults.standard.set(serverURLString, forKey: key) }
    }

    private init() {
        self.serverURLString = UserDefaults.standard.string(forKey: key) ?? ""
    }

    var serverURL: URL? {
        let trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var isConfigured: Bool { serverURL != nil }
}
