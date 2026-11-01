import SwiftUI
import MoeedCore
import MoeedEngine
#if canImport(UIKit)
import UIKit
import WebKit
#endif

/// The university's own sign-in page, inside the app. The student types into Blackboard's form, not
/// ours: the app never reads the password. After each page loads it asks Blackboard who is signed in;
/// the first time that works, the session's cookies go to the Keychain and the sheet closes itself.
struct BlackboardSignIn: View {
    let model: LibraryModel
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        VStack(spacing: 0) {
            bar
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("سجّل دخولك كالعادة. أول ما تدخل، مُعيد يكمل لحاله.")
                .font(Typeface.plex(14))
                .foregroundStyle(Palette.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.bar)
                .overlay(alignment: .top) { Rectangle().fill(Palette.sep).frame(height: 0.5) }
        }
        .background(Palette.bg)
    }

    private var bar: some View {
        HStack {
            Button("إلغاء") { model.showSignIn = false }
                .font(Typeface.plex(16))
                .foregroundStyle(Palette.accent)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(verbatim: model.base.host ?? "")
                    .font(Typeface.plex(15, .medium))
                    .environment(\.layoutDirection, .leftToRight)
            }
            .foregroundStyle(Palette.text)
            Spacer()
            // Balances the cancel button so the address sits in the middle.
            Text("إلغاء").font(Typeface.plex(16)).hidden()
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(Palette.bar)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.sep).frame(height: 0.5) }
    }

    @ViewBuilder
    private var page: some View {
        #if canImport(UIKit)
        if isSnapshot {
            Palette.raised
        } else {
            SignInPage(base: model.base) { cookies in model.linked(cookies) }
        }
        #else
        Palette.raised
        #endif
    }
}

#if canImport(UIKit)
private struct SignInPage: UIViewRepresentable {
    let base: URL
    let found: @MainActor ([HTTPCookie]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(base: base, found: found)
    }

    func makeUIView(context: Context) -> WKWebView {
        // The default store keeps the university's own "remember me", so signing in again is often one tap.
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: base))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let base: URL
        let found: @MainActor ([HTTPCookie]) -> Void
        private var done = false
        private var checking = false

        init(base: URL, found: @escaping @MainActor ([HTTPCookie]) -> Void) {
            self.base = base
            self.found = found
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { await check(webView) }
        }

        /// Hands the page's cookies for Blackboard's host to a plain session and asks who is signed in.
        private func check(_ webView: WKWebView) async {
            guard !done, !checking, let host = base.host else { return }
            checking = true
            defer { checking = false }
            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            let ours = cookies.filter { cookie in
                let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                return host == domain || host.hasSuffix("." + domain)
            }
            guard !ours.isEmpty else { return }
            let client = BlackboardClient(base: base, session: LibraryModel.session(ours))
            guard (try? await client.me()) != nil else { return }
            done = true
            found(ours)
        }
    }
}
#endif
