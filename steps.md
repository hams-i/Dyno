# Steps

## 2026-08-10 — ±10 timeline altına, README img, ekran kayması fix, 16:9 kapak

1. −10s / +10s tekrar zaman çizelgesinin altında (önceki yerleşim).
2. README ilgili bölümlerde `./source/readme-*.png` markdown görselleri.
3. İkinci ekrana kayınca kaybolma: kayma başında NotchSpace detach + MC
   poll skip + alpha=1; bitişte frame kilidi + orderFront (gecikmeli
   reattach kaldırıldı).
4. Ada kapağı hap eğrisine uyumlu (`UnevenRoundedRectangle`, inset 2.5).
   Geniş panelde 160×90 (16:9); adaya morph ile küçülür.

## 2026-08-10 — ±10 prev/next yanında, README görseller, sayaç animasyonu, ekran kaybı

1. Şimdi Çalıyor kontrolleri: `−10 | ◀ | ▶/❚❚ | ▶ | +10` — önceki/sonraki
   korundu, ±10 yanlarına taşındı (timeline altındaki kopyalar kaldırıldı).
2. README: `source/readme-*.png` (sıkıştırılmış) + markdown/HTML img yolları.
3. Timer TR adı: **Zamanlayıcı**.
4. Sayaç: `countsDown` ile + yukarı / − aşağı `numericText` animasyonu.
5. Çoklu ekranda NotchSpace ada kaybettiriyordu — multi-monitor’da detach,
   tek ekranda attach; kayma bitince kare + alpha yeniden kilitleniyor.

## 2026-08-10 — Medya kontrolleri, l10n, tema, source görseller, ekran kayması

1. Next/prev: MediaRemote send’e ek olarak sistem medya tuşları
   (NX_KEYTYPE_NEXT/PREVIOUS) — YouTube/Chrome için gerekli.
2. ±10 flicker: seek sonrası hemen `get` çekilmiyordu; stream eski elapsed
   yazıyordu. 0.9s seek kilidi + refreshOnce kaldırıldı.
3. YouTube thumbnail: tarayıcı bundle’larında agresif artwork yenileme.
4. Ayarlar ~560pt yüksek; Bilgi scroll’suz sığar. Tema: Sistem/Açık/Koyu
   (yalnızca ayarlar penceresi).
5. Tablar ve UI metinleri `L10n` ile TR/EN; dil değişince güncellenir.
6. Ekran görüntüleri `source/`; README yolları güncellendi.
7. Ekran kayması sonrası kaybolma: `.stationary` kaldırıldı, kayma bitince
   alpha=1 + NotchSpace detach/reattach.

## 2026-08-10 — Bilgi ayarı, tek ekran kaydırma, medya kontrolleri, README

