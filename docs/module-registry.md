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
| Config/EggConfig | 2–5 | `OfferThemes`, `EggsPerOffer`, `BaseWeights`, `OutcomeBonus`, `ContributionBonus`, `RerollCosts`, `OfferSeconds`, `HatchSeconds[rarity]`, `SpeedUpCoinsPerSecond`, `StartEggCapacity`, `StartIncubators`, `MaxIncubators`, `IncubatorPrices`, `PetSlotsStep`, `PetSlotsBasePrice`, `ModelName(theme)` | — |
| Config/PetStyle | 2 | цвета `Rarity[rarity]`, `Theme[theme]` | — |
| Config/BatConfig | 3 | `Range`, `HalfAngle`, `Cooldown`, `KnockoutSeconds`, `ImmunitySeconds`, `KnockSpeed`, `KnockLift` | — |
| Config/PowerUpConfig | 3 | `Kinds` (Speed, PaintBomb, Lock), `SpawnInterval`, `MaxActive`, `PickupRadius`, `SpeedMultiplier`, `SpeedSeconds`, `BombRadius`, `LockRadius`, `LockSeconds`, `Colors`, `Labels` | — |
| Net/RemoteNames | 1 | `ClientToServer`, `ServerToClient` | — |
| Logic/ArenaGrid | 1 | `KeyboardLayout(unit, gap)`, `ForEachKeyInRadius(keys, x, z, r, visit)`, `BuildIndex(keys, cellSize)`, `ForEachKeyInRadiusIndexed(index, x, z, r, visit)` | — |
| Logic/TeamBalancer | 1 | `TeamSize(humans, limits)`, `Assign(groups, limits) -> Assignment` | — |
| Logic/Reward | 1–2 | `DecideWinner(red, blue)`, `OutcomeFor(team, winner)`, `Coins(outcome, keys, multiplier, config)`, `ContributionPct(keys, bestOnTeam)` | — |
| Logic/EggRoller | 2 | `Bonus(ctx, cfg)`, `Weights(ctx, cfg)`, `Odds(weights)`, `PickIndex(weights, rng)`, `RollOffer(ctx, themes, rarities, cfg, rng)`, `KindsFor(pets, theme, rarity)`, `RollPet(pets, theme, rarity, rng)`, `BestSlot(eggs, rarities)` | — |
| Logic/BatTargeting | 3 | `FindTarget(origin, look, candidates, range, halfAngle) -> Id?` (ближайший в конусе, по горизонтали) | — |
| Logic/Incubation | 5 | `HatchSeconds(rarity, cfg)`, `SpeedUpCost(hatchAt, now, cfg)`, `NextIncubatorPrice(owned, cfg)`, `NextPetSlotsPrice(capacity, start, cfg)`, `RarestEgg(eggs, rarities)` | — |
| Logic/Parties | 6 | `new(maxSize)`, `Get`, `MembersOf`, `Invite(state, from, to, now, ttl)`, `Respond(state, target, inviter, accept, now)`, `Leave`, `Remove`, `Expire`, `InvitesFor` (всё по user id) | — |
| Logic/MovementCheck | 3 | `IsSuspicious(fromX, fromZ, toX, toZ, dt, walkSpeed, settings)` | — |
| Logic/StatCalculator | 2 | `Zero()`, `PetBonus(pet, cfg) -> (stat?, value)`, `Totals(pets, cfg) -> Stats` (с потолками), `Power(stats)` | — |

## Сервер (ServerScriptService/Server)

