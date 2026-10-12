# Реестр модулей

Единый список созданных модулей, их публичных интерфейсов и зависимостей.
Обновляется в каждом этапе. Архитектура: [design.md](design.md), раздел 5.

## Общие (ReplicatedStorage/Shared)

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Util/Loader | 0 | `Run(entries)`; типы `Entry`, `Lifecycle` | — |
| Util/Signal | 1 | `Signal.new()`, `:Connect(fn) -> Connection`, `:Fire(...)`, `:DisconnectAll()` | — |
| Util/ModelFront | платформы | `LocalFront(model)`, `Correction(model)` (поворот, после которого лицо модели смотрит в -Z; по декали `FaceDecal`) | — |
| Types | 0–2, карта | `Rarity`, `TeamId`, `Winner`, `Outcome`, `RoundPhase` (+ `Starting`), `QueueMode` (`Solo`/`Party`), `Stat`, `Stats`, `PetInstance`, `EggInstance`, `OfferContext`, `EggOffer`, `Profile`, `RoundResultPayload`, `PetHatchedPayload`, `OfflineIncomePayload`, `PlatformActionKind`, `ActionError` (+ `OnPlatform`, `EggsFull`, `Locked`); `Incubator` = платформа участка (`Egg`, `HatchAt`, `PetId`), в `Profile` поле `IncomeAt` | — |
| Config/RoundConfig | 1, карта | тайминги фаз (`StartingSeconds` — отсчёт после входа в портал), размеры команд, `MinKeysForReward`, `Coins` | — |
| Config/ArenaConfig | 1, карта | размеры клавиш, частоты тиков, радиус кисти, скорость, центр арены (`CenterZ` = 3000, далеко от хаба), точка возврата на площадь хаба, `PortalRadius`, `PortalServerRadius` | — |
| Config/TeamColors | 1 | `Red`, `Blue`, `Neutral`, `KeyLabel`, `ForTeam(team)` | Types |
| Config/Strings | 1–2 | тексты интерфейса (раунд, яйца, питомцы, ошибки) | — |
| Config/PetConfig | 2, баланс | `Rarities`, `Themes` (тема → главный стат и `IncomeMultiplier`), `ThemeOrder` (22 яйца пака, от частого к редкому), `Pets` (171 питомец, строится из списка яиц: ключ = имя модели без пробелов и знаков → имя, тема, редкость по месту в яйце, `Order` в яйце, модель из Assets.Pets, `Buffs[stat]` (лучший 3, следующий 2, остальные 1), `Income` монет/с), `Bonus[stat][rarity]`, `BonusPerEgg`, `Caps`, `StatOrder` (Speed, Power, PaintRadius, Luck, Coins), `RarityIncome`, `MaxEquipped`, `StartCapacity`, `OfflineIncomeMaxSeconds`, `SellValue`; цифры в `docs/pet-balance.md` | — |
| Config/EggConfig | 2–5, баланс | `OfferThemes` (= `PetConfig.ThemeOrder`), `EggsPerOffer`, `ThemeWeights` (как часто тема выпадает в слоте: каждое следующее яйцо ×0,75), `BaseWeights`, `OutcomeBonus`, `ContributionBonus`, `RerollCosts`, `OfferSeconds`, `HatchSeconds[rarity]`, `SpeedUpCoinsPerSecond`, `StartEggCapacity`, `StartIncubators`, `MaxIncubators`, `IncubatorPrices`, `PetSlotsStep`, `PetSlotsBasePrice`, `ModelName(theme)` | — |
| Config/PetStyle | 2 | цвета `Rarity[rarity]`, `Theme[theme]` (все 22 яйца), `Stat[stat]` (цвет баффа) | — |
| Config/BatConfig | 3 | `Range`, `HalfAngle`, `Cooldown`, `KnockoutSeconds`, `ImmunitySeconds`, `KnockSpeed`, `KnockLift` | — |
| Config/ShopConfig | 9 | `GamePasses` (VIP, FastHatch, DoubleCoins) и `Products` (SpeedUpEgg, Reroll, LuckPotion, Coins1000/5000/15000): `Id` (0 — ещё не создан), `Order`, `Coins`; множители пассов, бонус и длительность зелья, `PurchaseHistorySize` | — |
| Config/PowerUpConfig | 3 | `Kinds` (Speed, PaintBomb, Lock), `SpawnInterval`, `MaxActive`, `PickupRadius`, `SpeedMultiplier`, `SpeedSeconds`, `BombRadius`, `LockRadius`, `LockSeconds`, `Colors`, `Labels` | — |
| Net/RemoteNames | 1 | `ClientToServer`, `ServerToClient` | — |
| Logic/ArenaGrid | 1 | `KeyboardLayout(unit, gap)`, `ForEachKeyInRadius(keys, x, z, r, visit)`, `BuildIndex(keys, cellSize)`, `ForEachKeyInRadiusIndexed(index, x, z, r, visit)` | — |
| Logic/TeamBalancer | 1 | `TeamSize(humans, limits)`, `Assign(groups, limits) -> Assignment` | — |
| Logic/Reward | 1–2 | `DecideWinner(red, blue)`, `OutcomeFor(team, winner)`, `Coins(outcome, keys, multiplier, config)`, `ContributionPct(keys, bestOnTeam)` | — |
| Logic/EggRoller | 2 | `Bonus(ctx, cfg)`, `Weights(ctx, cfg)`, `Odds(weights)`, `PickIndex(weights, rng)`, `RollOffer(ctx, themes, rarities, cfg, rng)` (каждое из `EggsPerOffer` яиц: тема по `ThemeWeights`, редкость по `Weights`), `KindsFor(pets, theme, rarity)`, `HatchKinds(pets, theme, rarity, rarities?)` (если в яйце нет такой редкости — ближайшая, при равенстве ниже), `RollPet(pets, theme, rarity, rng, rarities?)`, `BestSlot(eggs, rarities)` | — |
| Logic/BatTargeting | 3 | `FindTarget(origin, look, candidates, range, halfAngle) -> Id?` (ближайший в конусе, по горизонтали) | — |
| Logic/PetIncome | платформы | `Rate(kind, cfg)` (доход вида из `PetConfig.Pets[kind].Income`), `Earned(earners {Kind, From?}, lastAt, now, cfg)` (доход питомцев на платформах за период, оффлайн не больше `OfflineIncomeMaxSeconds`; вылупившийся внутри периода считает от `From`), `PlacedPets(slots) -> {[petId]: index}` | — |
| Logic/Incubation | 5 | `HatchSeconds(rarity, cfg)`, `SpeedUpCost(hatchAt, now, cfg)`, `NextIncubatorPrice(owned, cfg)`, `NextPetSlotsPrice(capacity, start, cfg)`, `RarestEgg(eggs, rarities)` | — |
| Logic/Parties | 6 | `new(maxSize)`, `Get`, `MembersOf`, `Invite(state, from, to, now, ttl)`, `Respond(state, target, inviter, accept, now)`, `Leave`, `Remove`, `Expire`, `InvitesFor` (всё по user id) | — |
| Logic/Purchases | 9 | `KeyForId(items, id)`, `Remember(history, purchaseId, size) -> boolean` (false — уже выдано), `Sorted(items)`, `LuckWithPotion(luck, bonus, cap)` | — |
| Logic/MovementCheck | 3 | `IsSuspicious(fromX, fromZ, toX, toZ, dt, walkSpeed, settings)` | — |
| Logic/StatCalculator | 2, баланс | `Zero()`, `PetBuffs(pet, cfg) -> {[stat]: value}`, `Totals(pets, cfg) -> Stats` (5 статов, с потолками), `TeamWeight(stats)` (Speed + PaintRadius + Power, для балансировки команд) | — |