1. Ayarlar “Genel” → **Bilgi / About**: sunum tarzı özellik ızgarası, sürüm,
   açık kaynak kartı ve [github.com/hams-i/Dyno](https://github.com/hams-i/Dyno)
   bağlantısı. Sistem açılışı altındaki ⌃⌥D metni kaldırıldı; global
   `HotKeyController` artık başlatılmıyor.
2. Ada artık **tek ekranda**: ayna paneller kaldırıldı. Tıklanan ekran
   `activeScreenID` olur; üst kenardan sola/sağa `easeInOutCubic` kayarak
   o ekranın çentiğine gider.
3. Şimdi Çalıyor’da ±10 / ileri-geri / timeline: morph katmanı medya/pano
   sayfalarında hit-test’i kapatıyordu (tıklamaları yutuyordu). Medya’da
   pass-through; yalnızca Timer/Sayaç buton ankhorları hit alır.
4. README üstte İngilizce, altta Türkçe; kök dizindeki ekran görüntüleri
   eklendi. `git init` yapılmadı.

## 2026-08-10 — Docked Timer/Sayaç play ve +1 butonları

1. Ada durumundaki play/pause ve +1 tıklanınca aksiyon aslında
   AppKit `handleCompactControlClick` üzerinden çalışıyordu; ancak
   `IslandMorphLayer` yalnızca `AppModel`'i izliyordu. Nested
   `TimerService` / `CounterService` `@Published` değişimleri görünümü
   yenilemediği için ikon ve sayı yerinde kalıyor, buton "çalışmıyor"
   gibi görünüyordu. Aşağı ok `isExpanded` / `isActivityDocked`
   yayınladığı için çalışır görünüyordu.
2. Morph katmanı artık `timer` ve `counter`'ı `@ObservedObject` ile
   doğrudan izliyor; süre metni de adadayken canlı güncellenir.
3. Ada durumunda morph butonlarının hit-test'i açıldı (yedek yol) ve
   AppKit tıklama bölgeleri chevron (≤28) ile play/+ (≤64) olacak
   şekilde ayrıldı — play'in sağ kenarı yanlışlıkla aşağı oka düşmesin.

## 2026-08-10 — Çentiğe sığan ada, sekme göz kırpması, sayfayla kayan morph

1. **Timer'ın son hanesi çentiğin altında kalıyordu.** Ada = çentik + iki
   kanat; kanat genişliği sabit 56pt idi (`collapsedWidthExtra` 112'nin
   yarısı) ama 12pt süre metni ~58pt. Artık genişlik tahminle değil ölçümle
   belirleniyor: soldaki morph öğesi ada boyutundayken kendini ölçüp
   `AppModel.reportIslandLeadingHalfWidth` ile gereken kanat genişliğini
   bildiriyor, `islandSideExtra` de en az 112 olacak şekilde büyüyor. Süre
   bir saati aşıp `s:dd:dd.dd` biçimine geçince ada aynı yumuşak pencere
   animasyonuyla genişliyor. Sabit katsayılı `islandContentExtraWidth` ve
   ona bağlı elapsed/count gözlemcileri silindi.
2. **Sekme göz kırpması** `ExpandedIslandView`'in `progress > 0.02` ile
   sökülmesinden geliyordu: her açılışta `tabFrames` @State'i sıfırlanıyor,
   gösterge ölçüm gelene kadar bir iki kare kayboluyordu. Geniş yerleşim
   artık hiç sökülmüyor, yalnızca opaklıkla açılıyor. Kapalıyken kaydırma
   olaylarını yutmaması için gesture yakalayıcı `morphProgress > 0.9`
   koşuluna bağlandı.
3. **Morph öğeleri artık kendi sayfalarıyla kayıyor.** Sayfa kayması tek bir
   yayınlanmış değerden (`AppModel.pageScroll`) sürülüyor; hem sayfa yığını
   hem morph öğeleri aynı değeri okuduğu için iki parmak kaydırmada kapak /
   süre / sayaç sayfasıyla birebir hareket ediyor, sabit kalmıyor. Üç sekmenin
   öğeleri de sahnede duruyor ve `IslandMorphLayer` maskesi ada durumunda tüm
   panel, açıkken sayfa alanı olacak şekilde interpolasyonla kırpıyor.

## 2026-08-10 — Native açılış: sabit yerleşim + maskeli açılma

1. "Flip" hissinin asıl kaynağı: geniş içerik ara karelerde 600'den küçük
   genişliklere göre yeniden yerleşiyordu, yani butonlar/tablar animasyon
   boyunca eziliyordu. Artık geniş yerleşim **her zaman kendi tam boyutunda**
   (600x268) kuruluyor, üstten ortalanıyor ve büyüyen pencere tarafından
   maskelenerek açılıyor. Yeniden yerleşme yok; üstüne hafif bir
   0.94 → 1 ölçek (üst noktadan) ve erken biten opaklık rampası.
2. Pencere eğrisi `easeOutQuint`'ten kritik sönümlü yaya çevrildi. Quint
   aşırı ön yüklemeliydi (mesafenin yarısı sürenin ilk %13'ünde), bu yüzden
   ilerlemeye bağlı her geçiş "şak" diye oluyordu. Süreler 0.50s / 0.42s.
3. Kapak artık kare: geniş yerleşimdeki 96x96 kapak, adadaki 28x28 kapağın
   birebir büyümüş hali. En-boy değişmediği için kırpma kaymıyor, büyüme
   saf ve doğal.
4. Timer başlat/durdur butonu ada ve panelde aynı stilde (beyaz zemin,
   siyah ikon) — büyürken renk harmanlanmıyor.

## 2026-08-10 — Tek örnekli gerçek morph (kopya/devir tamamen kalktı)

1. Sahte uçuş + devir mimarisi kaldırıldı. Artık her paylaşılan öğe
   hiyerarşide **tek** örnek: geniş yerleşimde yerini şeffaf bir yuva
   (`morphSlot`) tutuyor, öğenin kendisi `IslandMorphLayer` içinde çizilip
   ada konumundan yuvanın konumuna büyüyor. Kopya yok, devir yok.
2. Öğeler ölçekle değil kendi boyutlarıyla büyüyor: kapak genişlik ve
   yüksekliği ayrı ayrı interpolasyonla 28x28 (1:1) → 180x101 (16:9) olarak
   geçiyor, köşe yarıçapı da 7 → 12. Metinler punto interpolasyonuyla
   (12 → 42 / 13 → 40) yeniden çiziliyor, bulanık ölçekleme yok.
   Butonlar çap + ikon puntosu + renk harmanıyla 22 → 56'ya gidiyor.
3. `ArtworkLayerView` artık kırpmayı katmana (`resizeAspectFill`) bırakıyor
   ve bitmap'i kaynağın kendi oranında, 64'e yuvarlanmış çözünürlükte
   üretiyor. Böylece 1:1 → 16:9 büyürken her karede rasterleştirme ve
   şekil bozulması olmuyor.
4. İçerik görünürlüğü zamanlayıcıyla değil `morphProgress` ile sürülüyor;
   `showsCompactContent` ve gecikmeli devir işleri silindi. Ada köşe
   yarıçapı da ilerlemeyle yumuşak geçiyor.
5. Tab göstergesi göz kırpması: kapsül artık hiç sahneden çıkmıyor (ölçüm
   eksikken `nil` dönüp kayboluyordu) ve `interactive()` cam efekti
   kaldırıldı — imleçle nabız gibi parlıyordu.

## 2026-08-10 — Devir anındaki göz kırpması + daha derli toplu ada

1. Göz kırpmasının sebebi çapraz solmaydı: ada katmanı 1→0, geniş içerik
   0→1 giderken ortada toplam opaklık düşüyor ve kısa bir karartı oluşuyordu.
   Artık katmanlar üst üste biniyor: `AppModel.showsCompactContent` ile ada
   katmanı altta tam opak kalıyor, geniş içerik üstünde 0.16s belirdikten
   0.2s sonra ada katmanı kaldırılıyor. Küçülürken geniş içerik animasyonsuz
   kalkıyor (alttaki ada katmanı zaten aynı yerde) — böylece daralan
   pencerede ezilmiş içerik de görünmüyor.
2. Ada bir tık kısaldı: `collapsedWidthExtra` 148 → 112, notch'suz ekran
   yedeği 330 → 294. Sol bilgi ile sağ aksiyon butonları arasındaki fazla
   boşluk kapandı.
3. Ada artık içeriğe göre esniyor: `AppModel.islandContentExtraWidth`
   süre bir saati aştığında +24pt, sayaç dört haneye çıktığında hane başına
   +8.5pt veriyor. Değişim `reposition(animated: true)` ile aynı yumuşak
   pencere animasyonundan geçiyor.

## 2026-08-10 — Ölçüme dayalı gerçek morph (öğeler hedeflerine uçuyor)

1. `MorphAnchor` / `morphSource(_:)` / `MorphFlight` altyapısı
   (`IslandRootView.swift`). Geniş paneldeki kapak, oynat butonu, Timer saati
   ve butonu, Sayaç değeri ve + butonu kendi karelerini panel koordinat
   uzayında (`MorphSpace`) bildiriyor; ada öğeleri tam o karelere uçuyor.
   Hedefler `AppModel.morphAnchors` içinde bilinçli olarak yayınlanmadan
   tutuluyor, böylece ölçüm her karede yeniden çizim tetiklemiyor.
   Yalnızca ekrandaki sekme kayıt yapıyor (`\.morphRecording`).
2. `AppModel.morphProgress` (0 = ada, 1 = panel) panel controller tarafından
   `setFrame` ile **aynı karede** güncelleniyor; artık GeometryReader
   gecikmesi yok. Ölçek hedef/dinlenme boyut oranından, kayma da öğenin o
   anki doğal merkezinden türüyor — pencere daralırken kenar öğeleri
   kenarla birlikte kaydığı için sapma oluşmuyor.
3. Pencere animasyonu `CADisplayLink` ile ekran yenileme hızına kilitlendi
   (ProMotion'da 120 Hz), eğri `easeOutQuint`, süreler 0.46s açılma /
   0.38s kapanma. Geniş içeriğe devir 0.21s'ye alındı: o anda pencere
   ~%97 boyutta, öğeler hedeflerinin üstünde, çapraz geçiş görünmüyor.
4. Ses dalgası geniş panelde birebir karşılığı olmadığı için oynat/duraklat
   butonuna doğru uçarken yumuşakça sönüyor (`fadesOut`).

## 2026-08-10 — Geometriye bağlı küçülme morph'u + titremesiz kapak

1. Swipe toleransı düşürüldü: eşik sayfa genişliğinin %22'sinden %10'una
   (min 40pt → 22pt), gesture yakalama da 1.6x/1.5pt yerine 1.1x/0.6pt.
2. Kapak titremesi giderildi: `MediaTabView`'daki gereksiz `.id(artwork)`
   kaldırıldı (her poll'da NSView'i yeniden kuruyordu) ve
   `ArtworkLayerView` artık aynı görsel + aynı piksel boyutu için yeniden
   rasterleştirmiyor (`RenderKey` önbelleği). CALayer örtük animasyonları
   `CATransaction.setDisableActions` + `actions = NSNull()` ile kapatıldı.
3. Küçülme morph'u artık spring yerine pencerenin canlı yüksekliğinden
   türüyor: `AppModel.collapsedPanelHeight` panel controller'dan besleniyor,
   `CompactIslandView` içindeki `shrinkProgress` 1→0 giderken kapak/dalga,
   Timer saati+butonu, Sayaç değeri+butonu merkezden büyük başlayıp
   küçülerek ada konumlarına uçuyor. Pencere animasyonuyla birebir senkron,
   taşma/kırpılma yok. `dockSettle` kaldırıldı; içerik geçişi 0.16s fade.

## 2026-08-10 — Orantılı tab göstergesi + adaya iniş morph + dist çıktısı

1. `build.sh`: Release derler, `dist/DynoIsland.app` üretir — bundan sonra
   her derleme bu yolla dist'e kopyalanacak.
2. Tab göstergesi artık sayfayla orantılı kayıyor: sekme çerçeveleri
   `PreferenceKey` ile ölçülüyor, kapsül sürükleme miktarına göre iki sekme
   arasında interpolasyonla konumlanıyor (macOS 26'da Liquid Glass kapsül).
3. Swipe sırasında kapağın garip hareketi giderildi: sekme sayfalarındaki
   `matchedGeometryEffect` morph'u kaldırıldı — öğeler artık sabit.
4. Adaya iniş animasyonu: `AppModel.dockSettle` 0→1 yayı; kapak/ses dalgası,
   Timer saati+butonu, Sayaç değeri+butonu merkezden büyük başlayıp
   küçülerek ada konumlarına kayıyor. Genişlerken panel içeriği hafif
   scale+fade ile açılıyor. Açılış reveal'i ile aynı koreografi (`settle`).

## 2026-08-10 — Liquid Glass tab + parmakla birebir swipe + morph

1. Tab bar macOS 26 Liquid Glass: `GlassEffectContainer` + aktif kapsülde
   `glassEffect(.regular.tint.interactive, in: .capsule)` ve `glassEffectID`
   ile native morph. macOS 26 altında eski `matchedGeometryEffect` kapsülü.
2. Swipe artık kesikli değil: `NSEvent.scrollWheel` phase takibiyle sayfa
   parmakla birebir kayıyor (`dragTranslation`), kenarlarda %30 direnç,
   bırakınca %22 eşikle en yakın sayfaya yaylanarak oturuyor. Dikey kaydırma
   (Pano) etkilenmiyor; momentum kuyruğu yutuluyor.
3. Adaya küçülürken öğeler uçuyor: `IslandRootView` içinde `@Namespace morph`,
   kapak / timer sayacı / timer play-pause / sayaç değeri / sayaç + butonu
   `matchedGeometryEffect` ile geniş panelden ada konumuna animasyonlu geçiyor.

## 2026-08-10 — Açılış 1 tık hızlı + kayan tab sayfaları

1. Launch reveal 1,75s → 1,52s, gecikme 0,22s → 0,18s.
2. Tab bar sabit; aktif kapsül `matchedGeometryEffect` ile kayar. Sayfalar yan
   yana HStack + offset ile kayar. Trackpad iki parmak yatay swipe tab değiştirir
   (dikey Pano kaydırması bozulmaz).

## 2026-08-10 — Space sabitleme geri geldi (CGS + kilit)

1. `NotchSpace` artık Set didSet yerine her seferinde güncel `windowNumber`
   ile `CGSAddWindowsToSpaces` çağırıyor (orderFront sonrası numara değişince
   pencere space'ten düşüyordu). windowNumber 0 ise birkaç kare retry var.
2. 60 Hz `enforceNotchAnchor` tekrar `orderFrontRegardless` + space'e yeniden
   bağlama yapıyor; Space kaydırmasında ada çentikte kalıyor.

## 2026-08-10 — Yavaş merkezden açılış + video yok

1. Açılış animasyonu yavaş ve düz: 0,22 sn merkez pozu, sonra 1,75 sn
   `easeInOutCubic` (aşma yok). Ada çentik genişliğinden başlar, width yavaş
   büyür. Kapak ve ses dalgası çentik merkezinde üst üste başlar; kapak sola,
   dalga sağa kayarak loblara oturur.
2. Şimdi Çalıyor video/yukarı ok özelliği yok — canlı yakalama daha önce
   kaldırılmıştı; medya sekmesinde yukarı ok yok (ok yalnızca Timer/Sayaç dock).

## 2026-08-10 — Özel CGS space + açılış reveal animasyonu

1. Space geçişi: boring.notch'taki yaklaşım port edildi (`Window/NotchSpace.swift`).
   `CGSSpaceCreate` ile mutlak seviyesi en yüksek özel bir space açılıp ana panel
   ve ayna paneller `CGSAddWindowsToSpaces` ile bu space'e taşınıyor; pencereler
   Space geçişlerine hiç katılmadığı için ada çentikte gerçekten sabit kalıyor.
   Uygulama kapanırken space `tearDown()` ile yok ediliyor.
2. Açılış animasyonu: `AppModel.launchReveal` 0→1, `easeOutBack` ile 0,9 sn.
   Ada çentik genişliğinde başlıyor, loblar iki yana simetrik açılıyor (185 →
   340 aşma → 333 px, merkez sabit). Kapak sola, ses dalgası sağa kayarak
   çentiğin arkasından çıkıyor; içerik fade + hafif scale ile geliyor.

## 2026-08-10 — Canlı video kaldırıldı + ada çentiğe kilitlendi

1. Şimdi Çalıyor'daki yukarı ok ve canlı ekran yakalama özelliği tamamen
   kaldırıldı: `MediaPreviewService` silindi, `isMediaCinema` durumu,
   cinema layout'u, AppKit cinema tıklama yolu, Ayarlar'daki İzinler bölümü ve
   `NSScreenCaptureUsageDescription` temizlendi.
2. Space geçişi: macOS paneli eski masaüstüyle birlikte kaydırabildiği için
   60 Hz döngüde `enforceNotchAnchor()` eklendi — Mission Control aktif değilken
   panel her karede çentik altındaki hedef kareye, alfa 1'e geri kilitleniyor ve
   aktif Space'te değilse öne alınıyor.

## 2026-08-10 — Gerçek MC sinyali + ekran yakala-kırp video

1. Spaces: `stationary` geri eklendi; 3 parmak sağ/sol geçişte ada çentikte sabit
   kalıyor, önceki Space ile birlikte kaymıyor.
2. Mission Control: Dock'un geçiş sırasında çizdiği adsız masaüstü katmanı
   penceresinin ölçeği ölçülerek 0…1 ilerleme çıkarılıyor; ada parmakla birebir
   yukarı/aşağı kayıyor. Tam açık durum için Dock'un tam ekran overlay'leri
   sayılıyor, devir teslim anındaki tek karelik sıçramalar debounce ediliyor.
3. Video: `including:[app]` ve `desktopIndependentWindow` filtreleri YouTube'un
   donanım hızlandırmalı katmanını siyah bıraktığı için tüm ekran yakalanıp
   kare kendi hattımızda hedef pencereye kırpılıyor; pencere taşınırsa kırpma
   0,5 sn'de bir güncelleniyor.

## 2026-08-10 — Spaces sabit + YouTube app-target + MC senkron

1. Spaces: `canJoinAllSpaces` (stationary kaldırıldı); ada çentikte kalır.
2. Video: display+including medya app, kardeş pencereler hariç; sourceRect yok.
3. Mission Control: progress 0…1 ile ada orantılı yukarı/aşağı kayar (60fps poll).

## 2026-08-10 — YouTube app-only capture + Mission Control gizle

1. Video: yalnızca medya app (including) + YouTube başlıklı pencere crop; masaüstü değil.
2. Spaces kaydırma: ada sabit (`canJoinAllSpaces`); Mission Control’te yukarı kayıp gizlenir.

## 2026-08-10 — Video display-crop + her ekranda üstte ada

1. YouTube siyah kare: pencere yerine display+sourceRect (HW video katmanı).
2. Panel seviyesi popUpMenu+25; daraltılmışken tüm ekranlarda ayna ada.

## 2026-08-10 — Video stream race fix

1. Standard MediaTabView onDisappear stream’i öldürüyordu → kaldırıldı.
2. Renderer hazır olmadan yakalama başlamıyor; CGImage→CALayer yolu.
3. Pencere filter’ı öncelikli; os_log ile tanı.

## 2026-08-10 — Cinema: yalnız aşağı ok + gerçek video

1. Video modunda DI sağında yalnızca aşağı ok; tıklama AppKit hit-zone.
2. Canlı video: SCStream → AVSampleBufferDisplayLayer; app-on-display filter.

## 2026-08-10 — Pin / video ayrımı + HQ canlı önizleme

1. Pin yalnızca paneli sabitler; video açmaz.
2. Şimdi Çalıyor yukarı ok → 16:9 cinema; aşağı ok ile çıkış (menü şeridi altında, tıklanır).
3. Canlı yakalama: IOSurface → CALayer, 1080p @ ~30 fps, CI dönüşümü yok.

## 2026-08-10 — Kısayol + menü dil + header sırası + pin 16:9

1. Sistem kısayolu ⌃⌥D (`HotKeyController`) — ada aç/kapa; Ayarlar → Tercihler’de not.
2. Menü çubuğu: TR/EN (`Sabitle`, `Çıkış Yap`, `Ayarlar…`, `Ada’yı Aç/Kapat`).
3. Timer/Sayaç header: yukarı ok → pin → ayarlar; ok diğer ikonlarla aynı stil.
4. Pin’li Şimdi Çalıyor: DI sağında pin; altında 16:9 canlı video (320 × strip+180).

## 2026-08-10 — Medya seek + sabit kapak + cinema boy

1. Play/pause kapak flicker: artwork cache + preserveArtwork.
2. Timeline Slider + −10s/+10s seek (MediaRemote seek).
3. Menü Pin/Ayarlar SF Symbol ikonları.
4. Pin cinema: yalnızca pin; 380×(~menu+132) ara boyut.
5. SharpArtworkView pixel-perfect HQ rasterize.

## 2026-08-10 — App icon + pin cinema medya

1. Tam AppIcon.icns Resources’a; paket sonrası zorla kopyalanır (Sistem Ayarları simgesi).
2. Şimdi Çalıyor: standart = kaliteli statik thumbnail (canlı yok).
3. Pin: tabs gizlenir, yalnızca canlı video; yukarı ok kaldırıldı.

## 2026-08-10 — Ayarlar penceresi + medya chrome compact

1. Pin sağında ayarlar (gear) → native Settings penceresi.
2. Sol nav: Genel / İzinler / Tercihler (dil, login item, ekran kaydı).
3. Şimdi Çalıyor yukarı ok → meta+timeline yüksekliği; ekran izni ister.
4. Tercihler `preferences.json` + SMAppService launch-at-login.

## 2026-08-10 — Yüksek kalite video/kapak thumbnail

1. ImageIO full-res decode + en büyük frame; daha keskin kapak tercih.
2. SharpArtworkView: CALayer trilinear, retina contentsScale.
3. MediaPreview canlı yakalama 720p + HQ downsample; medya sekmesinde öncelikli.
4. Kapak yok/düşükse 3 denemeli artwork refresh.

## 2026-08-10 — Sayaç not + tıklama split

1. Expanded Sayaç: sol not (TextEditor), sağ tıklama; "Tıklama" kaldırıldı.
2. Not `activities.json` içinde kalıcı (`counterNote`).
3. Compact ada: solda adet, sağda + (değişmedi).

## 2026-08-10 — Timer eski + Sayaç yönlü numericText

1. Timer animasyonları geri alındı (önceki sakin hali).
2. Sayaç: artır ↑ (`countsDown: false`), azalt/sıfırla ↓ (`countsDown: true`).

## 2026-08-10 — Numeric spring efekti Timer + decrement

1. Sayaç − / sıfırla: aynı spring + numericText.
2. Timer play/pause/sıfırla + canlı süre: aynı numericText spring.
3. Compact ada / AppKit tıklama da aynı animasyon.

## 2026-08-10 — Expanded Sayaç orantı

1. Büyük ekran Sayaç: Timer benzeri merkez layout; + 56pt Space Black.
2. − / sıfırla yan kontroller; dev panel buton kaldırıldı.

## 2026-08-10 — Yerel DB + DI layout geri + Pano height

1. Application Support `activities.json` — sayaç/timer kalıcı (kod değişse de).
2. Compact DI: sol değer + sağ Space Black buton (ortalamayı geri aldım).
3. Pano: kart 88; 4 satır sabit yükseklik; stats altta.
4. Expanded Sayaç + paneli Space Black.

## 2026-08-10 — Compact polish + Pano stats

1. Collapsed height −1px daha (min 33).
2. Timer/Sayaç (dock değil): buton sağa yaslı (trailing pad 4).
3. Artwork: tüm köşelerde eşit radius.
4. Sayaç/Timer buton: Space Black, 22pt; sayı ortalı.
5. Pano kart: max 4 satır + kelime/harf.

## 2026-08-10 — Astroid ikon + kapak radius + height -2

1. Compact artwork: yalnızca bottomLeading radius.
2. App/menu ikonu: Lucide astroid, ince beyaz (premium).
3. Collapsed height ≈ notchHeight - 2 (min 34).

## 2026-08-10 — Pano sayısı + büyük thumbnail

1. Pano header sağ üstte kopya adedi.
2. Collapsed medya sol artwork 28pt; sol padding azaltıldı.

## 2026-08-10 — Compact click routing (çentik)

1. Timer/Sayaç/aşağı-ok tıklamaları SwiftUI yerine AppKit global/local mouse ile
   sağ lob X bölgelerinden çözülüyor (menü çubuğu hit-test kaçışını aşar).

## 2026-08-10 — Dock vs hover + tıklama / equalizer

1. Timer/Sayaç butonları: senkron key window + tap gesture (çalışır).
2. Yukarı ok → dock: aşağı ok görünür, hover kapalı.
3. Doğal hover-küçülme: aşağı ok yok, hover açık; Timer/Sayaç kompakt kalır.
4. Ses dalgaları durunca ease-out ile noktalara küçülür.

## 2026-08-10 — Compact DI UX (Sayaç tık, equalizer, timer, radius)

1. Collapsed width +148; Sayaç + dairesel buton sağ lobda, tıklanabilir.
2. Voice charts: organik animasyon; durunca noktalara spring ile iner.
3. Timer: solda süre, sağda play/pause; akıcı spring.
4. Collapsed topLeading/topTrailing radius = 0.

## 2026-08-10 — Compact DI thumbnail + voice charts

1. Compact ada referans hap boyutu (~çentik+120 × 36); capsule köşe.
2. Medya kompakt: solda artwork thumbnail, sağda animasyonlu equalizer (voice charts).

## 2026-08-10 — Ada genişliği (kamera lobları)

1. Collapsed width = çentik + 100 pt; içerik kamera deliğinin sol/sağında görünür.
2. Docked Sayaç: solda sayı, sağda + / aşağı ok; Timer aynı sol–sağ düzen.

## 2026-08-10 — Timer/Sayaç dock + sayaç kalıcılığı

1. Timer/Sayaç aktifken otomatik küçülme → ilgili tab adada kalır (`dockActivityToIsland`).
2. Timer’daki sağdaki stop (Bitir) butonu kaldırıldı; Başlat/Durdur + Sıfırla kaldı.
3. Sayaç `UserDefaults` ile kalıcı.

## 2026-08-10 — Timer + Sayaç sekmeleri

1. Timer (başlat/durdur/sıfırla) ve Sayaç (+1 tık alanı, küçük -1) sekmeleri eklendi.
2. Timer/Sayaç sağ üstte yukarı ok → ada boyutuna iner; hover açmaz; sağda aşağı ok ile genişler.
3. Docked Sayaç: solda sayı, sağda +1 tık; docked Timer: süre + play/pause.

## 2026-08-07 — Hover yalnızca çentik

1. Collapsed hit rect artık tam çentik boyutu; alt/sağ/sol pad kaldırıldı.

## 2026-08-07 — Hover analizi + medya/pano layout

1. Hover bazen gelmeme: animasyon sırasında poll iptali, kısa dwell, kamera deliğinde mouse yokluğu.
2. Animasyon sırasında pending hover; çentik ALTINA 44pt hit bandı; dwell 0,08 sn.
3. Medya: kapak %30 / 16:9, sağda başlık+kanal+kontroller, altta full-width timeline.
4. Pano: `minWidth: 0` + clip — yatay büyük görseller taşmıyor.

## 2026-08-07 — Hover, status item, UI ve paketleme

1. Global hover: daha yüksek pencere seviyesi, geniş çentik hit bandı, 30 fps poll, Space/Space değişiminde `orderFront`.
2. Menü çubuğu status item + sağ tık menüsünde Quit.
3. Medya %50/%50 keskin kapak; pano toolbar kaldırıldı, kartlarda yalnızca içerik; silme header’da, pin en sağda.
4. `Scripts/package-app.sh` Release `.app` üretir (`dist/` + Masaüstü).

## 2026-08-05 — Çift katman UI + görsel yenileme

1. İç içe kart (ada + medya kartı) kaldırıldı; tek siyah yüzey.
2. if/else içerik — aynı anda iki ekran/opacity katmanı yok; clipShape ile taşma kesildi.
3. Hosting doğrudan contentView; medya/pano düz layout, sekme etiketli header.
4. Genişleme 600×268.

## 2026-08-05 — Hover constraint crash fix

1. `animator().setFrame` + SwiftUI spring/scale, NSHostingView’da “Update Constraints in Window” döngüsü yaratıyordu.
2. Hosting view artık düz NSView içinde; `invalidateIntrinsicContentSize` no-op; kare animasyonu Timer + `setFrame`.
3. `withAnimation`/scale transition kaldırıldı; CompactIslandView’dan GeometryReader çıkarıldı.
4. Geniş içerik (`showsExpandedContent`) pencere büyüdükten sonra açılıyor — küçük karede ağır layout yok.
5. 24 geçişlik stress test: `DYNO_WINDOW_STRESS_TEST_PASSED`, yeni crash yok.

## 2026-08-05 — Daha kısa genişleme, yalnızca kapak, pano kaydırma, animasyon

1. Genişlemiş yükseklik 452 → 286; canlı ScreenCapture önizlemesi kaldırıldı, yalnızca kapak görseli.
2. Ayarlar (dişli) düğmesi ve ekran kaydı menü öğesi kaldırıldı; MediaPreviewService AppModel’den çıkarıldı.
3. Pano `ScrollView` artık maxHeight ile sınırlanıyor; hit-test alt görünümlere öncelik veriyor.
4. Hover genişlemesi spring timing (panel + SwiftUI) ile yumuşatıldı.

## 2026-08-05 — Ada boyutu, kısayollar ve izin döngüsü

1. Daraltılmış Dyno artık gerçek çentik ölçüsünde (ör. 185×32); `collapsedDrop` kaldırıldı, köşe yarıçapı 10 pt.
2. Genişleme yalnızca aşağı; üst kenar `screen.frame.maxY`’de kalıyor. Menü çubuğu yüksekliği kadar üst boşluk bırakılıyor ki Şimdi Çalıyor / Pano / Sabitle / Ayarlar tıklanabilsin.
3. Panel tıklanınca `makeKey` + app activate; `acceptsFirstMouse` eklendi.
4. `CGRequestScreenCaptureAccess` otomatik çağrılmıyor — yalnızca kullanıcı düğmesine basınca bir kez; aksi halde tekrar tekrar izin soruyordu.
5. Debug derlemesi alınıp uygulama yeniden başlatıldı.

## 2026-08-05 — Hover’ın notch/menü çubuğunda çalışmaması

1. Menü çubuğu `mouseEntered` vermediği için `NSEvent.mouseLocation` poll + global/local monitor eklendi.
2. Kenar titremesi expand timer’ını iptal ettiği için hover histerezisi eklendi.
3. Daraltılmış ada notch altına ~16 pt sarkıyor; şeffaf köşeler için solid hit-test eklendi.
4. Tıklayınca anında genişleme; hover gecikmesi 0,18 sn.
5. Çift DynoIsland süreçleri kapatılıp tek build yeniden başlatıldı.

## 2026-08-05 — MediaRemote “Operation not permitted” düzeltmesi

1. macOS 15.4+ doğrudan MediaRemote erişimini engellediği için
   `ungive/mediaremote-adapter` vendor edildi (`Vendor/MediaRemoteAdapter`).
2. `NowPlayingService` Perl adapter `stream`/`get`/`send` komutlarına taşındı;
   uygulama artık MediaRemote’u kendi sürecinde `dlopen` etmiyor.
3. Xcode’a `Copy MediaRemote Adapter` run script fazı eklendi.
4. README ve bootstrap script güncellendi; uygulama yeniden derlenip açıldı.

## 2026-08-05 — Konum, hover içerik ve küçülme düzeltmeleri

1. Ada penceresi notch bandının üst kenarına yaslandı (`screen.frame.maxY`); `constrainFrameRect` override ile macOS’un menü çubuğu altına itmesi engellendi.
2. SwiftUI `onHover` kaldırıldı; borderless panel için AppKit `NSTrackingArea` hover takibi eklendi.
3. Pencere frame animasyonu sırasında sahte mouse exit/enter yok sayılıyor; animasyon bitince konum yeniden senkronlanıyor.
4. Genişleyince `ExpandedIslandView` içeriğinin görünmesi için root view `@ObservedObject` + `ignoresSafeArea` ile toparlandı.
5. Fare ayrılınca küçülme gecikmesi 0,08 sn’ye indirildi.
6. Debug derlemesi alınıp uygulama yeniden başlatıldı.
