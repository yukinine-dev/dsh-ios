import SwiftUI
import UIKit
import WebKit

/// Тонкая обёртка над WKWebView: просто показывает dsh web как есть, плюс pull-to-refresh
/// и возможность перезагрузить/вернуться назад кнопками сверху (см. ContentView).
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var reloadToken: Int
    @Binding var goBackToken: Int
    @Binding var canGoBack: Bool
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    /// Вызывается ровно один раз — когда страница в первый раз успешно догрузилась.
    /// Используется, чтобы DshEventsClient не лез за тем же токеном параллельно с
    /// самим WebView (см. комментарий у didFireFirstLoad) — иначе получается гонка
    /// за один и тот же токен, и кто-то из двух может остаться без сессии.
    var onFirstLoad: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // обычные cookies — токен dsh ставится как cookie при первом открытии
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.refreshControl = context.coordinator.refreshControl
        webView.load(URLRequest(url: url))
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            webView.load(URLRequest(url: url))
        }
        if context.coordinator.lastGoBackToken != goBackToken {
            context.coordinator.lastGoBackToken = goBackToken
            if webView.canGoBack { webView.goBack() }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        weak var webView: WKWebView?
        var lastReloadToken: Int = 0
        var lastGoBackToken: Int = 0
        /// true — первая успешная загрузка уже случилась, onFirstLoad больше не дёргаем
        /// (иначе он срабатывал бы на каждый ручной Reload, а нам нужен только самый первый раз).
        var didFireFirstLoad = false

        lazy var refreshControl: UIRefreshControl = {
            let rc = UIRefreshControl()
            rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
            return rc
        }()

        init(_ parent: WebView) {
            self.parent = parent
        }

        @objc func handleRefresh() {
            webView?.reload()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.loadError = nil
            refreshControl.endRefreshing()
            if !didFireFirstLoad {
                didFireFirstLoad = true
                parent.onFirstLoad?()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
            refreshControl.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
            refreshControl.endRefreshing()
        }
    }
}
