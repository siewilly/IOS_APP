import SwiftUI
import WebKit

@MainActor
public final class Live2DBridgeController: ObservableObject {
    public weak var webView: WKWebView?
    @Published public var isEngineReady: Bool = false
    public var onTouchReaction: ((String, String) -> Void)?

    public init() {}

    /// Direct mouth opening control (0.0 to 1.0)
    public func setMouthOpen(_ value: Double) {
        let clamped = max(0.0, min(1.0, value))
        let script = "if (window.Live2DBridge) { window.Live2DBridge.setMouthOpen(\(clamped)); }"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Trigger a named motion group and optional index
    public func triggerMotion(group: String, index: Int? = nil) {
        let indexStr = index != nil ? "\(index!)" : "null"
        let script = "if (window.Live2DBridge) { window.Live2DBridge.triggerMotion('\(group)', \(indexStr)); }"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Set a facial expression by ID or name
    public func setExpression(_ expId: String) {
        let script = "if (window.Live2DBridge) { window.Live2DBridge.setExpression('\(expId)'); }"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Pause or resume rendering ticker (used when entering background or text-only mode)
    public func setPaused(_ isPaused: Bool) {
        let script = "if (window.Live2DBridge) { window.Live2DBridge.setPaused(\(isPaused)); }"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}

public struct Live2DWebView: UIViewRepresentable {
    @ObservedObject public var controller: Live2DBridgeController

    public init(controller: Live2DBridgeController) {
        self.controller = controller
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = preferences
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // Script message handlers for bidirectional lifecycle notifications
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "live2dReady")
        contentController.add(context.coordinator, name: "live2dError")
        contentController.add(context.coordinator, name: "live2dTap")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.navigationDelegate = context.coordinator

        controller.webView = webView
        loadWebEngine(in: webView)
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op to preserve rendering state
    }

    private func loadWebEngine(in webView: WKWebView) {
        // 1. Preferred: Subdirectory WebEngine folder reference
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebEngine"),
           let webEngineDir = Bundle.main.resourceURL?.appendingPathComponent("WebEngine") {
            webView.loadFileURL(indexURL, allowingReadAccessTo: webEngineDir)
            return
        }

        // 2. Direct resource lookup fallback
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            let readAccessDir = Bundle.main.resourceURL ?? Bundle.main.bundleURL
            webView.loadFileURL(indexURL, allowingReadAccessTo: readAccessDir)
            return
        }

        print("[Live2DWebView] Warning: WebEngine/index.html could not be located in bundle.")
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: Live2DWebView

        init(_ parent: Live2DWebView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "live2dReady" {
                Task { @MainActor in
                    self.parent.controller.isEngineReady = true
                    print("[Live2DWebView] Live2D WebEngine report: Ready.")
                }
            } else if message.name == "live2dError" {
                print("[Live2DWebView] Live2D WebEngine report error:", message.body)
            } else if message.name == "live2dTap" {
                if let dict = message.body as? [String: Any],
                   let area = dict["area"] as? String,
                   let text = dict["text"] as? String {
                    Task { @MainActor in
                        self.parent.controller.onTouchReaction?(area, text)
                    }
                }
            }
        }
    }
}
