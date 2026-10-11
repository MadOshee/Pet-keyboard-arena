# Реестр модулей

Единый список созданных модулей, их публичных интерфейсов и зависимостей.
Обновляется в каждом этапе. Архитектура: [design.md](design.md), раздел 5.

## Общие (ReplicatedStorage/Shared)

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Util/Loader | 0 | `Run(entries)`; типы `Entry`, `Lifecycle` | — |
| Util/Signal | 1 | `Signal.new()`, `:Connect(fn) -> Connection`, `:Fire(...)`, `:DisconnectAll()` | — |
| Types | 0–2 | `Rarity`, `TeamId`, `Winner`, `Outcome`, `RoundPhase`, `Stat`, `Stats`, `PetInstance`, `EggInstance`, `OfferContext`, `EggOffer`, `Profile`, `RoundResultPayload`, `PetHatchedPayload`, `ActionError` | — |
| Config/RoundConfig | 1 | тайминги фаз, размеры команд, `MinKeysForReward`, `Coins` | — |
| Config/ArenaConfig | 1 | размеры клавиш, частоты тиков, радиус кисти, скорость, точка лобби | — |
| Config/TeamColors | 1 | `Red`, `Blue`, `Neutral`, `KeyLabel`, `ForTeam(team)` | Types |
| Config/Strings | 1–2 | тексты интерфейса (раунд, яйца, питомцы, ошибки) | — |
| Config/PetConfig | 2 | `Rarities`, `Themes` (тема → один стат), `Pets` (ключ → имя, тема, редкость, модель из Assets.Pets), `Bonus[stat][rarity]`, `Caps`, `MaxEquipped`, `StartCapacity`, `SellValue` | — |
| Config/EggConfig | 2 | `OfferThemes`, `EggsPerOffer`, `BaseWeights`, `OutcomeBonus`, `ContributionBonus`, `RerollCosts`, `OfferSeconds`, `ModelName(theme)` | — |
| Config/PetStyle | 2 | цвета `Rarity[rarity]`, `Theme[theme]` | — |
| Config/BatConfig | 3 | `Range`, `HalfAngle`, `Cooldown`, `KnockoutSeconds`, `ImmunitySeconds`, `KnockSpeed`, `KnockLift` | — |
| Config/PowerUpConfig | 3 | `Kinds` (Speed, PaintBomb, Lock), `SpawnInterval`, `MaxActive`, `PickupRadius`, `SpeedMultiplier`, `SpeedSeconds`, `BombRadius`, `LockRadius`, `LockSeconds`, `Colors`, `Labels` | — |
| Net/RemoteNames | 1 | `ClientToServer`, `ServerToClient` | — |
| Logic/ArenaGrid | 1 | `KeyboardLayout(unit, gap)`, `ForEachKeyInRadius(keys, x, z, r, visit)`, `BuildIndex(keys, cellSize)`, `ForEachKeyInRadiusIndexed(index, x, z, r, visit)` | — |
| Logic/TeamBalancer | 1 | `TeamSize(humans, limits)`, `Assign(groups, limits) -> Assignment` | — |
| Logic/Reward | 1–2 | `DecideWinner(red, blue)`, `OutcomeFor(team, winner)`, `Coins(outcome, keys, multiplier, config)`, `ContributionPct(keys, bestOnTeam)` | — |
| Logic/EggRoller | 2 | `Bonus(ctx, cfg)`, `Weights(ctx, cfg)`, `Odds(weights)`, `PickIndex(weights, rng)`, `RollOffer(ctx, themes, rarities, cfg, rng)`, `KindsFor(pets, theme, rarity)`, `RollPet(pets, theme, rarity, rng)`, `BestSlot(eggs, rarities)` | — |
| Logic/BatTargeting | 3 | `FindTarget(origin, look, candidates, range, halfAngle) -> Id?` (ближайший в конусе, по горизонтали) | — |
| Logic/MovementCheck | 3 | `IsSuspicious(fromX, fromZ, toX, toZ, dt, walkSpeed, settings)` | — |
| Logic/StatCalculator | 2 | `Zero()`, `PetBonus(pet, cfg) -> (stat?, value)`, `Totals(pets, cfg) -> Stats` (с потолками), `Power(stats)` | — |

## Сервер (ServerScriptService/Server)

