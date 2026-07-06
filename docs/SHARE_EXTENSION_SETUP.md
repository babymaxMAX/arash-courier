# Настройка «Поделиться в Arash» (iOS Share Extension)

Флаттер-часть уже готова и запушена: пакет `receive_sharing_intent` подключён,
`HomeScreen` слушает шаринг (и при холодном, и при горячем старте) и — только
для роли менеджер/админ — открывает «Новый заказ» с прикреплённым фото/видео
(`lib/screens/home_screen.dart`: `_initSharingIntent`/`_handleSharedMedia`).

Чтобы значок **Arash** появился в системном меню «Поделиться» на iOS (как у
Garuda на скриншоте), остался только нативный шаг — его можно сделать
**только в Xcode на Mac**. Это разовая настройка, дальше просто собираешь
приложение как обычно.

Bundle ID приложения: `com.arashexpress.courier`.

## Шаги в Xcode

1. Открой `ios/Runner.xcworkspace` в Xcode (не `.xcodeproj`).
2. **File → New → Target…** → выбери **Share Extension** → Next.
   - Product Name: `ShareExtension`
   - Language: Swift
   - Project: Runner, Embed in Application: Runner
   - **Finish**, на вопрос про "Activate scheme" — Cancel (не обязательно).
3. Убедись, что **Deployment Target** у нового таргета `ShareExtension`
   совпадает с таргетом `Runner` (обычно достаточно поставить то же значение
   вручную в Build Settings → Deployment → iOS Deployment Target).

### App Group (для обмена данными между расширением и приложением)

4. Выбери таргет **Runner** → вкладка **Signing & Capabilities** → **+
   Capability** → **App Groups** → **+** → добавь группу:
   ```
   group.com.arashexpress.courier
   ```
5. То же самое для таргета **ShareExtension**: Signing & Capabilities → +
   Capability → App Groups → отметь **ту же самую** группу
   `group.com.arashexpress.courier`.
6. Для обоих таргетов (`Runner` и `ShareExtension`) в **Build Settings** найди
   User-Defined Settings (или добавь новую) `CUSTOM_GROUP_ID` со значением
   `group.com.arashexpress.courier`.

### ShareViewController

7. Открой файл `ShareExtension/ShareViewController.swift`, который создал
   Xcode, и замени его содержимое на:

```swift
import receive_sharing_intent

class ShareViewController: RSIShareViewController {
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
```

`shouldAutoRedirect() = true` — расширение сразу открывает основное
приложение после выбора файла (без промежуточного экрана расширения), что и
нужно для сценария «выбрал фото → сразу попал в форму заказа».

8. Storyboard `MainInterface.storyboard`, который создал Xcode для
   расширения, трогать не нужно — `RSIShareViewController` сам всё
   отрисовывает/редиректит.

### Info.plist расширения — какие типы файлов принимать

9. В `ShareExtension/Info.plist` пропиши, что расширение принимает картинки
   (и видео, раз менеджеры получают и видео тоже):

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>10</integer>
            <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

### Swift Package Manager (нужен плагину)

10. В терминале, из корня проекта (`app/`):
    ```bash
    flutter config --enable-swift-package-manager
    flutter clean
    flutter pub get
    ```
11. Открой Xcode заново → таргет **ShareExtension** → **General** →
    **Frameworks, Libraries, and Embedded Content** → **+** → добавь
    `FlutterGeneratedPluginSwiftPackage` (появится в списке после
    `flutter pub get`, если Swift Package Manager включён).

### Готово — проверка

12. Собери и установи приложение на телефон обычным способом (TestFlight
    или через Xcode на подключённый iPhone).
13. В любом приложении (Фото, Telegram) нажми «Поделиться» на картинке →
    в списке приложений должен появиться **Arash** (или ShareExtension,
    можно переименовать Display Name в Info.plist на «Arash»).
14. Выбор Arash должен открыть приложение и сразу показать экран «Новый
    заказ» с превью прикреплённого фото сверху (реализовано в
    `add_order_screen.dart`) — дальше менеджер просто выбирает пункт выдачи,
    город, клиента и жмёт «Создать заказ»; фото прикрепится к заказу сразу
    после создания.

## Если что-то не работает

- Расширение не появляется в списке «Поделиться» → проверь, что оба
  таргета подписаны одним и тем же Team ID (Signing & Capabilities →
  Team), и что `NSExtensionActivationRule` в Info.plist разрешает нужный
  тип файла.
- Приложение открывается, но фото не подхватывается → проверь, что
  `group.com.arashexpress.courier` **дословно одинаковый** в App Groups
  ОБОИХ таргетов и в `CUSTOM_GROUP_ID` тоже.
- Работает только при перезапуске приложения, но не когда оно уже открыто →
  это нормально ловится кодом (`getInitialMedia` для холодного старта,
  `getMediaStream` для уже открытого приложения) — если не срабатывает,
  проверь, что фича сработала именно под ролью менеджер/админ
  (`_isManager` в `home_screen.dart`), для курьеров она намеренно
  отключена.