Порядок загрузки: NetService → PlayerDataService → ReadyService → PartyService → PetService → StatsService → MovementGuard → ArenaService → PowerUpService → BatService → BotService → RoundService → EggService → PlotService → TutorialService → RewardService.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `SERVICE_ORDER` | Loader |
| Util/RateLimiter | 1 | `new(rate, burst, clock?)`, `:Allow(key)`, `:Forget(key)` | — |
| Util/Participant | 4 | тип `Participant` (Player или модель бота), `AsPlayer`, `Character`, `Humanoid`, `Root`, `IsPresent`, `UserId` (0 у ботов) | — |
| Util/Guard | 1 | `Boolean(v)`, `Integer(v, min, max)`, `String(v, maxLen)` | — |
| Data/ProfileTemplate | 1–5 | `Template` (этап 2: `Pets`, `Equipped`, `PetCapacity`; `PendingOffer` пустое; этап 5: `Eggs`, `EggCapacity`, `Incubators` — 3 пустых), `CurrentSchemaVersion` = 1 (новые поля добавляет Reconcile, миграция не нужна) | Types, PetConfig |
| Data/Migrations | 1 | `Apply(data, currentVersion, steps?)` | — |
| Services/NetService | 1 | `On(name, limit, handler)`, `FireClient(name, player, ...)`, `FireAllClients(name, ...)` | RemoteNames, RateLimiter |
| Services/PlayerDataService | 1–5 | `IsLoaded(p)`, `Get(p)`, `Update(p, mutator)`; сигналы `ProfileLoaded(p, data)`, `ProfileReleasing(p)`, `Changed(p, data)` после каждого `Update` | ProfileStore, NetService, Migrations, ProfileTemplate |
| Services/ReadyService | 1 | `IsReady(p)`, `SetReady(p, value)`; сигнал `ReadyChanged(p, value)`; атрибут игрока `Ready` | NetService, PlayerDataService, Guard |
| Services/PetService | 2 | `Count(data)`, `AddToProfile(data, kind, rarity) -> petId?` (внутри чужого `Update`), `GetEquipped(p)`; сигнал `EquippedChanged(p)`; атрибут игрока `EquippedPets` (ключи через запятую); remotes `PetEquip`, `PetSell` | PlayerDataService, NetService, Guard, PetConfig |
| Services/MovementGuard | 3 | `Check(p, position, walkSpeed) -> "Ok" \| "Skip" \| "Return"` (5 нарушений за 10 с → вернуть на спавн, запись в Output), `Reset(p)` после каждого серверного телепорта | MovementCheck |
| Services/StatsService | 2–3 | `SetSpeedBoost(p, mult, seconds)`, `ClearSpeedBoost(p)`, `GetStats(p)`, `GetWalkSpeed(p)` (с ускорением от бонуса), `GetPaintRadius(p)`, `GetLuck(p)`, `GetCoinMultiplier(p)`, `GetPower(p)`; сигнал `StatsChanged(p, stats)` | PetService, StatCalculator, PetConfig, ArenaConfig |
| Services/ArenaService | 1–2 | клавиши: BasePart с тегом `ArenaKey` под Workspace.Arena, цвет между раундами из атрибута `BaseColor`; `BeginRound(teams)` (радиус кисти каждого участника из StatsService), `EndRound() -> RoundScore`, `PaintArea(team, x, z, r, player?)`, `LockArea(team, x, z, r, seconds)` (запертые клавиши светятся Neon), `BlockPainting(p, until)`, `IsPaintBlocked(p)`, `GetRandomKeyTop(random)`, `FindKeyToPaint(team, from, random, samples)`, участники (игроки и боты) — `Participant`, `GetTeamSpawn(team)`; атрибуты `ScoreRed`, `ScoreBlue`; каждый тик спрашивает MovementGuard | ArenaGrid, ArenaConfig, TeamColors, StatsService, MovementGuard |
| Services/PowerUpService | 3–4 | `BeginRound(everyone)`, `EndRound()`, `GetActivePositions()`; боты тоже подбирают; шары в Workspace.ActivePowerUps (атрибут `PowerUp`), подбор по расстоянию на сервере, шлёт `PowerUpEvent` | ArenaService, StatsService, NetService, PowerUpConfig |
| Services/BatService | 3–4 | `BeginRound(everyone)` (бита в правую руку игрокам и ботам), `Equip(p)` после респавна, `Swing(participant)` для ботов, `IsKnockedOut`, `CanBeHit`, `EndRound()`; сигнал `KnockedOut(attacker, victim)`; remote `BatSwing`, шлёт `BatSwingFx`, `KnockedOut`; ботов отбрасывает сервер | ArenaService, MovementGuard, NetService, Participant, BatTargeting, BatConfig |
| Services/BotService | 4 | `Spawn(red, blue) -> { [Model]: TeamId }` (R15 цвета команды в Workspace.Bots, стоят до старта), `BeginRound(everyone)`, `Despawn()`; ИИ 2 раза в секунду: идти к ближайшей не своей клавише из 24 случайных, иногда к бонусу, удар битой не чаще раза в 3 с | ArenaService, BatService, PowerUpService, Participant |
| Match/LocalMatchSource | 1–6 | `CollectParticipants() -> { { Player } }`: готовые члены одной группы идут одним списком | ReadyService, PlayerDataService, PartyService |
| Services/PartyService | 6 | `GetMemberIds(p)`; сигнал `PartyChanged()`; атрибут игрока `PartyId` (0 — без группы); remotes `PartyInvite`, `PartyRespond`, `PartyLeave`, шлёт `PartyUpdate` | NetService, Guard, Parties |
| Services/RoundService | 1–2 | `GetPhase()`; сигналы `PhaseChanged(phase)`, `RoundEnded(result)`; атрибуты `RoundPhase`, `PhaseEndsAt`, `Winner`, атрибут игрока `Team`; скорость в раунде и сила для баланса команд из StatsService, после раунда скорость сбрасывается | ArenaService, PowerUpService, BatService, BotService, MovementGuard, StatsService, LocalMatchSource, TeamBalancer, Reward |
| Services/EggService | 2–5 | `CreateOffer(p, ctx)` (старое невыбранное предложение сначала выбирается автоматически), `GetOffer(p)`; выбранное яйцо → свободный инкубатор, иначе хранилище, иначе монеты (шлёт `EggPicked`); `Collect(p, i)` (питомец, шлёт `PetHatched`, затем следующее яйцо из хранилища), `PlaceStored(p, i)`, `SpeedUp(p, i)`, `BuyIncubator(p)`, `BuyPetSlots(p)`; сигнал `PetHatched(p, payload)`; remotes `EggPick`, `EggReroll`, `BuyUpgrade` | PlayerDataService, PetService, NetService, Guard, EggRoller, Incubation, EggConfig, PetConfig |
| Services/PlotService | 5 | 12 участков в Workspace.Plots (по 6 у западного и восточного края пола арены): табличка, 6 инкубаторов (атрибуты `State`, `HatchAt`, `Rarity`; подсказки `Main` и `SpeedUp` с атрибутом `Active`), витрина из 6 лучших питомцев; `Teleport(p)`; атрибут игрока `Plot`; remote `GoToPlot` | EggService, PlayerDataService, MovementGuard, NetService, Incubation |
| Services/TutorialService | 7 | remote `TutorialDone`: ставит в профиле `Tutorial.Done = true` (клиент сам не может менять данные) | NetService, PlayerDataService |
| Services/RewardService | 1–2 | слушает `RoundEnded`: монеты с множителем Coins, предложение яиц (исход, вклад, удача), шлёт `RoundResult` | PlayerDataService, ReadyService, RoundService, StatsService, EggService, NetService, Reward |

