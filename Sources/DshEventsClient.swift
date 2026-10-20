import Foundation

/// Состояние агента, которое показываем в уведомлениях и Live Activity.
/// detail у .running — лучшее предположение о том, чем агент занят прямо сейчас
/// (думает / пишет код / читает файлы / выполняет команду), см. activityDetail(for:value:)
/// в DshEventsClient. Точный протокол dsh web для таких событий не документирован тут,
/// так что это эвристика по названию события/инструмента, а не гарантированный факт.
enum DshState: Equatable {
    case disconnected
    case idle
    case running(detail: String?)
    case waitingApproval(String)
}

/// Минимальный клиент протокола dsh web — ровно та же авторизация и тот же `$events`-поток,
/// что использует Telegram-бот (dsh_tg_bridge.py: Dsh.login() + WS /api/remote.mux + stream "ev").
/// Не трогает текущую сессию в самом WebView — это отдельное, параллельное соединение только
/// для того, чтобы знать, когда слать локальное уведомление / обновлять Live Activity.
@MainActor
final class DshEventsClient: NSObject, ObservableObject {
    @Published private(set) var state: DshState = .disconnected

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectDelay: TimeInterval = 3
    private var reconnectWorkItem: DispatchWorkItem?
    private var clientId: String?

    private var base: String = ""
    private var token: String = ""
    private var cookie: String?

    /// Последняя известная "чем занят" подсказка, пока сессия running — переживает
    /// повторные api-session/status(true), но сбрасывается, когда сессия становится idle.
    private var lastRunningDetail: String?

    func start(serverURL: URL) {
        stop()
        guard let comps = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else { return }
        guard let scheme = comps.scheme, let host = comps.host else { return }
        let port = comps.port.map { ":\($0)" } ?? ""
        base = "\(scheme)://\(host)\(port)"
        token = comps.queryItems?.first(where: { $0.name == "token" })?.value ?? ""
        connect()
    }

    func stop() {
        reconnectWorkItem?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    private func connect() {
        guard !token.isEmpty, !base.isEmpty else { return }
        Task {
            do {
                try await login()
                openSocket()
            } catch {
                scheduleReconnect()
            }
        }
    }

    private func login() async throws {
        guard var comps = URLComponents(string: base) else { throw URLError(.badURL) }
        comps.path = "/"
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = comps.url else { throw URLError(.badURL) }

        let config = URLSessionConfiguration.ephemeral // сами держим cookie, не доверяем системному стору
        let s = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await s.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // URLSession обычно схлопывает несколько Set-Cookie в одну строку через запятую —
        // ищем именно подстроку dsh-auth-, как это делает Dsh.login() в боте, а не парсим строго
        var setCookie = ""
        for (key, value) in http.allHeaderFields {
            if let k = key as? String, k.lowercased() == "set-cookie", let v = value as? String {
                setCookie = v
                break
            }
        }
        guard let range = setCookie.range(of: "dsh-auth-") else {
            throw URLError(.userAuthenticationRequired)
        }
        let fromAuth = String(setCookie[range.lowerBound...])
        cookie = fromAuth.components(separatedBy: ";").first?
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces)
    }

    private func openSocket() {
        guard let cookie else { scheduleReconnect(); return }
        var wsBase = base
        if wsBase.hasPrefix("https") { wsBase = "wss" + wsBase.dropFirst(5) }
        else if wsBase.hasPrefix("http") { wsBase = "ws" + wsBase.dropFirst(4) }
        guard let url = URL(string: wsBase + "/api/remote.mux") else { return }

        var request = URLRequest(url: url)
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        let config = URLSessionConfiguration.default
        let s = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        session = s
        let t = s.webSocketTask(with: request)
        task = t
        t.resume()
        reconnectDelay = 3

        let openFrame: [String: Any] = [
            "type": "open",
            "streamId": "ev",
            "endpoint": "$events",
            "payload": ["args": [String: Any]()],
        ]
        send(openFrame)
        receiveLoop()
    }

    private func send(_ obj: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handle(text)
                    }
                    self.receiveLoop()
                case .failure:
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard obj["type"] as? String == "item", obj["streamId"] as? String == "ev",
              let value = obj["value"] as? [String: Any] else { return }

        switch value["type"] as? String {
        case "ready":
            clientId = value["clientId"] as? String
        case "emit":
            guard value["event"] as? String == "api-session/status",
                  let args = value["args"] as? [Any], args.count >= 2,
                  let running = args[1] as? Bool else { return }
            if case .waitingApproval = state { return } // ожидание подтверждения приоритетнее статуса сессии
            if running {
                state = .running(detail: lastRunningDetail)
            } else {
                lastRunningDetail = nil
                state = .idle
            }
        case "waterfall":
            guard let event = value["event"] as? String else { return }
            if event == "approval/request" {
                let request = value["request"] as? [String: Any]
                let toolName = request?["toolName"] as? String ?? "действие"
                state = .waitingApproval("Нужно подтверждение: \(toolName)")
            } else if event == "user-questions/request" {
                state = .waitingApproval("Агент задал вопрос")
            } else if let detail = activityDetail(for: event, value: value) {
                lastRunningDetail = detail
                if case .running = state { state = .running(detail: detail) }
            }
        default:
            break
        }
    }

    /// Best-effort подсказка "чем занят агент" по имени waterfall-события и, если есть,
    /// имени инструмента в нём. Протокол dsh web не документирован в этом репозитории —
    /// если имена событий/инструментов другие, просто ничего не подсветится (безопасный
    /// fallback — останется общее "🧠 Думает…").
    private func activityDetail(for event: String, value: [String: Any]) -> String? {
        let lower = event.lowercased()
        let request = value["request"] as? [String: Any]
        if let toolName = request?["toolName"] as? String, lower.contains("tool") {
            return toolLabel(for: toolName)
        }
        if lower.contains("tool") {
            return "Выполняет действие"
        }
        if lower.contains("think") || lower.contains("reason") {
            return "Думает"
        }
        if lower.contains("message") || lower.contains("text") || lower.contains("answer") {
            return "Пишет ответ"
        }
        return nil
    }

    private func toolLabel(for toolName: String) -> String {
        switch toolName.lowercased() {
        case "edit", "write", "multiedit", "notebookedit":
            return "Пишет код"
        case "read":
            return "Читает файлы"
        case "bash", "shell", "terminal":
            return "Выполняет команду"
        case "grep", "glob", "search":
            return "Ищет по коду"
        default:
            return "Выполняет: \(toolName)"
        }
    }

    private func scheduleReconnect() {
        task = nil
        state = .disconnected
        reconnectWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.connect() }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay, execute: work)
        reconnectDelay = min(reconnectDelay * 2, 30)
    }
}
