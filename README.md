# Egg Keyboard Arena

Игра для Roblox: командная покраска гигантской клавиатуры, яйца и питомцы.
Полный дизайн и архитектура: [docs/design.md](docs/design.md).

## Как проверить сборку (без программирования)

1. Открой вкладку **Actions** в этом репозитории и выбери последний зелёный запуск **CI**.
2. Внизу страницы в разделе **Artifacts** скачай `EggKeyboardArena-...` и распакуй zip.
3. Открой `EggKeyboardArena.rbxl` в Roblox Studio и нажми **Play**.
4. В окне **Output** (View → Output) должны появиться строки
   `[EggKeyboardArena] server started` и `[EggKeyboardArena] client started` без красных ошибок.

Чек-листы проверки по этапам: [docs/testing](docs/testing).

Для проверки с несколькими игроками: вкладка **Test** → **Clients and Servers** → выбрать число игроков → **Start**.

## Для разработки (Rojo)

1. Установить [Rokit](https://github.com/rojo-rbx/rokit), затем в папке проекта: `rokit install`.
2. `wally install` (скачивает ProfileStore).
3. `rojo serve`, в Studio подключиться плагином Rojo.

Проверки (их же запускает CI):

- форматирование: `stylua src tests`
- линтер: `selene src`
- тесты чистой логики: `lune run tests/run`
- строгая типизация: см. шаг «Type check» в `.github/workflows/ci.yml`

## Структура

| Папка | Куда попадает в Studio | Что внутри |
|---|---|---|
| `src/shared` | ReplicatedStorage/Shared | типы, конфиги, чистая логика |
| `src/server` | ServerScriptService/Server | авторитетные сервисы сервера |
| `src/client` | StarterPlayer/StarterPlayerScripts/Client | контроллеры, интерфейс |
| `tests` | (не попадает) | тесты Lune для чистой логики |
| `docs` | (не попадает) | дизайн-документ и реестр модулей |