Порядок загрузки: NetService → PlayerDataService → ReadyService → PetService → StatsService → MovementGuard → ArenaService → PowerUpService → BatService → BotService → RoundService → EggService → RewardService.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `SERVICE_ORDER` | Loader |
| Util/RateLimiter | 1 | `new(rate, burst, clock?)`, `:Allow(key)`, `:Forget(key)` | — |
| Util/Participant | 4 | тип `Participant` (Player или модель бота), `AsPlayer`, `Character`, `Humanoid`, `Root`, `IsPresent`, `UserId` (0 у ботов) | — |
| Util/Guard | 1 | `Boolean(v)`, `Integer(v, min, max)`, `String(v, maxLen)` | — |
| Data/ProfileTemplate | 1–2 | `Template` (этап 2: `Pets`, `Equipped`, `PetCapacity`; `PendingOffer` пустое), `CurrentSchemaVersion` = 1 (новые поля добавляет Reconcile, миграция не нужна) | Types, PetConfig |
| Data/Migrations | 1 | `Apply(data, currentVersion, steps?)` | — |
| Services/NetService | 1 | `On(name, limit, handler)`, `FireClient(name, player, ...)`, `FireAllClients(name, ...)` | RemoteNames, RateLimiter |
| Services/PlayerDataService | 1 | `IsLoaded(p)`, `Get(p)`, `Update(p, mutator)`; сигналы `ProfileLoaded(p, data)`, `ProfileReleasing(p)` | ProfileStore, NetService, Migrations, ProfileTemplate |
| Services/ReadyService | 1 | `IsReady(p)`, `SetReady(p, value)`; сигнал `ReadyChanged(p, value)`; атрибут игрока `Ready` | NetService, PlayerDataService, Guard |
| Services/PetService | 2 | `Count(data)`, `AddToProfile(data, kind, rarity) -> petId?` (внутри чужого `Update`), `GetEquipped(p)`; сигнал `EquippedChanged(p)`; атрибут игрока `EquippedPets` (ключи через запятую); remotes `PetEquip`, `PetSell` | PlayerDataService, NetService, Guard, PetConfig |
| Services/MovementGuard | 3 | `Check(p, position, walkSpeed) -> "Ok" \| "Skip" \| "Return"` (5 нарушений за 10 с → вернуть на спавн, запись в Output), `Reset(p)` после каждого серверного телепорта | MovementCheck |
| Services/StatsService | 2–3 | `SetSpeedBoost(p, mult, seconds)`, `ClearSpeedBoost(p)`, `GetStats(p)`, `GetWalkSpeed(p)` (с ускорением от бонуса), `GetPaintRadius(p)`, `GetLuck(p)`, `GetCoinMultiplier(p)`, `GetPower(p)`; сигнал `StatsChanged(p, stats)` | PetService, StatCalculator, PetConfig, ArenaConfig |
| Services/ArenaService | 1–2 | клавиши: BasePart с тегом `ArenaKey` под Workspace.Arena, цвет между раундами из атрибута `BaseColor`; `BeginRound(teams)` (радиус кисти каждого участника из StatsService), `EndRound() -> RoundScore`, `PaintArea(team, x, z, r, player?)`, `LockArea(team, x, z, r, seconds)` (запертые клавиши светятся Neon), `BlockPainting(p, until)`, `IsPaintBlocked(p)`, `GetRandomKeyTop(random)`, `FindKeyToPaint(team, from, random, samples)`, участники (игроки и боты) — `Participant`, `GetTeamSpawn(team)`; атрибуты `ScoreRed`, `ScoreBlue`; каждый тик спрашивает MovementGuard | ArenaGrid, ArenaConfig, TeamColors, StatsService, MovementGuard |
| Services/PowerUpService | 3–4 | `BeginRound(everyone)`, `EndRound()`, `GetActivePositions()`; боты тоже подбирают; шары в Workspace.ActivePowerUps (атрибут `PowerUp`), подбор по расстоянию на сервере, шлёт `PowerUpEvent` | ArenaService, StatsService, NetService, PowerUpConfig |
| Services/BatService | 3–4 | `BeginRound(everyone)` (бита в правую руку игрокам и ботам), `Equip(p)` после респавна, `Swing(participant)` для ботов, `IsKnockedOut`, `CanBeHit`, `EndRound()`; сигнал `KnockedOut(attacker, victim)`; remote `BatSwing`, шлёт `BatSwingFx`, `KnockedOut`; ботов отбрасывает сервер | ArenaService, MovementGuard, NetService, Participant, BatTargeting, BatConfig |
| Services/BotService | 4 | `Spawn(red, blue) -> { [Model]: TeamId }` (R15 цвета команды в Workspace.Bots, стоят до старта), `BeginRound(everyone)`, `Despawn()`; ИИ 2 раза в секунду: идти к ближайшей не своей клавише из 24 случайных, иногда к бонусу, удар битой не чаще раза в 3 с | ArenaService, BatService, PowerUpService, Participant |
| Match/LocalMatchSource | 1 | `CollectParticipants() -> { { Player } }` | ReadyService, PlayerDataService |
| Services/RoundService | 1–2 | `GetPhase()`; сигналы `PhaseChanged(phase)`, `RoundEnded(result)`; атрибуты `RoundPhase`, `PhaseEndsAt`, `Winner`, атрибут игрока `Team`; скорость в раунде и сила для баланса команд из StatsService, после раунда скорость сбрасывается | ArenaService, PowerUpService, BatService, BotService, MovementGuard, StatsService, LocalMatchSource, TeamBalancer, Reward |
| Services/EggService | 2 | `CreateOffer(p, ctx)` (старое невыбранное предложение сначала выбирается автоматически), `GetOffer(p)`; сигнал `PetHatched(p, payload)`; remotes `EggPick`, `EggReroll`; автовыбор самого редкого яйца после `OfferSeconds` | PlayerDataService, PetService, NetService, Guard, EggRoller, EggConfig, PetConfig |
| Services/RewardService | 1–2 | слушает `RoundEnded`: монеты с множителем Coins, предложение яиц (исход, вклад, удача), шлёт `RoundResult` | PlayerDataService, ReadyService, RoundService, StatsService, EggService, NetService, Reward |

