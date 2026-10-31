import SwiftUI
import UserNotifications

// MARK: - Tema

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

enum Theme {
    static let bg = Color(light: 0xF4ECDF, dark: 0x14121F)
    static let card = Color(light: 0xFFFAF1, dark: 0x221F36)
    static let ink = Color(light: 0x1D1A2B, dark: 0xF1EAD8)
    static let line = Color(light: 0xD9CDB8, dark: 0x3A3655)
    static let hot = Color(light: 0xFF5A3C, dark: 0xFF7A59)
    static let warm = Color(light: 0xE69A0C, dark: 0xFFC04D)
    static let cool = Color(light: 0x118A7E, dark: 0x3FD0BD)
    static let mute = Color(light: 0x9A9283, dark: 0x7D7896)
}

// MARK: - Model & penyimpanan

struct Reminder: Identifiable, Codable {
    var id = UUID()
    var text: String
    var when: Date
    var created = Date()
}

final class Store: ObservableObject {
    @Published var items: [Reminder] = [] { didSet { save() } }
    private let key = "reminders.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([Reminder].self, from: d) {
            items = v
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    func add(_ text: String, at date: Date) {
        let r = Reminder(text: text, when: date)
        items.append(r)

        let content = UNMutableNotificationContent()
        content.title = "Pengingat"
        content.body = text
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: r.id.uuidString, content: content, trigger: trigger))
    }

    func remove(_ r: Reminder) {
        items.removeAll { $0.id == r.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [r.id.uuidString])
    }
}

// MARK: - Helper

func fmt(_ d: Date, _ pattern: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "id_ID")
    f.dateFormat = pattern
    return f.string(from: d)
}

func rel(_ s: TimeInterval) -> String {
    if s < 0 { return "terlewat" }
    let m = Int(s / 60)
    if m < 1 { return "kurang dari 1 mnt" }
    if m < 60 { return "dalam \(m) mnt" }
    let h = m / 60
    if h < 24 { return "dalam \(h)j \(m % 60)m" }
    return "dalam \(h / 24) hari"
}

func group(_ r: Reminder, _ now: Date) -> Int {
    if r.when <= now { return 3 }
    let cal = Calendar.current
    if cal.isDateInToday(r.when) { return 0 }
    if cal.isDateInTomorrow(r.when) { return 1 }
    return 2
}

func progress(_ p: Reminder?, _ now: Date) -> CGFloat {
    guard let p = p else { return 0 }
    let span = p.when.timeIntervalSince(p.created)
    if span <= 0 { return 1 }
    return CGFloat(min(1, max(0, now.timeIntervalSince(p.created) / span)))
}

struct VLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: 0))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

// MARK: - Kartu tiket

struct CardView: View {
    let r: Reminder
    let now: Date
    let g: Int
    let onDelete: () -> Void

    var hot: Bool { g != 3 && r.when.timeIntervalSince(now) < 3600 }
    var accent: Color {
        if hot { return Theme.hot }
        return [Theme.warm, Theme.cool, Theme.ink, Theme.mute][g]
    }
    var blink: Bool { Int(now.timeIntervalSince1970) % 2 == 0 }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(fmt(r.when, "HH:mm"))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                Text(fmt(r.when, "d MMM").uppercased())
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(accent)
            .frame(width: 84)
            .frame(maxHeight: .infinity)
            .background(accent.opacity(0.1))

            VLine()
                .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(r.text)
                    .font(.system(size: 18, design: .serif))
                    .strikethrough(g == 3)
                    .foregroundColor(Theme.ink)
                HStack(spacing: 6) {
                    if hot {
                        Circle().fill(Theme.hot).frame(width: 7, height: 7).opacity(blink ? 1 : 0.25)
                    }
                    Text(g == 3 ? "sudah berbunyi" : rel(r.when.timeIntervalSince(now)))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Image(systemName: "xmark").foregroundColor(Theme.mute)
            }
            .padding(.trailing, 16)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(g == 3 ? 0.55 : 1)
    }
}