## Сервер (ServerScriptService/Server)

Порядок загрузки: NetService → PlayerDataService → GamePassService → ReadyService → PartyService → PortalService → PetService → StatsService → MovementGuard → ArenaService → PowerUpService → BatService → BotService → RoundService → EggService → PlatformService → PlotService → TutorialService → MonetizationService → RewardService.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `SERVICE_ORDER` | Loader |
| Util/RateLimiter | 1 | `new(rate, burst, clock?)`, `:Allow(key)`, `:Forget(key)` | — |
| Util/Participant | 4 | тип `Participant` (Player или модель бота), `AsPlayer`, `Character`, `Humanoid`, `Root`, `IsPresent`, `UserId` (0 у ботов) | — |
| Util/Guard | 1 | `Boolean(v)`, `Integer(v, min, max)`, `String(v, maxLen)` | — |
| Data/ProfileTemplate | 1–5 | `Template` (этап 2: `Pets`, `Equipped`, `PetCapacity`; `PendingOffer` пустое; этап 5: `Eggs`, `EggCapacity`, `Incubators` — 3 пустых; платформы: `IncomeAt` = 0), `CurrentSchemaVersion` = 1 (новые поля добавляет Reconcile, миграция не нужна) | Types, PetConfig |
| Data/Migrations | 1 | `Apply(data, currentVersion, steps?)` | — |
| Services/NetService | 1 | `On(name, limit, handler)`, `FireClient(name, player, ...)`, `FireAllClients(name, ...)` | RemoteNames, RateLimiter |
| Services/PlayerDataService | 1–5, 9 | `IsLoaded(p)`, `Get(p)`, `Update(p, mutator)`, `GrantPurchase(p, purchaseId, mutator) -> ProductPurchaseDecision` (ждёт сохранения); сигналы `ProfileLoaded(p, data)`, `ProfileReleasing(p)`, `Changed(p, data)` после каждого `Update` | ProfileStore, NetService, Migrations, ProfileTemplate, ShopConfig, Purchases |
| Services/ReadyService | 1, карта | очередь на матч: `IsReady(p)`, `GetMode(p) -> QueueMode?`, `SetReady(p, value, mode?)`; сигнал `ReadyChanged(p, value)`; атрибуты игрока `Ready`, `QueueMode`; remote `SetReady` только выходит из очереди | NetService, Guard |
| Services/PortalService | карта | remote `JoinQueue(mode)`: проверяет, что игрок у портала (World.Portal) и не в матче; Solo — в очередь один, Party — вся группа (ошибка `NoParty` без группы) | NetService, PartyService, PlayerDataService, ReadyService, Guard, ArenaConfig |
| Services/PetService | 2, платформы | `Count(data)` (без питомцев на платформах), `AddToProfile(data, kind, rarity, onPlatform?) -> petId?` (внутри чужого `Update`; на платформу — без лимита), `GetEquipped(p)`, `PublishEquipped(p)`; питомца на платформе нельзя надеть и продать (`OnPlatform`); сигнал `EquippedChanged(p)`; атрибут игрока `EquippedPets` (ключи через запятую); remotes `PetEquip`, `PetSell` | PlayerDataService, NetService, Guard, PetConfig |
| Services/MovementGuard | 3 | `Check(p, position, walkSpeed) -> "Ok" \| "Skip" \| "Return"` (5 нарушений за 10 с → вернуть на спавн, запись в Output), `Reset(p)` после каждого серверного телепорта | MovementCheck |
| Services/StatsService | 2–3 | `SetSpeedBoost(p, mult, seconds)`, `ClearSpeedBoost(p)`, `GetStats(p)`, `GetWalkSpeed(p)` (с ускорением от бонуса), `GetPaintRadius(p)`, `GetLuck(p)`, `GetCoinMultiplier(p)`, `GetPower(p)` (бафф Power для биты), `GetTeamWeight(p)`; сигнал `StatsChanged(p, stats)` | PetService, StatCalculator, PetConfig, ArenaConfig |
| Services/ArenaService | 1–2 | клавиши: BasePart с тегом `ArenaKey` под Workspace.Arena, цвет между раундами из атрибута `BaseColor`; `BeginRound(teams)` (радиус кисти каждого участника из StatsService), `EndRound() -> RoundScore`, `PaintArea(team, x, z, r, player?)`, `LockArea(team, x, z, r, seconds)` (запертые клавиши светятся Neon), `BlockPainting(p, until)`, `IsPaintBlocked(p)`, `GetRandomKeyTop(random)`, `FindKeyToPaint(team, from, random, samples)`, участники (игроки и боты) — `Participant`, `GetTeamSpawn(team)`; атрибуты `ScoreRed`, `ScoreBlue`; каждый тик спрашивает MovementGuard | ArenaGrid, ArenaConfig, TeamColors, StatsService, MovementGuard |
| Services/PowerUpService | 3–4 | `BeginRound(everyone)`, `EndRound()`, `GetActivePositions()`; боты тоже подбирают; шары в Workspace.ActivePowerUps (атрибут `PowerUp`), подбор по расстоянию на сервере, шлёт `PowerUpEvent` | ArenaService, StatsService, NetService, PowerUpConfig |
| Services/BatService | 3–4 | `BeginRound(everyone)` (бита в правую руку игрокам и ботам), `Equip(p)` после респавна, `Swing(participant)` для ботов, `IsKnockedOut`, `CanBeHit`, `EndRound()`; сигнал `KnockedOut(attacker, victim)`; remote `BatSwing`, шлёт `BatSwingFx`, `KnockedOut`; ботов отбрасывает сервер; Power атакующего удлиняет вектор отлёта (`direction × (1 + Power)`) | ArenaService, MovementGuard, NetService, Participant, BatTargeting, BatConfig |
| Services/BotService | 4 | `Spawn(red, blue) -> { [Model]: TeamId }` (R15 цвета команды в Workspace.Bots, стоят до старта), `BeginRound(everyone)`, `Despawn()`; ИИ 2 раза в секунду: идти к ближайшей не своей клавише из 24 случайных, иногда к бонусу, удар битой не чаще раза в 3 с | ArenaService, BatService, PowerUpService, Participant |
| Match/LocalMatchSource | 1–6, карта | `CollectParticipants() -> { { Player } }`: игроки из очереди, вошедшие через PARTY GAME, идут одной группой; `HasParticipants()` | ReadyService, PlayerDataService, PartyService |
| Services/PartyService | 6 | `GetMemberIds(p)`; сигнал `PartyChanged()`; атрибут игрока `PartyId` (0 — без группы); remotes `PartyInvite`, `PartyRespond`, `PartyLeave`, шлёт `PartyUpdate` | NetService, Guard, Parties |
| Services/RoundService | 1–2, карта | Intermission (очереди нет) → Starting (отсчёт на хабе) → Countdown/Playing/Results на арене → возврат на хаб и выход из очереди; `GetPhase()`; сигналы `PhaseChanged(phase)`, `RoundEnded(result)`; атрибуты `RoundPhase`, `PhaseEndsAt`, `Winner`, атрибут игрока `Team`; скорость в раунде и сила для баланса команд из StatsService, после раунда скорость сбрасывается | ArenaService, PowerUpService, BatService, BotService, MovementGuard, StatsService, LocalMatchSource, TeamBalancer, Reward |
| Services/EggService | 2–5, 9 | `NextIncubatorPrice(data)` (VIP-инкубатор не сдвигает цены), `GrantSpeedUp(data)`, `GrantVipIncubator(p)`; купленные рероллы и ускорения тратятся раньше монет; пасс FastHatch ускоряет инкубацию на 30%; `CreateOffer(p, ctx)` (старое невыбранное предложение сначала выбирается автоматически), `GetOffer(p)`; выбранное яйцо → хранилище, иначе монеты (шлёт `EggPicked`); `SpeedUp(p, i)`, `BuyIncubator(p)` (следующая платформа), `BuyPetSlots(p)`, `HatchSeconds(p, rarity)`; remotes `EggPick`, `EggReroll`, `BuyUpgrade` | PlayerDataService, NetService, Guard, EggRoller, Incubation, EggConfig, PetConfig |
| Services/PlatformService | платформы | remote `PlatformAction(index, action, id?)`: `PlaceEgg` (яйцо из хранилища), `PlacePet` (снимает с игрока, если надет), `Take` (питомец в инвентарь, яйцо в хранилище), `SpeedUp`, `Buy` (только следующая); раз в секунду вылупляет готовые яйца прямо на платформе (шлёт `PetHatched`) и платит доход питомцев до `IncomeAt`; при входе платит за время оффлайн (до 24 ч) и шлёт `OfflineIncome` | EggService, PetService, PlayerDataService, NetService, Guard, EggRoller, PetIncome, PetConfig, EggConfig |
| Services/PlotService | 5, карта, платформы | по участку на каждый `PlotAnchor` карты (сейчас 6, в зданиях баз World.Islands.*; без карты — 12 по краям арены) в Workspace.Plots: табличка (высота из атрибута `SignHeight` якоря), 20 невидимых частей `PlatformN` на платформах здания (без карты — сетка 5×4 зелёных площадок) с атрибутами `State` (`Locked`/`Empty`/`Incubating`/`Pet`), `HatchAt`, `Rarity`, `Kind`, `Income`, `Price` и `ObjectValue Button` → зелёная кнопка; на платформе модель `Shown` (яйцо или питомец лицом к кнопке); `Teleport(p)`; атрибут игрока `Plot`; remote `GoToPlot` | EggService, PlayerDataService, MovementGuard, NetService, PetIncome, ModelFront |
| Services/GamePassService | 9 | `Owns(p, name)`; сигнал `PassAdded(p, name)`; проверка пассов при входе и после покупки в игре; атрибуты игрока `Pass_<name>` | ShopConfig, Purchases |
| Services/MonetizationService | 9 | `MarketplaceService.ProcessReceipt`: товар по id из ShopConfig, выдача через `PlayerDataService:GrantPurchase`; VIP: тег над головой и бесплатный инкубатор | PlayerDataService, EggService, GamePassService, ShopConfig, Purchases |
| Services/TutorialService | 7 | remote `TutorialDone`: ставит в профиле `Tutorial.Done = true` (клиент сам не может менять данные) | NetService, PlayerDataService |
| Services/RewardService | 1–2, 9 | слушает `RoundEnded`: монеты с множителем Coins и пассом 2x, зелье удачи (+0,5 удачи до потолка на 5 предложений), предложение яиц (исход, вклад, удача), шлёт `RoundResult` | PlayerDataService, ReadyService, RoundService, StatsService, EggService, NetService, Reward |

