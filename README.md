# zapret — iOS

Музыкальный плеер на SwiftUI для iOS 17+. Поддерживает поиск по Deezer, iTunes/Apple Music,
Archive.org и YouTube, воспроизведение через AVPlayer, избранное и офлайн-загрузки.

## Структура

```
zapret.xcodeproj/          Xcode-проект (iOS App target, scheme "zapret")
Sources/zapret/
  App.swift                @main, SwiftUI App
  Views/                   ContentView, SearchView, FavoritesView, DeviceView,
                           TrackRowView, MiniPlayerView, FullPlayerView
  ViewModels/              MusicViewModel (ObservableObject)
  Services/                AudioPlayer, DownloadManager, FavoritesStore
  Providers/               DeezerProvider, ItunesProvider, ArchiveOrgProvider, YouTubeProvider
  Models/                  Track, PlayerState, Source
  Extensions/              Color+Hex
  Resources/               Assets.xcassets (AppIcon, AccentColor)
Info.plist                 Ключи приложения (bundle id из build settings)
Package.swift              SPM-манифест (для разработки через SwiftPM)
tools/generate-xcodeproj.ps1  Генератор .xcodeproj (XcodeGen не нужен)
.github/workflows/         CI-сборка unsigned IPA
```

## Сборка IPA

### Вариант 1: GitHub Actions (проще всего)

При push в `main` workflow `.github/workflows/ios-build.yml` собирает `zapret-unsigned.ipa`
и кладёт его в артефакты запуска. Скачать: Actions → последний запуск → Artifacts → `zapret-ipa`.

Запуск вручную: Actions → iOS Build → Run workflow.

### Вариант 2: macOS + Xcode локально

```bash
xcodebuild -project zapret.xcodeproj -scheme zapret \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build

APP="build/DerivedData/Build/Products/Release-iphoneos/zapret.app"
rm -rf build/Payload && mkdir -p build/Payload
cp -R "$APP" build/Payload/
cd build && zip -qry zapret-unsigned.ipa Payload
```

### Вариант 3: другой билдер

`builder.json` уже указывает на корень проекта (`.`), схему `zapret` и bundle id
`com.example.zapret`. Xcode-проект и shared scheme в репозитории, поэтому сборщик
видит iOS-проект без дополнительных параметров.

Если нужно пересобрать `.xcodeproj` (после добавления файлов):

```powershell
powershell -ExecutionPolicy Bypass -File tools\generate-xcodeproj.ps1
```

## Установка на iPhone

IPA не подписана — это осознанно (сборка без Apple Developer аккаунта).
Подписывать и устанавливать нужно через AltStore / SideStore: они подписывают IPA
вашим Apple ID при установке. Бесплатный сертификат живёт 7 дней.

Чтобы собирать подписанную IPA, задайте в проекте `DEVELOPMENT_TEAM` и включите
`CODE_SIGNING_ALLOWED=YES` (или передайте флаги в `xcodebuild`).

## Ограничения

- YouTube открывается deeplink'ом в приложении — потоковое воспроизведение требует yt-dlp/NewPipe-совместимого кодека.
- Локальная музыка («Устройство») — заглушка: iOS не даёт прямого доступа к медиатеке без MPMediaLibrary.
- В сборке отключена подпись (`CODE_SIGNING_ALLOWED = NO`) — IPA unsigned.