import CoreLocation
import MapKit
import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var locationProvider = LocationProvider()
    @State private var deepLinkURL = URL(string: "cosmokittestapp://profile/settings")
    @State private var pushTitle = "Welcome to the app!"
    @State private var pushBody = "Thanks for downloading. Explore all the features available to you."
    @State private var requests: [ProxyDemoRequest] = []
    @State private var isRunningProxyDemo = false
    @State private var mapPosition: MapCameraPosition = .region(.init(center: .timesSquare, span: .defaultSpan))

    private let demoDelayNanoseconds: UInt64 = 800_000_000

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeader

                VStack(spacing: 14) {
                    statsCard
                    locationCard
                    deepLinksCard
                    pushCard
                    networkProxyCard
                    LogsCard()
                    PermissionsCard()
                    EnvironmentCard()
                    DefaultsCard()
                    AppDataCard()
                }
                .padding(.horizontal, 22)
                .padding(.top, -22)
                .padding(.bottom, 28)
            }
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.99))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            locationProvider.start()
        }
        .onOpenURL { url in
            deepLinkURL = url
        }
        .onReceive(locationProvider.$currentCoordinate.compactMap { $0 }) { coordinate in
            mapPosition = .region(.init(center: coordinate, span: .defaultSpan))
        }
        .onReceive(NotificationCenter.default.publisher(for: .cosmoKitPushReceived)) { notification in
            let userInfo = notification.userInfo ?? [:]
            pushTitle = (userInfo["title"] as? String)?.isEmpty == false ? userInfo["title"] as? String ?? pushTitle : pushTitle
            pushBody = (userInfo["body"] as? String)?.isEmpty == false ? userInfo["body"] as? String ?? pushBody : pushBody
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "A855F7"), Color(hex: "EC4899"), Color(hex: "F97316")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 250)

            FloatingParticlesView()
                .frame(height: 250)
                .clipped()

            VStack(spacing: 15) {
                Image(systemName: "rectangle.3.group.bubble")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))

                VStack(spacing: 6) {
                    Text("CosmoKit")
                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Simulator Control Panel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                HStack(spacing: 10) {
                    heroChip("GPS", icon: "location.fill")
                    heroChip("Push", icon: "bell.fill")
                    heroChip("Links", icon: "link")
                    heroChip("Proxy", icon: "network")
                }
            }
            .padding(.bottom, 38)
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem("6", label: "Features", icon: "star.fill")
            Divider().frame(height: 38)
            statItem("3", label: "Speeds", icon: "speedometer")
            Divider().frame(height: 38)
            statItem("9+", label: "HTTP Tests", icon: "arrow.up.arrow.down")
        }
        .frame(height: 68)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private var locationCard: some View {
        FeaturePanel(icon: "location.fill", iconColor: .blue, title: "Location Simulation", subtitle: "GPS mock + route simulation", borderColor: .blue) {
            VStack(spacing: 12) {
                Map(position: $mapPosition) {
                    Marker("Target", coordinate: .timesSquare)
                    if let coordinate = locationProvider.currentCoordinate {
                        Marker("Simulator", systemImage: "location.fill", coordinate: coordinate)
                            .tint(.blue)
                    }
                }
                .frame(height: 182)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack {
                    Label("Route in progress", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("1 points")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 12) {
                    coordinateBox("Latitude", value: String(format: "%.6f", locationProvider.currentCoordinate?.latitude ?? 40.758000), icon: "arrow.up.arrow.down")
                    coordinateBox("Longitude", value: String(format: "%.6f", locationProvider.currentCoordinate?.longitude ?? -73.985500), icon: "arrow.left.arrow.right")
                }
            }
        }
    }

    private var deepLinksCard: some View {
        FeaturePanel(icon: "link", iconColor: .orange, title: "Deep Links", subtitle: "URL scheme testing", borderColor: nil) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Received URL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.gray)
                Text(deepLinkURL?.absoluteString ?? "cosmokittestapp://profile/settings")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }

    private var pushCard: some View {
        FeaturePanel(icon: "bell.fill", iconColor: .pink, title: "Push Notifications", subtitle: "APNS payload testing", borderColor: .pink) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "app.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pushTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.84))
                    Text(pushBody)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray)
                        .lineLimit(3)
                }

                Spacer()
                Text("now")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
            }
            .padding(13)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var networkProxyCard: some View {
        FeaturePanel(icon: "network", iconColor: .cyan, title: "Network Proxy", subtitle: "Request interception & mocking", borderColor: nil) {
            VStack(spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 9) {
                    requestButton("GET", tint: .blue) { await perform(.get) }
                    requestButton("POST", tint: .green) { await perform(.post) }
                    requestButton("PUT", tint: .orange) { await perform(.put) }
                    requestButton("404", tint: .red) { await perform(.notFound) }
                    requestButton("500", tint: .purple) { await perform(.serverError) }
                    requestButton("JSON", tint: .cyan) { await perform(.json) }
                    requestButton("Delay 2s", tint: .gray) { await perform(.delay) }
                    requestButton("Image", tint: .pink) { await perform(.image) }
                    requestButton("Headers", tint: .indigo) { await perform(.headers) }
                }

                Button {
                    runProxyDemoSequence()
                } label: {
                    Label(isRunningProxyDemo ? "Running demo..." : "Run Proxy Demo", systemImage: isRunningProxyDemo ? "hourglass" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isRunningProxyDemo)
                .accessibilityIdentifier("runProxyDemoButton")

                if !requests.isEmpty {
                    VStack(spacing: 7) {
                        HStack {
                            Text("Recent Requests")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.gray)
                            Spacer()
                            Button("Clear") { requests.removeAll() }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.cyan)
                        }

                        ForEach(requests.prefix(3)) { request in
                            requestRow(request)
                        }
                    }
                }
            }
        }
    }

    private func heroChip(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 24)
            .background(.white.opacity(0.22), in: Capsule())
    }

    private func statItem(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.indigo)
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func coordinateBox(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: 60)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func requestButton(_ title: String, tint: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(tint.opacity(0.24), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isRunningProxyDemo)
    }

    private func requestRow(_ request: ProxyDemoRequest) -> some View {
        HStack(spacing: 7) {
            Text(request.endpoint.method.rawValue)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(request.methodColor, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text("\(request.statusCode)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(request.statusColor)
            Text(request.endpoint.path)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.gray)
                .lineLimit(1)
            Spacer()
            Text(request.elapsedText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(request.statusColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func runProxyDemoSequence() {
        guard !isRunningProxyDemo else { return }
        isRunningProxyDemo = true
        Task {
            // Fire each request on a steady cadence WITHOUT waiting for its
            // response, so they stream into CosmoKit's inspector at an even rhythm
            // regardless of per-host latency or cold starts — smooth on camera.
            for endpoint in DemoEndpoint.demoSequence {
                Task { await perform(endpoint) }
                try? await Task.sleep(nanoseconds: demoDelayNanoseconds)
            }
            // Let the final responses settle before re-enabling the button.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { isRunningProxyDemo = false }
        }
    }

    private func perform(_ endpoint: DemoEndpoint) async {
        let startedAt = Date()
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 8
        endpoint.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Use a FRESH session per request rather than URLSession.shared.
        // URLSession.shared snapshots the system proxy at first use and caches it
        // for the process lifetime — so if the app launched before CosmoKit's proxy
        // was enabled, every request kept routing to a stale/absent proxy and failed
        // instantly (-1) without ever reaching the inspector. A fresh ephemeral
        // session re-reads the live system proxy on each call.
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (_, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            NSLog("[DEMO] %@ %@ -> %d", endpoint.method.rawValue, endpoint.urlString, statusCode)
            addRequest(endpoint, statusCode: statusCode, elapsed: Date().timeIntervalSince(startedAt))
        } catch {
            let ns = error as NSError
            NSLog("[DEMO] %@ %@ FAILED code=%ld domain=%@ desc=%@",
                  endpoint.method.rawValue, endpoint.urlString, ns.code, ns.domain, ns.localizedDescription)
            // Surface the real URLError code (e.g. -1004 cannotConnect, -1200 TLS)
            // in the row instead of a generic -1, so failures are diagnosable.
            addRequest(endpoint, statusCode: ns.code, elapsed: Date().timeIntervalSince(startedAt))
        }
    }

    @MainActor
    private func addRequest(_ endpoint: DemoEndpoint, statusCode: Int, elapsed: TimeInterval) {
        requests.insert(.init(endpoint: endpoint, statusCode: statusCode, elapsed: elapsed), at: 0)
        requests = Array(requests.prefix(12))
    }
}

struct FeaturePanel<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let borderColor: Color?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.13))
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 45, height: 45)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.86))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                }

                Spacer()
                if borderColor != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.green)
                }
            }

            content
        }
        .padding(18)
        .background(Color(red: 0.98, green: 0.98, blue: 1.0), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((borderColor ?? .clear).opacity(0.55), lineWidth: borderColor == nil ? 0 : 2)
        }
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }
}