## Клиент (StarterPlayerScripts/Client)

Порядок загрузки: DataController → HudController → PackUiController → KeyPressController → EggOfferController → InventoryController → PetIndexController → BackpackController → PetFollowController → BatController → EffectsController → PlotController → PlatformController → PartyController → PortalController → ShopController → TutorialController.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| Bootstrap | 0 | точка входа, `CONTROLLER_ORDER` | Loader |
| Util/ClientNet | 1 | `Fire(name, ...)`, `On(name, handler)` | — |
| Controllers/DataController | 1 | `Get() -> Profile?`; сигнал `Changed(profile)` | ClientNet |
| UI/Widgets | 2, 7, UI-пак | всё в стиле Studs UI Pack из `Assets.UI` (без шаблонов простые кнопки): `PlaySound(name)` (сначала звуки UI-пака, потом Assets.Sounds; кнопки играют Click, при наведении мышью Hover), `Corner`, `Stroke`, `AspectRatio`, `Label` (шрифт пака с обводкой), `Button` (кнопка пака; Text, TextColor3 и BackgroundColor3 переносятся на рисунок), `Panel(..., barColor?)` (полупрозрачное окно, с barColor полоса заголовка), `MoneyLabel` (жёлто-зелёный текст монет), `ProgressBar(...)` → полоса, заливка, текст слева и справа, `MenuButton(name, text, icon, color, order)` (квадратная кнопка с иконкой в общей колонке слева), `AnimatePress(button)` (рост при наведении, сжатие при нажатии), `Card(name, parent, size, pos, color) -> (card, title)` (плитка индекса пака), `TintCard(card, color)`, `ScreenGui` | — |
| UI/PetText | баланс | `Bonus(stat, value)` («+5% Speed»), `Buffs(kind)` ({Stat, Text}), `BuffLines(kind)`, `Number(n)` («1,234») | PetConfig, Strings |
| UI/AssetModels | 2 | `Pet(kind)`, `Egg(theme)` (копии из ReplicatedStorage.Assets или nil), `LocalFront(model)`, `FrontCorrection(model)` (через Util/ModelFront), `FitHeight(model, h)`, `Viewport(parent, model?, color)` (камера вписывает все углы модели в кадр и пересчитывается при смене размера), `Frame(viewport, direction?)` | PetConfig, EggConfig |
| Controllers/HudController | 1–2, карта | интерфейс: фаза и таймер (только в очереди и в матче), счёт (только в матче), команда, монеты, кнопка LEAVE QUEUE, баннер итогов и отказов (`ActionResult`) | DataController, ClientNet |
| Controllers/PackUiController | UI-пак | весь экран пака (`Assets.UI.GameUI`), чтобы Иван выбрал, что оставить: кнопки по краям открывают окна пака с тем же именем (Shop, Rebirth, Pets, Backpack, Daily, Upgrades) с анимацией выезда (окна в своём слое `GameUIWindows`), `Close` закрывает; содержимое окон — примеры из пака. Настоящее: монеты в счётчике CashFrame (с иконкой денег), MY BASE → `GoToPlot`, окна Pets и Backpack заполняют свои контроллеры, Party (бывший верхний Shop) → `PartyController:Toggle()`. Нашу колонку `Menu` (Widgets.MenuButton) выключает: Иван оставил только кнопки пака. В матче скрыт ; `Opened(name)` сигнал при открытии окна, `GetWindow(name)`, `IsOpen(name)` | DataController, PartyController, ClientNet, Widgets |
| Controllers/KeyPressController | 1, 10 | только визуал: клавиши проседают под любым персонажем (игроки и боты) и играют `KeySound`; пол целиком из клавиш: `arena/Arena.rbxm` (Keys с тегом ArenaKey, Decor, Floor), генерирует `lune run tools/build-arena` | — |
| Controllers/EggOfferController | 2–5, 9 | окно «выбери 1 из 4» из `PendingOffer`, реролл (бесплатный, если куплен), кнопка R$ REROLL (если товар создан), шансы, таймер, окно «куда ушло яйцо» (`EggPicked`) и «тебе выпал…» (`PetHatched`) | DataController, ClientNet, AssetModels, Widgets, EggRoller |
| Controllers/PetIndexController | UI-пак | окно Pets (бывший Index): ряд на каждое из 22 яиц (модель, шанс в слоте, питомцы по 3 в ряд от слабого к лучшему, прогресс x/n), чужие питомцы силуэтом «???»; справа выбранный: модель, имя, редкость, доход $/с, баффы в столбик цветом стата, «You have N · Equipped x/3» и EQUIP/UNEQUIP (`PetEquip` с id подходящего питомца); внизу Unlocked x/171 | DataController, PackUiController, ClientNet, Widgets, AssetModels, PetText, PetIncome |
| Controllers/BackpackController | UI-пак | окно Backpack с вкладками Bats (бита и отлёт от Power), Eggs (яйца в хранилище, x/20), Traits (пока пусто) | DataController, PackUiController, Widgets, AssetModels, StatCalculator |
| Controllers/InventoryController | 2–5 | (старое окно, кнопка выключена вместе с колонкой Menu) кнопка PETS, `Toggle()` (открыть или закрыть окно), список питомцев (без стоящих на платформах), число яиц, покупка +25 мест, надеть/снять, продажа с подтверждением, сумма бонусов | DataController, ClientNet, AssetModels, Widgets, StatCalculator |
| Controllers/PlotController | 5, 7, платформы | надписи над платформами своего участка: цена следующей, «Empty», таймер яйца, доход питомца «+N/s»; кнопка MY PLOT; на телефоне частицы питомцев на участках выключены | ClientNet, Widgets |
| Controllers/PlatformController | платформы | зелёная кнопка перед платформой проседает со щелчком, пока на ней стоит персонаж; на своём участке открывает окно платформы: выбор яйца или питомца (`PlaceEgg`/`PlacePet`), у занятой — таймер, HATCH NOW, доход, TAKE BACK, у закрытой — BUY; окно закрывается, когда сходишь; сообщение `OfflineIncome` | DataController, ClientNet, Widgets, AssetModels, Incubation, PetIncome |
| Controllers/ShopController | 7, 9 | кнопка SHOP (в лобби): следующий инкубатор и +25 мест за монеты (серая кнопка, если монет мало, звук Purchase); раздел Robux: пассы (OWNED, если куплен) и товары с ценой из Roblox, SOON при id 0 | DataController, ClientNet, Widgets, Incubation |
| Controllers/TutorialController | 7 | 5 подсказок сверху, шаги идут по действиям игрока (Ready, раунд, выбор яйца, вылупление, надеть питомца), SKIP; показывается, пока в профиле нет `Tutorial.Done` | DataController, ClientNet, Widgets |
| Controllers/PartyController | 6 | кнопка PARTY, `Toggle()` (открыть или закрыть окно): список игроков (друзья первыми) с INVITE, состав группы и LEAVE, всплывающее приглашение ACCEPT / DECLINE | ClientNet, Widgets |
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

