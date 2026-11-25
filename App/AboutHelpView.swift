import AppKit
import SwiftUI

/// Product identity shown in the About box, the Help window and the welcome window.
enum AppInfo {
    static let name = "PxStation Mac"
    static let projectURL = URL(string: "https://github.com/LucaMaroglio/pxstation-mac")!
    /// PxStation Mac is a fork of this project (MIT license).
    static let upstreamName = "macos-spice-client"
    static let upstreamAuthor = "Paweł Więcaszek"
    static let upstreamURL = URL(string: "https://github.com/pawelwiecaszek/macos-spice-client")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// "[year] - Luca Maroglio", from NSHumanReadableCopyright (set in the build settings).
    static var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? "Luca Maroglio"
    }
}

/// Logo from the asset catalog, used by the welcome, About and Help windows.
struct AppLogo: View {
    var size: CGFloat

    var body: some View {
        Image("PxStationLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 6) {
            AppLogo(size: 128)
                .padding(.bottom, 6)
            Text(AppInfo.name)
                .font(.title2.weight(.bold))
            Text("Version \(AppInfo.version)")
                .foregroundStyle(.secondary)
            Text(AppInfo.copyright)
                .foregroundStyle(.secondary)
        }
        .textSelection(.enabled)
        .padding(.horizontal, 48)
        .padding(.vertical, 28)
        .frame(minWidth: 300)
    }
}

// MARK: - Help

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    AppLogo(size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(AppInfo.name) Help")
                            .font(.title.weight(.semibold))
                        Text("Version \(AppInfo.version)")
                            .foregroundStyle(.secondary)
                    }
                }

                section("Connecting to a virtual machine") {
                    Text("Open a virt-viewer connection file (.vv) with File › Open Connection File… (⌘O), by double-clicking it in Finder or by dropping it on the welcome window. In Proxmox VE, click Console › SPICE: the browser downloads the file, whose ticket is valid for a few seconds and only once.")
                    Text("With a Proxmox server added under Settings › Proxmox, the Virtual Machines window (⌘0) lists your VMs and connects to them without downloading a file.")
                }

                section("Proxmox API access") {
                    Text("The Virtual Machines window, the Power menu and reconnecting with a fresh ticket need an API token (Datacenter › Permissions › API Tokens) with the VM.Audit, VM.PowerMgmt and VM.Console privileges, for example the PVEVMUser role on /vms. The token secret is stored in the Keychain.")
                }

                section("Keyboard") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        shortcut("⌘O", "Open a connection file")
                        shortcut("⌘0", "Virtual Machines window")
                        shortcut("⌃⌥⌘⌫", "Send Ctrl+Alt+Del to the guest")
                        shortcut("⌃⌘F", "Toggle full screen")
                    }
                    Text("⌘ is sent to the guest as the Windows key (Settings › General); ⌘Q, ⌘W, ⌘H, ⌘Tab and ⌘Space always stay with macOS.")
                }

                section("In the virtual machine") {
                    Text("Install spice-vdagent (Linux) or the SPICE guest tools (Windows) for the shared clipboard, file copy, a seamless pointer and automatic resolution. USB devices, disc images and smartcards each need a free Spice Port USB device in the VM's hardware.")
                }

                section("About this project") {
                    Text("\(AppInfo.name) is a fork of \(AppInfo.upstreamName) by \(AppInfo.upstreamAuthor), released under the MIT license.")
                    Link(AppInfo.upstreamURL.absoluteString, destination: AppInfo.upstreamURL)
                    Text("PxStation Mac project page:")
                    Link(AppInfo.projectURL.absoluteString, destination: AppInfo.projectURL)
                    Text(AppInfo.copyright)
                        .foregroundStyle(.secondary)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 620)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shortcut(_ keys: String, _ action: LocalizedStringKey) -> some View {
        GridRow {
            Text(keys).monospaced()
            Text(action)
        }
    }
}

// MARK: - Windows

/// AppKit-managed singleton window, like the welcome and VM list windows.
@MainActor
final class InfoWindow<Content: View> {
    private let title: () -> String
    private let style: NSWindow.StyleMask
    private let content: () -> Content
    private var window: NSWindow?

    init(title: @escaping () -> String, style: NSWindow.StyleMask, content: @escaping () -> Content) {
        self.title = title
        self.style = style
        self.content = content
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.styleMask = style
            window.title = title()
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

@MainActor
enum AboutWindow {
    static let shared = InfoWindow(
        title: { String(localized: "About \(AppInfo.name)") },
        style: [.titled, .closable, .fullSizeContentView]
    ) { AboutView() }
}

@MainActor
enum HelpWindow {
    static let shared = InfoWindow(
        title: { String(localized: "\(AppInfo.name) Help") },
        style: [.titled, .closable, .miniaturizable, .resizable]
    ) { HelpView() }
}
