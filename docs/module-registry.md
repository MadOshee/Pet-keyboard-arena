# Реестр модулей

Единый список созданных модулей, их публичных интерфейсов и зависимостей.
Обновляется в каждом этапе. Архитектура: [design.md](design.md), раздел 5.

| Модуль | Путь в Studio | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|---|
| Loader | ReplicatedStorage/Shared/Util/Loader | 0 | `Run(entries: { Entry })`; типы `Entry`, `Lifecycle` | — |
| Types | ReplicatedStorage/Shared/Types | 0 | `Rarity` | — |
| Bootstrap (server) | ServerScriptService/Server/Bootstrap | 0 | точка входа, список `SERVICE_ORDER` | Loader |
| Bootstrap (client) | StarterPlayerScripts/Client/Bootstrap | 0 | точка входа, список `CONTROLLER_ORDER` | Loader |