- Каждая тема яйца даёт главный стат (таблица в `docs/pet-balance.md`). В предложении 4 яйца, тема каждого по `ThemeWeights`, редкость у каждого своя. Питомец той же редкости, что яйцо (если в яйце нет такой редкости — ближайшей), вид случайный внутри темы и редкости; питомец хранит свою редкость из конфига.
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

## Решения этапа 9 (уточнения к design.md)

- В design.md был один `MonetizationService`. Его пришлось разделить на два: `GamePassService` (внизу, только «у кого какой пасс») и `MonetizationService` (вверху, ProcessReceipt). Иначе EggService и RewardService, которым нужно знать про пассы, зависели бы от сервиса выше себя.
- Защита от двойной выдачи: id покупки записывается в `ProcessedPurchases` в том же изменении профиля, что и товар (`PlayerDataService:GrantPurchase`), а Roblox получает `PurchaseGranted` только после сохранения, где этот id уже есть. Повторный чек ничего не выдаёт.
- VIP «+1 инкубатор» сделан как один бесплатный инкубатор в пределах 6 мест на участке (места под 7-й нет). Цены остальных не сдвигаются. Если все 6 уже куплены, игрок получает цену последнего (15 000 монет).
- «Ускорить яйцо» за Robux заканчивает яйцо, которому осталось дольше всех. Если яиц нет, ускорение сохраняется и тратится на следующее нажатие «Hatch now».
- Пасс «Цвета краски» и золотой след VIP отложены: нужен твой выбор оттенков в Studio.
- Окно яиц показывает шансы до покупки реролла за Robux (правило Roblox о платных случайных наградах).

