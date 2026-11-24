# zapret — iOS

Музыкальный плеер на SwiftUI для iOS 17+. Поиск и воспроизведение полных треков:
YouTube, SoundCloud, Archive.org. Плюс избранное, офлайн-загрузки и фоновое аудио.

## Структура

```
project.yml                  Спека XcodeGen (проект генерируется на CI)
Sources/zapret/
  App.swift                  @main, SwiftUI App
  Views/                     ContentView, SearchView, FavoritesView, DeviceView,
                             TrackRowView, MiniPlayerView, FullPlayerView
  ViewModels/                MusicViewModel (ObservableObject)
  Services/                  AudioPlayer, DownloadManager, FavoritesStore
  Providers/                 YouTubeProvider, SoundCloudProvider, ArchiveOrgProvider
  Models/                    Track, PlayerState, Source
  Extensions/                Color+Hex
  Resources/                 Assets.xcassets (AppIcon, AccentColor)
Info.plist                   Ключи приложения (bundle id из build settings)
Package.swift                SPM-манифест (для разработки через SwiftPM)
builder.json                 Конфиг сборщика (scheme, bundle id, профиль)
.github/workflows/           CI-сборка unsigned IPA (iOS Build, iOS Share)
```

## Как играет музыка

| Источник | Поиск | Воспроизведение |
|---|---|---|
| YouTube | Piped API (`/search`), fallback — Invidious | `Piped /streams/{id}` → прямой аудио-поток (mp4/aac), fallback — Invidious `adaptiveFormats` |
| SoundCloud | `api-v2.soundcloud.com/search` (client_id со страницы soundcloud.com) | `transcodings` → progressive mp3, иначе HLS |
| Archive.org | `advancedsearch.php` | `metadata/{id}` → файл из `files[]` |

Всё играет в приложении через AVPlayer — никаких перебросов в сторонние приложения.
Превью-треки (Deezer/iTunes отдают только 30 секунд) в поиске не участвуют.

## Сборка IPA

### Вариант 1: GitHub Actions (проще всего)

При push в `main` workflow `.github/workflows/ios-build.yml` собирает `zapret-unsigned.ipa`
и кладёт его в артефакты запуска. Скачать: Actions → последний запуск → Artifacts → `ipa`.

Запуск вручную: Actions → iOS Build → Run workflow.

### Вариант 2: CLI-сборщик

```powershell
$env:PATH = 'C:\Program Files\Git\bin;' + $env:PATH
builder ios build --unsigned
```

IPA появится в `dist/`.

### Вариант 3: macOS + Xcode локально

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project zapret.xcodeproj -scheme zapret \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

## Установка на iPhone

IPA не подписана — это осознанно (сборка без Apple Developer аккаунта).
Подписывать и устанавливать нужно через AltStore / SideStore / iLOADER: они подписывают IPA
вашим Apple ID при установке. Бесплатный сертификат живёт 7 дней.

Чтобы собирать подписанную IPA, задайте в проекте `DEVELOPMENT_TEAM` и включите
`CODE_SIGNING_ALLOWED=YES` (или передайте флаги в `xcodebuild`).

## Ограничения

- YouTube/SoundCloud зависят от публичных инстансов Piped/Invidious и client_id SoundCloud —
  если они недоступны, источник просто не вернёт результатов (приложение не падает).
- Локальная музыка («Устройство») — заглушка: iOS не даёт прямого доступа к медиатеке без MPMediaLibrary.
- В сборке отключена подпись (`CODE_SIGNING_ALLOWED = NO`) — IPA unsigned.