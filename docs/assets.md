# Ассеты

Модели из паков Ивана лежат в `assets/` и попадают в `ReplicatedStorage.Assets` (см. `default.project.json`).
Все файлы очищены от скриптов. Разбор исходных паков: `/mnt/project-files/assets/` в проекте.

| Файл | Что внутри | Откуда |
|---|---|---|
| `Key.rbxm` | MeshPart `Key` (меш `rbxassetid://120847269680553`, 2.2 × 1.4 × 2.2), SurfaceGui `Top` с TextLabel `Letter`, Sound `KeySound` | Free Ocean Keyboard |
| `Sounds.rbxm` | Folder `Sounds`: KeyPress, Click, Hover, Error, Success, Confetti, Purchase, Notification, LevelUp, Tada | Free Ocean Keyboard |
| `Pets.rbxm` | Folder `Pets`, 171 модель питомца | Pets & Eggs |
| `Eggs.rbxm` | Folder `Eggs`, 84 модели яиц (~28 тем) | Pets & Eggs |
| `Bat.rbxm` | Model `Bat`: Handle, Taper, Barrel, Knob (сварены с Handle), Attachment `Grip` на Handle, `HitPoint` с ParticleEmitter `HitBurst` (выключен, вызывать `:Emit(20)`), Trail `SwingTrail` (выключен) | Сделана с нуля |

## Как подключать
- **Клавиша.** `ArenaService` ищет детали с тегом `ArenaKey` в `Workspace.Arena`. Клон `Assets.Key` масштабируется под `ArenaConfig.KeyUnit` через `Size`. В оригинале клавиша при нажатии опускается на 1.35 studs за 0.3 с (Quad Out) и играет `KeySound` с PlaybackSpeed 0.95–1.05. Это делает клиент, сервер это не трогает.
- **Питомцы и яйца.** Модели называются так же, как в паке. Переименованы: `Dominus Egg*` → `Royal Egg*`, `Developer Pet` → `Coder Pet`. Таблица тем и предложенные ступени яиц: `/mnt/project-files/assets/pets-eggs-pack.md`.
- **Бита.** `PrimaryPart` = Handle, рукоять вниз по оси Y. Вешать на `RightHand` через `Grip`.

## Риски
- Меши и звуки загружены авторами паков. Если ассет не публичный, в нашем месте он будет пустым или беззвучным. Проверяется первым Play.
- 61 питомец с частицами и SurfaceAppearance; самые тяжёлые до 52 деталей. На телефонах частицы питомцев лучше выключать.