## Клиент (StarterPlayerScripts/Client)

Порядок загрузки: DataController → HudController → KeyPressController → EggOfferController → InventoryController → PetFollowController → BatController → EffectsController → PlotController → PartyController → ShopController → TutorialController.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `CONTROLLER_ORDER` | Loader |
| Util/ClientNet | 1 | `Fire(name, ...)`, `On(name, handler)` | — |
| Controllers/DataController | 1 | `Get() -> Profile?`; сигнал `Changed(profile)` | ClientNet |
| UI/Widgets | 2, 7 | `PlaySound(name)` (звук из Assets.Sounds, каждая кнопка играет Click), `Corner`, `Stroke`, `AspectRatio`, `Label`, `Button`, `Panel`, `ScreenGui` | — |
| UI/AssetModels | 2 | `Pet(kind)`, `Egg(theme)` (копии из ReplicatedStorage.Assets или nil), `LocalFront(model)`, `FrontCorrection(model)`, `FitHeight(model, h)`, `Viewport(parent, model?, color)` | PetConfig, EggConfig |
| Controllers/HudController | 1–2 | интерфейс: фаза и таймер, счёт, команда, монеты, кнопка «Играть», баннер итогов и отказов (`ActionResult`) | DataController, ClientNet |
| Controllers/KeyPressController | 1 | только визуал: клавиши проседают под любым персонажем и играют `KeySound`; пол целиком из клавиш: `arena/Arena.rbxm` (Keys с тегом ArenaKey, Decor, Floor), генерирует `lune run tools/build-arena` | — |
| Controllers/EggOfferController | 2–5 | окно «выбери 1 из 4» из `PendingOffer`, реролл, шансы, таймер, окно «куда ушло яйцо» (`EggPicked`) и «тебе выпал…» (`PetHatched`) | DataController, ClientNet, AssetModels, Widgets, EggRoller |
| Controllers/InventoryController | 2–5 | кнопка PETS, список питомцев, число яиц, покупка +25 мест, надеть/снять, продажа с подтверждением, сумма бонусов | DataController, ClientNet, AssetModels, Widgets, StatCalculator |
| Controllers/PlotController | 5, 7 | таймеры над инкубаторами своего участка, подсказки только на своём участке, цена ускорения, кнопка MY PLOT (с «!», когда яйцо готово) | DataController, ClientNet, Widgets, Incubation |
| Controllers/ShopController | 7 | кнопка SHOP (в лобби): следующий инкубатор и +25 мест для питомцев с ценами, кнопка серая, если монет не хватает, звук Purchase после покупки; заметка про Robux (этап 9) | DataController, ClientNet, Widgets, Incubation |
| Controllers/TutorialController | 7 | 5 подсказок сверху, шаги идут по действиям игрока (Ready, раунд, выбор яйца, вылупление, надеть питомца), SKIP; показывается, пока в профиле нет `Tutorial.Done` | DataController, ClientNet, Widgets |
| Controllers/PartyController | 6 | кнопка PARTY: список игроков (друзья первыми) с INVITE, состав группы и LEAVE, всплывающее приглашение ACCEPT / DECLINE | ClientNet, Widgets |
| Controllers/BatController | 3 | удар: клик, F или круглая кнопка BAT (видна только в раунде), серая на время перезарядки | ClientNet, Widgets, BatConfig |
| Controllers/EffectsController | 3, 8 | след и звук удара, искры попадания, полёт своей жертвы, надписи «Hit!», «Knocked out!», бонусов; вращение шаров-бонусов; звуки событий (победа Tada + конфетти, яйцо, питомец, эпический и легендарный с конфетти, отказ Error, приглашение Notification) | ClientNet, Widgets, BatConfig |
| Controllers/PetFollowController | 2, 8 | питомцы всех игроков бегут за ними (по атрибуту `EquippedPets`), шары-заглушки без ассетов; на телефоне и планшете частицы питомцев выключены | AssetModels, PetConfig |

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
| EggPicked | сервер → клиент | `(result: EggPickedPayload)` | — |
| PetHatched | сервер → клиент | `(result: PetHatchedPayload)` при сборе из инкубатора | — |
| BuyUpgrade | клиент → сервер | `(upgradeId: "Incubator" \| "PetSlots")` | 2/с, всплеск 4 |
| GoToPlot | клиент → сервер | `()` | 1/с, всплеск 2 |
| PartyInvite | клиент → сервер | `(targetUserId: number)` | 1/с, всплеск 3 |
| PartyRespond | клиент → сервер | `(inviterUserId: number, accept: boolean)` | 2/с, всплеск 4 |
| PartyLeave | клиент → сервер | `()` | 1/с, всплеск 2 |
| PartyUpdate | сервер → клиент | `(party: PartyPayload)` каждому игроку | — |
| TutorialDone | клиент → сервер | `()` подсказки пройдены или пропущены | 1/с, всплеск 2 |
| ActionResult | сервер → клиент | `(action: string, reason: ActionError)`, только отказы | — |
| BatSwing | клиент → сервер | `()` | 4/с, всплеск 4 (+ перезарядка 1,5 с на сервере) |
| BatSwingFx | сервер → всем | `(attacker: Model)` персонаж игрока или бота | — |
| KnockedOut | сервер → всем | `(victim: Model, attacker: Model, direction: Vector3, seconds)` | — |
| PowerUpEvent | сервер → всем | `(kind, userId, position: Vector3)`, userId 0 у бота | — |