private struct FloatingParticlesView: View {
    private let particles = (0..<18).map { _ in
        Particle(
            x: Double.random(in: 0.05...0.95),
            y: Double.random(in: 0.05...0.95),
            size: CGFloat.random(in: 4...10),
            opacity: Double.random(in: 0.12...0.35)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(particles.enumerated()), id: \.offset) { _, particle in
                Circle()
                    .fill(.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(x: proxy.size.width * particle.x, y: proxy.size.height * particle.y)
            }
        }
    }
}

private struct Particle {
    let x: Double
    let y: Double
    let size: CGFloat
    let opacity: Double
}

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentCoordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            manager.requestLocation()
        case .denied, .restricted:
            currentCoordinate = .timesSquare
        @unknown default:
            currentCoordinate = .timesSquare
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        start()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentCoordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if currentCoordinate == nil {
            currentCoordinate = .timesSquare
        }
    }
}

private struct ProxyDemoRequest: Identifiable {
    let id = UUID()
    let endpoint: DemoEndpoint
    let statusCode: Int
    let elapsed: TimeInterval

    var statusColor: Color {
        switch statusCode {
        case 200..<300: return .green
        case 400..<500: return .red
        case 500..<600: return .purple
        default: return .orange
        }
    }

    var methodColor: Color {
        switch endpoint.method {
        case .get: return .blue
        case .post: return .green
        case .put: return .orange
        }
    }

