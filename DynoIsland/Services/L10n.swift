import Foundation

/// Uygulama içi metinler — PreferencesStore diline göre TR/EN.
/// `cachedIsTurkish` MainActor dışı da okunabilir (enum title vs.).
enum L10n {
    nonisolated(unsafe) static var cachedIsTurkish = true

    static var isTurkish: Bool { cachedIsTurkish }

    static func t(_ turkish: String, _ english: String) -> String {
        cachedIsTurkish ? turkish : english
    }

    // Tabs
    static var tabNowPlaying: String { t("Şimdi Çalıyor", "Now Playing") }
    static var tabClipboard: String { t("Pano", "Clipboard") }
    static var tabTasks: String { t("Görevler", "Tasks") }
    static var tabTimer: String { t("Zamanlayıcı", "Timer") }
    static var tabCounter: String { t("Sayaç", "Counter") }

    // Media
    static var unknownTitle: String { t("Bilinmeyen başlık", "Unknown title") }
    static var noMediaTitle: String { t("Şu anda oynatılan medya yok", "Nothing playing right now") }
    static var noMediaHint: String {
        t("Bir şarkı veya video başlat, kapak burada görünsün.", "Start a song or video to see artwork here.")
    }
    static var noMediaUnavailable: String {
        t(
            "Bu macOS sürümünde sistem medya bilgisini kullanamıyoruz.",
            "System media info isn’t available on this macOS version."
        )
    }
    static var play: String { t("Oynat", "Play") }
    static var pause: String { t("Duraklat", "Pause") }
    static var skipBack10: String { t("10 saniye geri", "Skip back 10 seconds") }
    static var skipForward10: String { t("10 saniye ileri", "Skip forward 10 seconds") }
    static var previousTrack: String { t("Önceki", "Previous") }
    static var nextTrack: String { t("Sonraki", "Next") }

    // Clipboard
    static var clipboardEmptyTitle: String { t("Pano geçmişi boş", "Clipboard history is empty") }
    static var clipboardEmptyHint: String {
        t("Kopyaladığın öğeler burada listelenir.", "Items you copy will show up here.")
    }
    static var clipboardClearConfirmTitle: String {
        t("Pano geçmişi temizlensin mi?", "Clear clipboard history?")
    }
    static var clipboardClearConfirmAction: String {
        t("Tüm geçmişi temizle", "Clear all history")
    }
    static var clipboardClearConfirmCancel: String { t("Vazgeç", "Cancel") }
    static var clipboardClearConfirmMessage: String {
        t(
            "Bu işlem yalnızca Dyno Island geçmişini siler; mevcut panon değişmez.",
            "This only clears Dyno Island history; your system clipboard stays unchanged."
        )
    }
    static var clipboardClearHelp: String {
        t("Pano geçmişini temizle", "Clear clipboard history")
    }
    static var copyToClipboard: String { t("Panoya kopyala", "Copy to clipboard") }
    static var copiedImage: String { t("Kopyalanan görsel", "Copied image") }
    static func fileCount(_ n: Int) -> String {
        t("\(n) dosya", "\(n) files")
    }

    // Tasks
    static var tasksEmptyTitle: String { t("Henüz görev yok", "No tasks yet") }
    static var tasksEmptyHint: String {
        t("Yukarıdan yeni bir görev ekle.", "Add a new task above.")
    }
    static var tasksEmptyFilterTitle: String {
        t("Bu filtrede görev yok", "Nothing in this filter")
    }
    static var tasksPlaceholder: String { t("Görev ekle…", "Add a task…") }
    static var tasksAdd: String { t("Görev ekle", "Add task") }
    static var tasksFilterAll: String { t("Tümü", "All") }
    static var tasksFilterActive: String { t("Aktif", "Active") }
    static var tasksFilterCompleted: String { t("Tamamlanan", "Completed") }
    static var tasksCompleteNext: String {
        t("Seçili görevi tamamla", "Complete selected task")
    }
    static var tasksDelete: String { t("Görevi sil", "Delete task") }
    static var tasksClearCompleted: String {
        t("Tamamlananları temizle", "Clear completed")
    }
    static var tasksActiveCountLabel: String {
        t("aktif görev", "active")
    }
    static var tasksShowOnIsland: String {
        t("Adada göster", "Show on island")
    }
    static func tasksCreatedAt(_ value: String) -> String {
        t("Oluşturuldu \(value)", "Created \(value)")
    }
    static func tasksCompletedAt(_ value: String) -> String {
        t("Tamamlandı \(value)", "Completed \(value)")
    }

    // Timer / Counter
    static var reset: String { t("Sıfırla", "Reset") }
    static var start: String { t("Başlat", "Start") }
    static var stop: String { t("Durdur", "Stop") }
    static var counterPlusHelp: String { t("Sayaç +1", "Counter +1") }
    static var counterNote: String { t("Sayaç notu", "Counter note") }

    // Header / chrome
    static var pinned: String { t("Sabit", "Pinned") }
    static var collapseToIsland: String { t("Dinamik adaya küçült", "Collapse to island") }
    static var pin: String { t("Sabitle", "Pin") }
    static var unpin: String { t("Sabitlemeyi kaldır", "Unpin") }
    static var settings: String { t("Ayarlar", "Settings") }
    static var expandIsland: String { t("Dyno Island’ı genişlet", "Expand Dyno Island") }
    static var expand: String { t("Genişlet", "Expand") }

    // Menu
    static var toggleIsland: String { t("Ada’yı Aç/Kapat", "Toggle Island") }
    static var quit: String { t("Çıkış Yap", "Quit") }

    // Settings
    static var settingsTitle: String { t("Ayarlar", "Settings") }
    static var aboutPane: String { t("Bilgi", "About") }
    static var preferencesPane: String { t("Tercihler", "Preferences") }
    static var language: String { t("Dil", "Language") }
    static var appearance: String { t("Tema", "Appearance") }
    static var appearanceSystem: String { t("Sistem", "System") }
    static var appearanceLight: String { t("Açık", "Light") }
    static var appearanceDark: String { t("Koyu", "Dark") }
    static var launchAtLogin: String { t("Sistem açılışında başlat", "Launch at login") }
    static var launchAtLoginHint: String {
        t(
            "Mac’e giriş yapınca Dyno Island otomatik açılsın",
            "Start Dyno Island automatically when you log in"
        )
    }
}
