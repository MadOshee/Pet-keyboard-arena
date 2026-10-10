# Реестр модулей

Единый список созданных модулей, их публичных интерфейсов и зависимостей.
Обновляется в каждом этапе. Архитектура: [design.md](design.md), раздел 5.

## Общие (ReplicatedStorage/Shared)

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Util/Loader | 0 | `Run(entries)`; типы `Entry`, `Lifecycle` | — |
| Util/Signal | 1 | `Signal.new()`, `:Connect(fn) -> Connection`, `:Fire(...)`, `:DisconnectAll()` | — |
| Types | 0–1 | `Rarity`, `TeamId`, `Winner`, `Outcome`, `RoundPhase`, `Profile`, `RoundResultPayload` | — |
| Config/RoundConfig | 1 | тайминги фаз, размеры команд, `MinKeysForReward`, `Coins` | — |
| Config/ArenaConfig | 1 | размеры клавиш, частоты тиков, радиус кисти, скорость, точка лобби | — |
| Config/TeamColors | 1 | `Red`, `Blue`, `Neutral`, `KeyLabel`, `ForTeam(team)` | Types |
| Config/Strings | 1 | тексты интерфейса | — |
| Net/RemoteNames | 1 | `ClientToServer`, `ServerToClient` | — |
| Logic/ArenaGrid | 1 | `KeyboardLayout(unit, gap)`, `ForEachKeyInRadius(keys, x, z, r, visit)` | — |
| Logic/TeamBalancer | 1 | `TeamSize(humans, limits)`, `Assign(groups, limits) -> Assignment` | — |
| Logic/Reward | 1 | `DecideWinner(red, blue)`, `OutcomeFor(team, winner)`, `Coins(outcome, keys, multiplier, config)` | — |

## Сервер (ServerScriptService/Server)

Порядок загрузки: NetService → PlayerDataService → ReadyService → ArenaService → RoundService → RewardService.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `SERVICE_ORDER` | Loader |
| Util/RateLimiter | 1 | `new(rate, burst, clock?)`, `:Allow(key)`, `:Forget(key)` | — |
| Util/Guard | 1 | `Boolean(v)`, `Integer(v, min, max)`, `String(v, maxLen)` | — |
| Data/ProfileTemplate | 1 | `Template`, `CurrentSchemaVersion` | Types |
| Data/Migrations | 1 | `Apply(data, currentVersion, steps?)` | — |
| Services/NetService | 1 | `On(name, limit, handler)`, `FireClient(name, player, ...)`, `FireAllClients(name, ...)` | RemoteNames, RateLimiter |
| Services/PlayerDataService | 1 | `IsLoaded(p)`, `Get(p)`, `Update(p, mutator)`; сигналы `ProfileLoaded(p, data)`, `ProfileReleasing(p)` | ProfileStore, NetService, Migrations, ProfileTemplate |
| Services/ReadyService | 1 | `IsReady(p)`, `SetReady(p, value)`; сигнал `ReadyChanged(p, value)`; атрибут игрока `Ready` | NetService, PlayerDataService, Guard |
| Services/ArenaService | 1 | `BeginRound(teams)`, `EndRound() -> RoundScore`, `GetTeamSpawn(team)`; атрибуты `ScoreRed`, `ScoreBlue` | ArenaGrid, ArenaConfig, TeamColors |
| Match/LocalMatchSource | 1 | `CollectParticipants() -> { { Player } }` | ReadyService, PlayerDataService |
| Services/RoundService | 1 | `GetPhase()`; сигналы `PhaseChanged(phase)`, `RoundEnded(result)`; атрибуты `RoundPhase`, `PhaseEndsAt`, `Winner`, атрибут игрока `Team` | ArenaService, LocalMatchSource, TeamBalancer, Reward |
| Services/RewardService | 1 | слушает `RoundEnded`, шлёт `RoundResult` | PlayerDataService, ReadyService, RoundService, NetService, Reward |

## Клиент (StarterPlayerScripts/Client)

Порядок загрузки: DataController → HudController → KeyPressController.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `CONTROLLER_ORDER` | Loader |
| Util/ClientNet | 1 | `Fire(name, ...)`, `On(name, handler)` | — |
| Controllers/DataController | 1 | `Get() -> Profile?`; сигнал `Changed(profile)` | ClientNet |
| Controllers/HudController | 1 | интерфейс: фаза и таймер, счёт, команда, монеты, кнопка «Играть», баннер итогов | DataController, ClientNet |
| Controllers/KeyPressController | 1 | только визуал: клавиши проседают под любым персонажем и играют `KeySound`; пол целиком из клавиш: `arena/Arena.rbxm` (Keys с тегом ArenaKey, Decor, Floor), генерирует `lune run tools/build-arena` | — |

## Remotes

| Имя | Направление | Аргументы | Лимит |
|---|---|---|---|
| SetReady | клиент → сервер | `(ready: boolean)` | 2/с, всплеск 4 |
| DataSync | сервер → клиент | `(profile: Profile)` | — |
| RoundResult | сервер → клиент | `(result: RoundResultPayload)` | — |