    var elapsedText: String {
        elapsed >= 1 ? String(format: "%.1fs", elapsed) : "\(Int(elapsed * 1000))ms"
    }
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

private struct DemoEndpoint {
    let method: HTTPMethod
    let urlString: String
    let path: String          // shown in the in-app "Recent Requests" list
    let brand: String         // how CosmoKit's proxy groups it (host-derived)
    var headers: [String: String] = ["X-CosmoKit-Demo": "proxy-video"]
    var body: Data? = nil

    var url: URL { URL(string: urlString)! }

    // MARK: Quick-test buttons (ad-hoc, point at httpbin)
    static let get = DemoEndpoint(method: .get, urlString: "https://httpbin.org/get", path: "/get", brand: "httpbin")
    static let post = DemoEndpoint(method: .post, urlString: "https://httpbin.org/post", path: "/post", brand: "httpbin",
                                   body: #"{"source":"CosmoKitTestApp","action":"post-demo"}"#.data(using: .utf8))
    static let put = DemoEndpoint(method: .put, urlString: "https://httpbin.org/put", path: "/put", brand: "httpbin",
                                  body: #"{"source":"CosmoKitTestApp","action":"put-demo","enabled":true}"#.data(using: .utf8))
    static let notFound = DemoEndpoint(method: .get, urlString: "https://httpbin.org/status/404", path: "/status/404", brand: "httpbin")
    static let serverError = DemoEndpoint(method: .get, urlString: "https://httpbin.org/status/500", path: "/status/500", brand: "httpbin")
    static let json = DemoEndpoint(method: .get, urlString: "https://httpbin.org/json", path: "/json", brand: "httpbin")
    static let delay = DemoEndpoint(method: .get, urlString: "https://httpbin.org/delay/2", path: "/delay/2", brand: "httpbin")
    static let image = DemoEndpoint(method: .get, urlString: "https://httpbin.org/image/png", path: "/image/png", brand: "httpbin")
    static let headers = DemoEndpoint(method: .get, urlString: "https://httpbin.org/headers", path: "/headers", brand: "httpbin",
                                      headers: ["X-CosmoKit-Demo": "proxy-video", "X-Request-Source": "CosmoKitTestApp"])

    // MARK: Ad demo — curated traffic that maps to recognizable brands in
    // CosmoKit's proxy inspector (host → brand). Hitting several hosts, with a
    // couple of requests each, shows off domain grouping, collapse/expand and the
    // brand-name extraction. All are read-only GETs (safe against real backends);
    // the OpenAI POST has no key so it 401s harmlessly. Mixed statuses are
    // intentional — real apps have them, and it shows the colored badges.
    static let demoSequence: [DemoEndpoint] = [
        // CosmoFinanças — 2 requests (shows brand grouping + collapse)
        DemoEndpoint(method: .get, urlString: "https://api.cosmofinancas.org/api/health", path: "/api/health", brand: "CosmoFinanças"),
        DemoEndpoint(method: .get, urlString: "https://cosmofinancas.org/", path: "/", brand: "CosmoFinanças"),
        // LifeManager
        DemoEndpoint(method: .get, urlString: "https://api.managerme.org/api/health", path: "/api/health", brand: "LifeManager"),
        DemoEndpoint(method: .get, urlString: "https://managerme.org/", path: "/", brand: "LifeManager"),
        // CosmoRemote
        DemoEndpoint(method: .get, urlString: "https://api.cosmoremote.com/health", path: "/health", brand: "CosmoRemote"),
        DemoEndpoint(method: .get, urlString: "https://cosmoremote.com/", path: "/", brand: "CosmoRemote"),
        // Google APIs (real 200 JSON)
        DemoEndpoint(method: .get, urlString: "https://www.googleapis.com/oauth2/v3/certs", path: "/oauth2/v3/certs", brand: "Google APIs"),
        // RevenueCat
        DemoEndpoint(method: .get, urlString: "https://api.revenuecat.com/v1/health", path: "/v1/health", brand: "RevenueCat"),
        // Google (search)
        DemoEndpoint(method: .get, urlString: "https://www.google.com/", path: "/", brand: "Google"),
        // DuckDuckGo
        DemoEndpoint(method: .get, urlString: "https://duckduckgo.com/", path: "/", brand: "DuckDuckGo"),
        // Firebase — unauth read → 404 (one realistic "caught issue" for the demo)
        DemoEndpoint(method: .get, urlString: "https://cosmo-demo.firebaseio.com/users.json", path: "/users.json", brand: "Firebase"),
    ]
    // NOTE: hosts in CosmoKit's proxy bypass list (apple.com, openai.com,
    // anthropic.com, github.com, banks, messengers, …) are intentionally NOT
    // MITM'd, so they won't appear in the inspector — keep the demo to
    // non-bypassed hosts so every request shows up.
}

private extension CLLocationCoordinate2D {
    static let timesSquare = CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855)
}

private extension MKCoordinateSpan {
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    ContentView()
}