// MARK: - Layar utama

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var showAdd = false
    private let names = ["Hari ini", "Besok", "Nanti", "Selesai"]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.bg.ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header(ctx.date)
                        nextCard(ctx.date)
                        list(ctx.date)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }

            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Theme.hot)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                    .background(Circle().fill(Theme.ink).offset(x: 4, y: 4))
            }
            .padding(24)
        }
        .sheet(isPresented: $showAdd) {
            AddView().environmentObject(store)
        }
    }

    func header(_ now: Date) -> some View {
        let h = Calendar.current.component(.hour, from: now)
        let hi = h < 11 ? "Selamat pagi" : h < 15 ? "Selamat siang" : h < 18 ? "Selamat sore" : "Selamat malam"
        return VStack(alignment: .leading, spacing: 0) {
            Text(hi)
                .font(.system(size: 20, design: .serif).italic())
                .foregroundColor(Theme.hot)
            Text(fmt(now, "HH:mm"))
                .font(.system(size: 84, weight: .light, design: .serif))
                .foregroundColor(Theme.ink)
            Text(fmt(now, "EEEE, d MMMM yyyy").uppercased())
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.mute)
        }
    }

    func nextCard(_ now: Date) -> some View {
        let p = store.items.filter { $0.when > now }.min { $0.when < $1.when }
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress(p, now))
                    .stroke(Theme.hot, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text("BERIKUTNYA")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.mute)
                Text(p?.text ?? "Tidak ada yang menunggu")
                    .font(.system(size: 19, design: .serif))
                    .foregroundColor(Theme.ink)
                    .lineLimit(2)
                Text(p.map { rel($0.when.timeIntervalSince(now)) } ?? "Santai dulu ☕")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Theme.hot)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    func list(_ now: Date) -> some View {
        let sorted = store.items.sorted { $0.when < $1.when }
        return VStack(alignment: .leading, spacing: 24) {
            if sorted.isEmpty {
                Text("Belum ada pengingat. Ketuk + untuk memasang yang pertama ✦")
                    .font(.system(size: 20, design: .serif).italic())
                    .foregroundColor(Theme.mute)
                    .padding(.top, 20)
            }
            ForEach(0..<4, id: \.self) { g in
                section(g, sorted, now)
            }
        }
    }

    @ViewBuilder
    func section(_ g: Int, _ all: [Reminder], _ now: Date) -> some View {
        let found = all.filter { group($0, now) == g }
        let rows = g == 3 ? Array(found.reversed()) : found
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(names[g].uppercased()) · \(rows.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.mute)
                ForEach(rows) { r in
                    CardView(r: r, now: now, g: g) { store.remove(r) }
                }
            }
        }
    }
}

// MARK: - Form tambah

struct AddView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var date = Date().addingTimeInterval(600)

    var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pengingat baru")
                        .font(.system(size: 28, design: .serif).italic())
                        .foregroundColor(Theme.hot)

                    TextField("Ingatkan saya untuk…", text: $text)
                        .font(.system(size: 22, design: .serif))
                        .foregroundColor(Theme.ink)
                    Rectangle().fill(Theme.line).frame(height: 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("+15 mnt") { Date().addingTimeInterval(15 * 60) }
                            chip("+1 jam") { Date().addingTimeInterval(3600) }
                            chip("Malam 20:00") {
                                let d = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
                                return d < Date() ? d.addingTimeInterval(86400) : d
                            }
                            chip("Besok 08:00") {
                                Calendar.current.date(bySettingHour: 8, minute: 0, second: 0,
                                                      of: Date().addingTimeInterval(86400))!
                            }
                        }
                    }

                    DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(Theme.hot)

                    Button {
                        store.add(trimmed, at: date)
                        dismiss()
                    } label: {
                        Text("Pasang pengingat ✦")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.hot)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: 2))
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink).offset(x: 4, y: 4))
                    }
                    .disabled(trimmed.isEmpty)
                    .opacity(trimmed.isEmpty ? 0.4 : 1)
                    .padding(.top, 6)
                }
                .padding(24)
            }
        }
    }

    func chip(_ title: String, _ make: @escaping () -> Date) -> some View {
        Button { date = make() } label: {
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1.5))
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        return true
    }

    // Tampilkan notifikasi juga saat aplikasi sedang dibuka.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@main
struct PengingatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
