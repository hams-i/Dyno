export type Locale = "en" | "tr";

export const locales: Locale[] = ["en", "tr"];

export type IslandTabKey = "media" | "clipboard" | "timer" | "counter";

export type FeatureDetail = {
  title: string;
  desc: string;
  points: string[];
};

export type Messages = {
  brand: string;
  tagline: string;
  nav: {
    features: string;
    demo: string;
    download: string;
    github: string;
  };
  hero: {
    badge: string;
    title: string;
    titleAccent: string;
    subtitle: string;
    cta: string;
    ctaSecondary: string;
  };
  islandTabs: Record<IslandTabKey, string>;
  features: {
    eyebrow: string;
    byTab: Record<IslandTabKey, FeatureDetail>;
  };
  controls: {
    language: string;
    theme: string;
    themeSystem: string;
    themeLight: string;
    themeDark: string;
    expand: string;
    collapse: string;
    collapseToIsland: string;
    pin: string;
    unpin: string;
    pinned: string;
    settings: string;
  };
  media: {
    app: string;
    title: string;
    artist: string;
    play: string;
    pause: string;
    previous: string;
    next: string;
    skipBack: string;
    skipForward: string;
  };
  clipboard: {
    empty: string;
    hint: string;
    copied: string;
    clear: string;
    samples: string[];
  };
  timer: {
    reset: string;
    start: string;
    stop: string;
  };
  counter: {
    notePlaceholder: string;
    decrease: string;
    increase: string;
  };
  footer: {
    license: string;
    made: string;
  };
};

const en: Messages = {
  brand: "Dyno Island",
  tagline: "Dynamic Island for your Mac notch",
  nav: {
    features: "Features",
    demo: "Demo",
    download: "Download",
    github: "GitHub",
  },
  hero: {
    badge: "Open source · macOS",
    title: "Your notch,",
    titleAccent: "alive.",
    subtitle:
      "Now Playing, clipboard history, timer, and counter — morphing smoothly between a compact island and a full panel.",
    cta: "Get Dyno Island",
    ctaSecondary: "View on GitHub",
  },
  islandTabs: {
    media: "Now Playing",
    clipboard: "Clipboard",
    timer: "Timer",
    counter: "Counter",
  },
  features: {
    eyebrow: "In the island",
    byTab: {
      media: {
        title: "Now Playing",
        desc: "See what’s playing in the notch — artwork, controls, and the timeline stay one glance away.",
        points: [
          "Album art morphs between the compact island and the full panel",
          "Skip, play, and pause without leaving your desktop",
          "Scrub the track or jump −10s / +10s from the notch",
        ],
      },
      clipboard: {
        title: "Clipboard",
        desc: "Everything you copy is kept in a scrollable history you can reuse instantly.",
        points: [
          "Browse recent copies in a compact three-column grid",
          "Tap any card to copy it again",
          "Clear the whole history in one step when you’re done",
        ],
      },
      timer: {
        title: "Timer",
        desc: "A precise stopwatch that shrinks into the island when you only need a quick look.",
        points: [
          "Centisecond accuracy, formatted like the Mac app",
          "Start, pause, and reset from the expanded panel",
          "Dock with the up arrow — play/pause stays on the island",
        ],
      },
      counter: {
        title: "Counter",
        desc: "Track reps, scores, or habits with a note beside the number.",
        points: [
          "Write a short note next to your running count",
          "Add, subtract, or reset without opening another app",
          "Dock to the island for a one-tap +1 at a glance",
        ],
      },
    },
  },
  controls: {
    language: "Language",
    theme: "Theme",
    themeSystem: "System",
    themeLight: "Light",
    themeDark: "Dark",
    expand: "Expand island",
    collapse: "Collapse",
    collapseToIsland: "Collapse to island",
    pin: "Pin",
    unpin: "Unpin",
    pinned: "Pinned",
    settings: "Settings",
  },
  media: {
    app: "Music",
    title: "İki Melek",
    artist: "Bengü",
    play: "Play",
    pause: "Pause",
    previous: "Previous track",
    next: "Next track",
    skipBack: "−10s",
    skipForward: "+10s",
  },
  clipboard: {
    empty: "Clipboard history is empty",
    hint: "Items you copy will show up here.",
    copied: "Copied",
    clear: "Clear all",
    samples: [
      "github.com/hams-i/Dyno",
      "Dyno Island landing copy",
      "pnpm dev — landing preview",
      "swift build && ./build.sh",
      "MIT License · open source",
      "Dynamic Island for macOS",
      "brew install --cask dyno",
      "Notch-native media controls",
      "Clipboard history · 12 items",
      "Timer with morphing display",
      "Counter + sticky notes",
      "Your notch, alive.",
    ],
  },
  timer: {
    reset: "Reset",
    start: "Start",
    stop: "Stop",
  },
  counter: {
    notePlaceholder: "Write a note…",
    decrease: "Decrease by one",
    increase: "Increase by one",
  },
  footer: {
    license: "MIT License",
    made: "Made for macOS",
  },
};