## Клиент (StarterPlayerScripts/Client)

Порядок загрузки: DataController → HudController → KeyPressController → EggOfferController → InventoryController → PetFollowController → BatController → EffectsController.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `CONTROLLER_ORDER` | Loader |
| Util/ClientNet | 1 | `Fire(name, ...)`, `On(name, handler)` | — |
| Controllers/DataController | 1 | `Get() -> Profile?`; сигнал `Changed(profile)` | ClientNet |
| UI/Widgets | 2 | `Corner`, `Stroke`, `AspectRatio`, `Label`, `Button`, `Panel`, `ScreenGui` | — |
| UI/AssetModels | 2 | `Pet(kind)`, `Egg(theme)` (копии из ReplicatedStorage.Assets или nil), `LocalFront(model)`, `FrontCorrection(model)`, `FitHeight(model, h)`, `Viewport(parent, model?, color)` | PetConfig, EggConfig |
| Controllers/HudController | 1–2 | интерфейс: фаза и таймер, счёт, команда, монеты, кнопка «Играть», баннер итогов и отказов (`ActionResult`) | DataController, ClientNet |
| Controllers/KeyPressController | 1 | только визуал: клавиши проседают под любым персонажем и играют `KeySound`; пол целиком из клавиш: `arena/Arena.rbxm` (Keys с тегом ArenaKey, Decor, Floor), генерирует `lune run tools/build-arena` | — |
| Controllers/EggOfferController | 2 | окно «выбери 1 из 4» из `PendingOffer`, реролл, шансы, таймер, окно «тебе выпал…» (`PetHatched`) | DataController, ClientNet, AssetModels, Widgets, EggRoller |
| Controllers/InventoryController | 2 | кнопка PETS, список питомцев, надеть/снять, продажа с подтверждением, сумма бонусов | DataController, ClientNet, AssetModels, Widgets, StatCalculator |
| Controllers/BatController | 3 | удар: клик, F или круглая кнопка BAT (видна только в раунде), серая на время перезарядки | ClientNet, Widgets, BatConfig |
| Controllers/EffectsController | 3 | след и звук удара, искры попадания, полёт своей жертвы, надписи «Hit!», «Knocked out!», бонусов; вращение шаров-бонусов | ClientNet, Widgets, BatConfig |
| Controllers/PetFollowController | 2 | питомцы всех игроков бегут за ними (по атрибуту `EquippedPets`), шары-заглушки без ассетов | AssetModels, PetConfig |

## Remotes

| Имя | Направление | Аргументы | Лимит |
|---|---|---|---|
| SetReady | клиент → сервер | `(ready: boolean)` | 2/с, всплеск 4 |
| DataSync | сервер → клиент | `(profile: Profile)` | — |
| RoundResult | сервер → клиент | `(result: RoundResultPayload)` | — |
| EggPick | клиент → сервер | `(offerId: string, slot: 1..4)` | 2/с, всплеск 4 |
| EggReroll | клиент → сервер | `(offerId: string)` | 2/с, всплеск 4 |
| PetEquip | клиент → сервер | `(petId: string, equip: boolean)` | 4/с, всплеск 8 |
| PetSell | клиент → сервер | `(petId: string)` | 4/с, всплеск 8 |
| PetHatched | сервер → клиент | `(result: PetHatchedPayload)` | — |
| ActionResult | сервер → клиент | `(action: string, reason: ActionError)`, только отказы | — |
| BatSwing | клиент → сервер | `()` | 4/с, всплеск 4 (+ перезарядка 1,5 с на сервере) |
| BatSwingFx | сервер → всем | `(attacker: Model)` персонаж игрока или бота | — |
| KnockedOut | сервер → всем | `(victim: Model, attacker: Model, direction: Vector3, seconds)` | — |
| PowerUpEvent | сервер → всем | `(kind, userId, position: Vector3)`, userId 0 у бота | — |

## Решения этапа 2 (уточнения к design.md)

- Каждая тема яйца даёт один стат: Basic → Coins, Forest → Speed, Arctic → PaintRadius, Volcanic → Luck. В предложении 4 яйца, по одному каждой темы, редкость у каждого своя. Питомец той же редкости, что яйцо, вид случайный внутри темы и редкости.
- Шансы: базовые веса 50/28/15/6/1, вес редкости ранга r умножается на (1 + бонус)^r, бонус = победа 0,35 / ничья 0,15 + вклад × 0,3 + удача питомцев.
- Предложение передаётся в профиле (`PendingOffer` в DataSync), отдельного remote `EggOffer` нет. Ответы на успешные действия тоже приходят через DataSync, `ActionResult` шлёт только отказы.
- Инвентарь полон: питомец из яйца сразу превращается в монеты по цене продажи (5/10/25/60/150), окно выбора предупреждает заранее.
