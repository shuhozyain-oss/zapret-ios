# zapret — iOS

Порт музыкального плеера zapret на SwiftUI / Swift Package Manager для iOS.

## Статус

Текущий функционал:
- 🔍 Поиск: Deezer, iTunes/Apple Music, Archive.org, YouTube (deeplink)
- ▶️ Проигрывание: AVPlayer + AVAudioSession
- 💚 Избранное: UserDefaults
- ⬇️ Скачивание: Documents directory

## Сборка (требуется macOS + Xcode)

```bash
git clone <repo> zapret-ios
cd zapret-ios
# открыть Package.swift в Xcode
open Package.swift
```

Или через SPM CLI:
```bash
xcodebuild -scheme zapret -destination 'generic/platform=iOS Simulator' build
```

## Подпись и установка через SideStore / AltStore

1. Установить [SideStore](https://sidestore.io) или [AltStore](https://altstore.io) на iPhone.
2. Создать Apple ID (или использовать существующий).
3. В SideStore/AltStore включить «Custom IPA» / «Sideloading» и добавить собранный IPA.
4. Free provisioning — сертификат живёт 7 дней, подходит для бета.

Для бесплатного сертификата:
- SideStore поддерживает бесплатные Apple ID для sideloading.
- Нужен Mac для импорта в SideStore.

## Ограничения

- YouTube полнотекстовое воспроизведение требует yt-dlp / NewPipe на Android — на iOS нужно решение на AVPlayer + direct URLs.
- MediaStore → Core Media на iOS сложнее; Local Music вкладка — placeholder.