## Решения этапа 2 (уточнения к design.md)

- Каждая тема яйца даёт один стат: Basic → Coins, Forest → Speed, Arctic → PaintRadius, Volcanic → Luck. В предложении 4 яйца, по одному каждой темы, редкость у каждого своя. Питомец той же редкости, что яйцо, вид случайный внутри темы и редкости.
- Шансы: базовые веса 50/28/15/6/1, вес редкости ранга r умножается на (1 + бонус)^r, бонус = победа 0,35 / ничья 0,15 + вклад × 0,3 + удача питомцев.
- Предложение передаётся в профиле (`PendingOffer` в DataSync), отдельного remote `EggOffer` нет. Ответы на успешные действия тоже приходят через DataSync, `ActionResult` шлёт только отказы.
- Этап 5: выбранное яйцо само встаёт в свободный инкубатор (без похода на участок), иначе в хранилище яиц (20), иначе превращается в монеты по цене продажи (5/10/25/60/150); окно выбора предупреждает заранее. После сбора питомца в инкубатор само встаёт следующее яйцо из хранилища. Инкубаторы управляются подсказками ProximityPrompt на участке, поэтому remotes `IncubatorPlace/Collect/SpeedUp` из design.md не нужны. Инкубатор хранит яйцо внутри себя (`{Egg, HatchAt}`), а не ссылку `EggId`.

## Решения этапа 7 (уточнения к design.md)

- Туториал: в design.md был только `TutorialController` + флаг в профиле. Клиент не может сам записать флаг (сервер главный), поэтому добавлен крошечный `TutorialService` с одним remote `TutorialDone`. Больше он ничего не делает.
- Магазин за монеты использует уже готовый remote `BuyUpgrade` (этап 5), новых покупок на сервере нет. Товары за Robux появятся на этапе 9.
- Адаптив: весь интерфейс в Scale с `UIAspectRatioConstraint`, поэтому кнопки слева (PARTY, PETS, MY PLOT, SHOP) стоят выше джойстика телефона.

## Решения этапа 8 (уточнения к design.md)

- Большая часть контента уже пришла раньше: клавиши арены и пол (этап 1), 24 питомца в 4 темах, яйца и бита из паков (этапы 2–3). Этап 8 добавил звуки и конфетти для событий и выключение частиц питомцев на телефонах (риск из `docs/assets.md`).
- Оформление лобби и участков (декор, таблички) не делал вслепую: его нужно смотреть в Studio вместе с Иваном.
