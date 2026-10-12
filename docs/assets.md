# Ассеты

Модели из паков Ивана лежат в `assets/` и попадают в `ReplicatedStorage.Assets` (см. `default.project.json`).
Все файлы очищены от скриптов. Разбор исходных паков: `/mnt/project-files/assets/` в проекте.

| Файл | Что внутри | Откуда |
|---|---|---|
| `Key.rbxm` | MeshPart `Key` (меш `rbxassetid://120847269680553`, 2.2 × 1.4 × 2.2), SurfaceGui `Top` с TextLabel `Letter`, Sound `KeySound` (звук из пака, `rbxassetid://122473549531722`) | Free Ocean Keyboard |
| `Sounds.rbxm` | Folder `Sounds`: KeyPress, Click, Hover, Error, Success, Confetti, Purchase, Notification, LevelUp, Tada | Free Ocean Keyboard |
| `Pets.rbxm` | Folder `Pets`, 171 модель питомца | Pets & Eggs |
| `Eggs.rbxm` | Folder `Eggs`, 84 модели яиц (~28 тем) | Pets & Eggs |
| `Bat.rbxm` | Model `Bat`: Handle, Taper, Barrel, Knob (сварены с Handle), Attachment `Grip` на Handle, `HitPoint` с ParticleEmitter `HitBurst` (выключен, вызывать `:Emit(20)`), Trail `SwingTrail` (выключен) | Сделана с нуля |
| `UI.rbxm` | Folder `UI`: шаблоны `Window` (окно с полосой заголовка `Top`), `Button`, `MenuButton`, `Close`, `CashText`, `Bar`; `Sounds` (11 звуков интерфейса: Click, Hover, Error, Buy, Success, Purchase…); `Icons` (Shop, Index, Pass, Rebirth, Settings). Собран из `StarterGui.GameUI` и `SoundService.SFX` пака без 3 его скриптов | Studs UI Pack 2 V1.3 |

## Как подключать
- **Клавиша.** `ArenaService` ищет детали с тегом `ArenaKey` в `Workspace.Arena`. Клон `Assets.Key` масштабируется под `ArenaConfig.KeyUnit` через `Size`. В оригинале клавиша при нажатии опускается на 1.35 studs за 0.3 с (Quad Out) и играет `KeySound` с PlaybackSpeed 0.95–1.05. Это делает клиент, сервер это не трогает.
- **Питомцы и яйца.** Модели называются так же, как в паке. Переименованы: `Dominus Egg*` → `Royal Egg*`, `Developer Pet` → `Coder Pet`. Таблица тем и предложенные ступени яиц: `/mnt/project-files/assets/pets-eggs-pack.md`.
- **Интерфейс.** Всё строит `UI/Widgets` из шаблонов `Assets.UI`: цвет кнопки задаётся одним цветом, светлый верх, тёмная кромка и обводка считаются из него. Тексты пака двухслойные (тёмный `Name` и белый `Color` над ним), Widgets держит их одинаковыми. У шаблонов кнопок в паке `Active = false`, Widgets включает его, иначе `Activated` не срабатывает. Шаблоны используют новые `UIShadow` и `StrokeSizingMode`, поэтому нужен свежий Studio.
- **Бита.** `PrimaryPart` = Handle, рукоять вниз по оси Y. Вешать на `RightHand` через `Grip`.

## Риски
- Меши и звуки загружены авторами паков. Если ассет не публичный, в нашем месте он будет пустым или беззвучным. Проверяется первым Play.
- 61 питомец с частицами и SurfaceAppearance; самые тяжёлые до 52 деталей. На телефонах частицы питомцев лучше выключать.