const tr: Messages = {
  brand: "Dyno Island",
  tagline: "Mac çentiği için Dynamic Island",
  nav: {
    features: "Özellikler",
    demo: "Demo",
    download: "İndir",
    github: "GitHub",
  },
  hero: {
    badge: "Açık kaynak · macOS",
    title: "Çentiğin",
    titleAccent: "canlı.",
    subtitle:
      "Şimdi Çalıyor, pano geçmişi, zamanlayıcı ve sayaç — kompakt ada ile geniş panel arasında yumuşak morph animasyonları.",
    cta: "Dyno Island'ı Al",
    ctaSecondary: "GitHub'da Gör",
  },
  islandTabs: {
    media: "Şimdi Çalıyor",
    clipboard: "Pano",
    timer: "Zamanlayıcı",
    counter: "Sayaç",
  },
  features: {
    eyebrow: "Adada",
    byTab: {
      media: {
        title: "Şimdi Çalıyor",
        desc: "Çentikte ne çaldığını gör — kapak, kontroller ve zaman çizelgesi bir bakış uzağında.",
        points: [
          "Kapak, kompakt ada ile geniş panel arasında morph olur",
          "Masaüstünden çıkmadan atla, oynat veya duraklat",
          "Şarkıyı sürükle veya −10s / +10s ile hızlı ilerle",
        ],
      },
      clipboard: {
        title: "Pano",
        desc: "Kopyaladığın her şey kaydırılabilir bir geçmişte durur; anında yeniden kullan.",
        points: [
          "Son kopyaları üç sütunluk ızgarada tara",
          "Herhangi bir karta dokunup tekrar kopyala",
          "Bitince geçmişi tek adımda temizle",
        ],
      },
      timer: {
        title: "Zamanlayıcı",
        desc: "Sadece hızlı bakış istediğinde adaya küçülen hassas kronometre.",
        points: [
          "Mac uygulamasıyla aynı saliseli doğruluk",
          "Geniş panelden başlat, duraklat ve sıfırla",
          "Yukarı ok ile sabitle — play/pause adada kalır",
        ],
      },
      counter: {
        title: "Sayaç",
        desc: "Tekrar, skor veya alışkanlıkları sayının yanındaki notla takip et.",
        points: [
          "Sayının yanında kısa bir not tut",
          "Başka uygulama açmadan artır, azalt veya sıfırla",
          "Adaya sabitleyip tek dokunuşla +1 yap",
        ],
      },
    },
  },
  controls: {
    language: "Dil",
    theme: "Tema",
    themeSystem: "Sistem",
    themeLight: "Açık",
    themeDark: "Koyu",
    expand: "Adayı genişlet",
    collapse: "Küçült",
    collapseToIsland: "Adaya küçült",
    pin: "Sabitle",
    unpin: "Sabitlemeyi kaldır",
    pinned: "Sabitlendi",
    settings: "Ayarlar",
  },
  media: {
    app: "Müzik",
    title: "İki Melek",
    artist: "Bengü",
    play: "Oynat",
    pause: "Duraklat",
    previous: "Önceki parça",
    next: "Sonraki parça",
    skipBack: "−10s",
    skipForward: "+10s",
  },
  clipboard: {
    empty: "Pano geçmişi boş",
    hint: "Kopyaladığın öğeler burada listelenir.",
    copied: "Kopyalandı",
    clear: "Tümünü temizle",
    samples: [
      "github.com/hams-i/Dyno",
      "Dyno Island tanıtım metni",
      "pnpm dev — landing önizleme",
      "swift build && ./build.sh",
      "MIT Lisansı · açık kaynak",
      "macOS için Dynamic Island",
      "brew install --cask dyno",
      "Çentiğe gömülü medya kontrolleri",
      "Pano geçmişi · 12 öğe",
      "Morphing zamanlayıcı ekranı",
      "Sayaç + yapışkan notlar",
      "Çentiğin, canlı.",
    ],
  },
  timer: {
    reset: "Sıfırla",
    start: "Başlat",
    stop: "Durdur",
  },
  counter: {
    notePlaceholder: "Not yaz…",
    decrease: "Bir azalt",
    increase: "Bir artır",
  },
  footer: {
    license: "MIT Lisansı",
    made: "macOS için üretildi",
  },
};

export const dictionaries: Record<Locale, Messages> = { en, tr };

export function getMessages(locale: Locale): Messages {
  return dictionaries[locale];
}