## Решения этапа 10 (оптимизация и исправления)

- По ревью кода этапа 2 и этапа 9:
  - StatsService подписывается на смену питомцев в `Init`, чтобы бонусы не терялись у профилей, загрузившихся раньше старта.
  - Ошибка у одного игрока больше не останавливает автовыбор яиц для всего сервера и не лишает наград остальных после раунда.
  - Инвентарь перестраивает карточки только когда меняются питомцы или надетые, а не при каждой смене монет.
  - Питомцы ушедшего игрока не возвращаются в мир; подписки снимаются.
  - Кнопки окна яиц разблокируются через 3 с, если сервер не ответил.
- Клавиши проседают и под ботами.
- Утечек по таблицам игроков не нашёл: у всех сервисов есть очистка на `PlayerRemoving` или в конце раунда.

## Карта (хаб и базы)

Карта взята из пака Ивана `world/source/StealMap6.rbxl` (2026-10-12): площадь в центре, 6 баз с двухэтажными зданиями, море с кораблями.

| Модуль | Этап | Публичный интерфейс | Зависит от |
|---|---|---|---|
| tools/pack/clean_rbxl.py | карта | `python3 tools/pack/clean_rbxl.py <пак.rbxl> <выход.rbxl>`: распаковывает zstd-чанки и убирает свойство `Tags`, чтобы Lune смог прочитать файл из Studio | zstandard (pip) |
| tools/build-world | карта | `lune run tools/build-world <очищенный пак>`: убирает скрипты и красные рынки, переносит центр площади в (0, 0), убирает море под ареной, NPC «UPGRADES» делает продавцом (`Shop` → подсказка `Shop`), ставит в каждое здание `PlotAnchor`, платформы `Platforms.PlatformN` на площадках пака (первый этаж 1–10, второй 11–20, атрибут `Index`, -Z к кнопке), зелёная площадка `Receive` перед каждой становится `PlatformButton` (атрибут `Platform`); `CFrame.lookAt` в Lune переворачивает часть направлений, поэтому кадры строятся вручную (`World.Islands.IslandN`, атрибуты `PlotIndex`, `SignHeight`) и портал в центр. Пишет `world/World.rbxm`, `world/materials/*.rbxm` (MaterialService); небо пака не берём, оно засвечивало картинку добела | Portal, ArenaConfig |
| tools/world/Portal | карта | `build(rbx, parent, cframe) -> Model Portal`: круглая сцена, кольцо-врата, светящийся диск (`Swirl` = PrimaryPart), части `Spin` (крутятся) и `Float` (кристаллы парят), надпись PLAY. Работает и в Lune, и в Studio | — |
| tools/build-arena | 1, карта | арена ставится в `ArenaConfig.CenterX/CenterZ` | ArenaConfig |
| Controllers/PortalController | карта | окно SOLO GAME / PARTY GAME у портала (`JoinQueue`), большой отсчёт «Match in N» в фазе Starting; анимация портала на клиенте (`Spin`, `Float`) | ClientNet, Widgets, ArenaConfig |
| Controllers/ShopController | 7, карта | + продавец SHOP у входа в базу (подсказка `Shop`) открывает то же окно магазина | — |
