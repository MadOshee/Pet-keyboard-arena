# Баланс питомцев

Дата: 2026-10-13. Цифры взяты из `src/shared/Config/PetConfig.luau` и `EggConfig.luau`. Таблицы ниже печатает `lune run tools/pet-balance`, поэтому после правки конфига их легко обновить. Деньги в игре показаны в долларах: $1000, $100/s, $100 000.

## Как это устроено

- В игре 21 яйцо и 168 питомцев из пака Pets & Eggs. Яйца идут от самого частого (Basic) к самому редкому (Sparkletime).
- В каждом яйце ровно 8 питомцев (решение Ивана): 2 Common, 2 Uncommon, 2 Rare, 1 Epic, 1 Legendary.
- В паке в яйцах было от 4 до 11 питомцев, поэтому лишних я переложил в близкие по теме яйца: Walrus, Moose и Eagle в Ice, Dark Dragon и Dark Phoenix в Dark, Cyber Comet в Cyborg, Parade Cube и Patriot Cuboid в Glitch, Chicken и Seaside Dogcat в Season 1, White Sparkletime в SpinToWin. Яйца Slime больше нет: его 4 питомца лежат в Royal. Rat, Bull и Inferno Cube в игру не вошли.
- После раунда игрок выбирает 1 из 4 яиц. У каждого яйца своя тема (какое это яйцо) и своя редкость.
- Тема решает, каких питомцев можно получить, сколько денег они приносят и какой у них главный бафф. Шанс каждой темы в слоте задан в `EggConfig` (в сумме 100%): 13 яиц от 11% (Basic) до 5,1% (Underworld) и 8 супер редких меньше 5% (Dark 2,4% … Sparkletime 0,25%), они подсвечены оранжевым. Время вылупления зависит от темы: Basic 30 с, Forest 1 мин и дальше дольше, до 2 ч у Sparkletime (Ivan, 2026-10-13).
- Редкость яйца решает, питомец какой редкости вылупится; из двух питомцев одной редкости выпадает любой.
- Доход в секунду = доход редкости × множитель яйца, округлённый до целого. Доход редкости: Common $5, Uncommon $15, Rare $50, Epic $200, Legendary $1000 (13 октября Иван попросил поднять доход, все цифры стали в 5 раз больше).
- Питомец на платформе базы приносит деньги каждую секунду, даже когда игрок не в игре. Оффлайн считается не больше 24 часов.
- Экипированный питомец (до 3 штук) даёт баффы. Один и тот же питомец не может одновременно стоять на платформе и быть экипирован.

## Баффы

| Бафф | Цвет | Что даёт |
|---|---|---|
| Speed | жёлтый | Скорость бега в раунде |
| Power | красный | Сила удара битой: соперник отлетает дальше |
| Area | голубой | Размер кисти: сколько клавиш красится вокруг игрока |
| Luck | зелёный | Шанс на более редкие яйца после раунда |
| Money | зелёный | Больше денег за раунд |

- У питомца не больше 3 баффов: у Legendary 3, у Epic 2, у остальных 1.
- Первый бафф всегда главный бафф яйца. Второй и третий равны половине главного значения той же редкости, с округлением вверх до целого процента.
- Каждое следующее яйцо даёт баффы на 5% сильнее предыдущего: у Sparkletime они в 2 раза больше, чем у Basic.

## Яйца

| Яйцо | Шанс в слоте | Главный бафф | Множитель дохода |
|---|---|---|---|
| Basic | 25.06% | Money | ×1 |
| Forest | 18.79% | Speed | ×1.2 |
| Surfing | 14.1% | Speed | ×1.6 |
| Arctic | 10.57% | Area | ×1.9 |
| Ice | 7.93% | Power | ×2.2 |
| Volcanic | 5.95% | Luck | ×2.6 |
| Infernal | 4.46% | Power | ×3 |
| Dragon | 3.35% | Power | ×3.5 |
| Holographic | 2.51% | Luck | ×4 |
| Space | 1.88% | Speed | ×5 |
| Cyborg | 1.41% | Power | ×6 |
| Nebula | 1.06% | Luck | ×7 |
| Underworld | 0.79% | Area | ×8 |
| Dark | 0.6% | Power | ×9.5 |
| Glitched | 0.45% | Money | ×11 |
| Glitch | 0.34% | Luck | ×13 |
| Patriotic | 0.25% | Speed | ×15 |
| Season 1 | 0.19% | Money | ×17.5 |
| SpinToWin | 0.14% | Luck | ×20 |
| Royal | 0.11% | Money | ×25 |
| Sparkletime | 0.08% | Luck | ×30 |

«Шанс в слоте» означает, как часто это яйцо выпадает в одном из 4 слотов выбора. Sparkletime выпадает примерно в 1 слоте из 1 250.

## Редкость яйца

| Редкость | Поражение | Победа и лучший вклад |
|---|---|---|
| Common | 50% | 29.17% |
| Uncommon | 28% | 26.95% |
| Rare | 15% | 23.83% |
| Epic | 6% | 15.72% |
| Legendary | 1% | 4.32% |

Победа, большой вклад в покраску и бафф Luck сдвигают шансы к редким яйцам.

## Все питомцы

| Яйцо | Питомец | Редкость | Доход на платформе | Баффы при экипировке | Шанс за одно яйцо (поражение) |
|---|---|---|---|---|---|
| Basic | Doggy | Common | $5/s | +5% Money | 6.26% |
| Basic | Kitty | Common | $5/s | +5% Money | 6.26% |
| Basic | Bunny | Uncommon | $15/s | +8% Money | 3.51% |
| Basic | Piggy | Uncommon | $15/s | +8% Money | 3.51% |
| Basic | Ducky | Rare | $50/s | +12% Money | 1.88% |
| Basic | Bear | Rare | $50/s | +12% Money | 1.88% |
| Basic | Fox | Epic | $200/s | +4% Speed, +20% Money | 1.5% |
| Basic | Cow | Legendary | $1000/s | +6% Speed, +15% Luck, +30% Money | 0.25% |
| Forest | Squirrel | Common | $6/s | +2% Speed | 4.7% |
| Forest | Deer | Common | $6/s | +2% Speed | 4.7% |
| Forest | Owl | Uncommon | $18/s | +3% Speed | 2.63% |
| Forest | Panda | Uncommon | $18/s | +3% Speed | 2.63% |
| Forest | Lynx | Rare | $60/s | +5% Speed | 1.41% |
| Forest | Elephant | Rare | $60/s | +5% Speed | 1.41% |
| Forest | Tiger | Epic | $240/s | +8% Speed, +7% Area | 1.13% |
| Forest | Lion | Legendary | $1200/s | +13% Speed, +10% Area, +16% Money | 0.19% |
| Surfing | Floaty Ducky | Common | $8/s | +2% Speed | 3.52% |
| Surfing | Surfing Doggy | Common | $8/s | +2% Speed | 3.52% |
| Surfing | Surfing Kitty | Uncommon | $24/s | +3% Speed | 1.97% |
| Surfing | Shark | Uncommon | $24/s | +3% Speed | 1.97% |
| Surfing | Beach Boi | Rare | $80/s | +6% Speed | 1.06% |
| Surfing | Bucket O' Shells | Rare | $80/s | +6% Speed | 1.06% |
| Surfing | Seaweed Monster | Epic | $320/s | +9% Speed, +11% Money | 0.85% |
| Surfing | Tidal God | Legendary | $1600/s | +13% Speed, +10% Area, +17% Money | 0.14% |
| Arctic | Penguin | Common | $10/s | +3% Area | 2.64% |
| Arctic | Snow Squirrel | Common | $10/s | +3% Area | 2.64% |
| Arctic | Arctic Fox | Uncommon | $29/s | +6% Area | 1.48% |
| Arctic | Polar Bear | Uncommon | $29/s | +6% Area | 1.48% |
| Arctic | Mammoth | Rare | $95/s | +9% Area | 0.79% |
| Arctic | Snow Tiger | Rare | $95/s | +9% Area | 0.79% |
| Arctic | King Penguin | Epic | $380/s | +9% Power, +14% Area | 0.63% |
| Arctic | Frost Defender | Legendary | $1900/s | +7% Speed, +15% Power, +21% Area | 0.11% |
| Ice | Ice Doggy | Common | $11/s | +5% Power | 1.98% |
| Ice | Ice Kitty | Common | $11/s | +5% Power | 1.98% |
| Ice | Walrus | Uncommon | $33/s | +7% Power | 1.11% |
| Ice | Moose | Uncommon | $33/s | +7% Power | 1.11% |
| Ice | Eagle | Rare | $110/s | +12% Power | 0.59% |
| Ice | Ice Golem | Rare | $110/s | +12% Power | 0.59% |
| Ice | Frost Wisp | Epic | $440/s | +18% Power, +7% Area | 0.48% |
| Ice | Frigidus | Legendary | $2200/s | +7% Speed, +30% Power, +11% Area | 0.08% |
| Volcanic | Volcanic Doggy | Common | $13/s | +6% Luck | 1.49% |
| Volcanic | Volcanic Kitty | Common | $13/s | +6% Luck | 1.49% |
| Volcanic | Molten Piggy | Uncommon | $39/s | +10% Luck | 0.83% |
| Volcanic | Volcanic Golem | Uncommon | $39/s | +10% Luck | 0.83% |
| Volcanic | Molten Cow | Rare | $130/s | +15% Luck | 0.45% |
| Volcanic | Fire Panda | Rare | $130/s | +15% Luck | 0.45% |
| Volcanic | Inferno Dragon | Epic | $520/s | +10% Power, +25% Luck | 0.36% |
| Volcanic | Blazing Phoenix | Legendary | $2600/s | +16% Power, +38% Luck, +19% Money | 0.06% |
| Infernal | Imp | Common | $15/s | +5% Power | 1.12% |
| Infernal | Hell Bat | Common | $15/s | +5% Power | 1.12% |
| Infernal | Inferno Mimic | Uncommon | $45/s | +8% Power | 0.62% |
| Infernal | Flame Wisp | Uncommon | $45/s | +8% Power | 0.62% |
| Infernal | Infernus | Rare | $150/s | +13% Power | 0.33% |
| Infernal | Infernal Revenant | Rare | $150/s | +13% Power | 0.33% |
| Infernal | Cerberus | Epic | $600/s | +20% Power, +13% Luck | 0.27% |
| Infernal | Blazing Guardian | Legendary | $3000/s | +8% Speed, +33% Power, +20% Luck | 0.04% |
| Dragon | Dragon | Common | $18/s | +5% Power | 0.84% |
| Dragon | Bone Dragon | Common | $18/s | +5% Power | 0.84% |
| Dragon | Ruby Dragon | Uncommon | $53/s | +8% Power | 0.47% |
| Dragon | Rex | Uncommon | $53/s | +8% Power | 0.47% |
| Dragon | Phoenix | Rare | $175/s | +14% Power | 0.25% |
| Dragon | Hydra | Rare | $175/s | +14% Power | 0.25% |
| Dragon | Kitsune | Epic | $700/s | +20% Power, +14% Money | 0.2% |
| Dragon | King Hydra | Legendary | $3500/s | +34% Power, +21% Luck, +21% Money | 0.03% |
| Holographic | Holo Doggy | Common | $20/s | +7% Luck | 0.63% |
| Holographic | Holo Kitty | Common | $20/s | +7% Luck | 0.63% |
| Holographic | Holo Butterfly | Uncommon | $60/s | +11% Luck | 0.35% |
| Holographic | Holo Dino | Uncommon | $60/s | +11% Luck | 0.35% |
| Holographic | Rainbow Shock | Rare | $200/s | +17% Luck | 0.19% |
| Holographic | Chroma Wisp | Rare | $200/s | +17% Luck | 0.19% |
| Holographic | Holocorn | Epic | $800/s | +9% Area, +28% Luck | 0.15% |
| Holographic | Prisma | Legendary | $4000/s | +13% Area, +42% Luck, +21% Money | 0.03% |
| Space | Space Snail | Common | $25/s | +3% Speed | 0.47% |
| Space | Space Mouse | Common | $25/s | +3% Speed | 0.47% |
| Space | Space Doggy | Uncommon | $75/s | +4% Speed | 0.26% |
| Space | Space Kitty | Uncommon | $75/s | +4% Speed | 0.26% |
| Space | Astronaut | Rare | $250/s | +7% Speed | 0.14% |
| Space | Alien | Rare | $250/s | +7% Speed | 0.14% |
| Space | Cool Sun | Epic | $1000/s | +12% Speed, +15% Luck | 0.11% |
| Space | Planetarium | Legendary | $5000/s | +17% Speed, +18% Power, +22% Luck | 0.02% |
| Cyborg | Cyborg Doggy | Common | $30/s | +6% Power | 0.35% |
| Cyborg | Cyborg Owl | Common | $30/s | +6% Power | 0.35% |
| Cyborg | Cyborg Deer | Uncommon | $90/s | +9% Power | 0.2% |
| Cyborg | Cyborg Racoon | Uncommon | $90/s | +9% Power | 0.2% |
| Cyborg | Cyber Comet | Rare | $300/s | +15% Power | 0.11% |
| Cyborg | Omega One | Rare | $300/s | +15% Power | 0.11% |
| Cyborg | Robotic Leviathan | Epic | $1200/s | +6% Speed, +22% Power | 0.08% |
| Cyborg | Giant Robot | Legendary | $6000/s | +9% Speed, +38% Power, +14% Area | 0.01% |
| Nebula | Nebula Bunny | Common | $35/s | +8% Luck | 0.26% |
| Nebula | Nebula Bear | Common | $35/s | +8% Luck | 0.26% |
| Nebula | Nebula Golem | Uncommon | $105/s | +12% Luck | 0.15% |
| Nebula | Hexarium | Uncommon | $105/s | +12% Luck | 0.15% |
| Nebula | Luminous | Rare | $350/s | +19% Luck | 0.08% |
| Nebula | Nebular Demon | Rare | $350/s | +19% Luck | 0.08% |
| Nebula | Astra | Epic | $1400/s | +6% Speed, +31% Luck | 0.06% |
| Nebula | Astra Hydra | Legendary | $7000/s | +10% Speed, +47% Luck, +24% Money | 0.01% |
| Underworld | Bat | Common | $40/s | +5% Area | 0.2% |
| Underworld | Ghost | Common | $40/s | +5% Area | 0.2% |
| Underworld | Crawler | Uncommon | $120/s | +8% Area | 0.11% |
| Underworld | Punk Bat | Uncommon | $120/s | +8% Area | 0.11% |
| Underworld | Werewolf | Rare | $400/s | +13% Area | 0.06% |
| Underworld | Crimson Eye | Rare | $400/s | +13% Area | 0.06% |
| Underworld | Phantom | Epic | $1600/s | +12% Power, +19% Area | 0.05% |
| Underworld | Messor | Legendary | $8000/s | +20% Power, +29% Area, +24% Luck | 0.0079% |
| Dark | Sapphire Demon | Common | $48/s | +7% Power | 0.15% |
| Dark | Vesp | Common | $48/s | +7% Power | 0.15% |
| Dark | Dark Dragon | Uncommon | $143/s | +10% Power | 0.08% |
| Dark | Dark Berserker | Uncommon | $143/s | +10% Power | 0.08% |
| Dark | Dark Phoenix | Rare | $475/s | +17% Power | 0.04% |
| Dark | Neon Abyss | Rare | $475/s | +17% Power | 0.04% |
| Dark | Dark Defender | Epic | $1900/s | +25% Power, +17% Luck | 0.04% |
| Dark | The Overseer | Legendary | $9500/s | +41% Power, +25% Luck, +25% Money | 0.006% |
| Glitched | Bruh | Common | $55/s | +9% Money | 0.11% |
| Glitched | Coder Pet | Common | $55/s | +9% Money | 0.11% |
| Glitched | Glitched Cube | Uncommon | $165/s | +14% Money | 0.06% |
| Glitched | Glitched Doggy | Uncommon | $165/s | +14% Money | 0.06% |
| Glitched | Glitched Bunny | Rare | $550/s | +20% Money | 0.03% |
| Glitched | Glitched Fox | Rare | $550/s | +20% Money | 0.03% |
| Glitched | Glitched Crawler | Epic | $2200/s | +17% Luck, +34% Money | 0.03% |
| Glitched | Missing 404 | Legendary | $11 000/s | +22% Power, +26% Luck, +51% Money | 0.0045% |
| Glitch | Virus Cube | Common | $65/s | +9% Luck | 0.08% |
| Glitch | Tetra Cube | Common | $65/s | +9% Luck | 0.08% |
| Glitch | Parade Cube | Uncommon | $195/s | +14% Luck | 0.05% |
| Glitch | Patriot Cuboid | Uncommon | $195/s | +14% Luck | 0.05% |
| Glitch | Glitch | Rare | $650/s | +21% Luck | 0.03% |
| Glitch | Fracture | Rare | $650/s | +21% Luck | 0.03% |
| Glitch | Virus CORE | Epic | $2600/s | +35% Luck, +18% Money | 0.02% |
| Glitch | CORE | Legendary | $13 000/s | +11% Speed, +53% Luck, +27% Money | 0.0034% |
| Patriotic | Patriotic Doggy | Common | $75/s | +4% Speed | 0.06% |
| Patriotic | Patriotic Shock | Common | $75/s | +4% Speed | 0.06% |
| Patriotic | Patriotic Star | Uncommon | $225/s | +5% Speed | 0.04% |
| Patriotic | Patriotic Robot | Uncommon | $225/s | +5% Speed | 0.04% |
| Patriotic | Patriotic Mimic | Rare | $750/s | +9% Speed | 0.02% |
| Patriotic | Patriot Dragon | Rare | $750/s | +9% Speed | 0.02% |
| Patriotic | Patrius | Epic | $3000/s | +14% Speed, +14% Power | 0.02% |
| Patriotic | Liberty | Legendary | $15 000/s | +22% Speed, +23% Power, +27% Money | 0.0025% |
| Season 1 | Mimic | Common | $88/s | +9% Money | 0.05% |
| Season 1 | Chicken | Common | $88/s | +9% Money | 0.05% |
| Season 1 | Sunny Bunny | Uncommon | $263/s | +15% Money | 0.03% |
| Season 1 | Sunny Bear | Uncommon | $263/s | +15% Money | 0.03% |
| Season 1 | Seaside Dogcat | Rare | $875/s | +22% Money | 0.01% |
| Season 1 | Dogcat | Rare | $875/s | +22% Money | 0.01% |
| Season 1 | Unicorn | Epic | $3500/s | +8% Speed, +37% Money | 0.01% |
| Season 1 | Delightful Trio | Legendary | $17 500/s | +11% Speed, +17% Area, +56% Money | 0.0019% |
| SpinToWin | Crystal Doggy | Common | $100/s | +10% Luck | 0.04% |
| SpinToWin | Crystal Kitty | Common | $100/s | +10% Luck | 0.04% |
| SpinToWin | Crystal Bat | Uncommon | $300/s | +15% Luck | 0.02% |
| SpinToWin | Crystal Butterfly | Uncommon | $300/s | +15% Luck | 0.02% |
| SpinToWin | White Sparkletime | Rare | $1000/s | +23% Luck | 0.01% |
| SpinToWin | Crystal Cuboid | Rare | $1000/s | +23% Luck | 0.01% |
| SpinToWin | Amethyst Golem | Epic | $4000/s | +38% Luck, +19% Money | 0.0084% |
| SpinToWin | Brilliant Gem | Legendary | $20 000/s | +17% Area, +57% Luck, +29% Money | 0.0014% |
| Royal | Slime Cube | Common | $125/s | +10% Money | 0.03% |
| Royal | Slime Doggy | Common | $125/s | +10% Money | 0.03% |
| Royal | Slime Kitty | Uncommon | $375/s | +16% Money | 0.01% |
| Royal | Slime Bat | Uncommon | $375/s | +16% Money | 0.01% |
| Royal | Royal Heart | Rare | $1250/s | +23% Money | 0.0079% |
| Royal | Aureus | Rare | $1250/s | +23% Money | 0.0079% |
| Royal | Empyreus | Epic | $5000/s | +20% Luck, +39% Money | 0.0063% |
| Royal | Queen Kitty | Legendary | $25 000/s | +25% Power, +30% Luck, +59% Money | 0.0011% |
| Sparkletime | Red Sparkletime | Common | $150/s | +10% Luck | 0.02% |
| Sparkletime | Pink Sparkletime | Common | $150/s | +10% Luck | 0.02% |
| Sparkletime | Purple Sparkletime | Uncommon | $450/s | +16% Luck | 0.01% |
| Sparkletime | Blue Sparkletime | Uncommon | $450/s | +16% Luck | 0.01% |
| Sparkletime | Cyan Sparkletime | Rare | $1500/s | +24% Luck | 0.006% |
| Sparkletime | Green Sparkletime | Rare | $1500/s | +24% Luck | 0.006% |
| Sparkletime | Black Sparkletime | Epic | $6000/s | +40% Luck, +20% Money | 0.0048% |
| Sparkletime | Gold Sparkletime | Legendary | $30 000/s | +12% Speed, +60% Luck, +30% Money | 0.0008% |

«Шанс за одно яйцо» посчитан для худшего случая: поражение без Luck. После победы с лучшим вкладом легендарные выпадают примерно в 4 раза чаще. Самый редкий питомец, Gold Sparkletime, приносит $30 000/s и выпадает примерно в 1 яйце из 125 000.

## Сила баффов и потолки

Значения для первого яйца (Basic); у каждого следующего яйца они на 5% больше.

| Бафф | Common | Uncommon | Rare | Epic | Legendary | Потолок (3 питомца) |
|---|---|---|---|---|---|---|
| Speed | +2% | +3% | +5% | +8% | +12% | +25% |
| Power | +4% | +6% | +10% | +15% | +25% | +60% |
| Area | +3% | +5% | +8% | +12% | +18% | +50% |
| Luck | +5% | +8% | +12% | +20% | +30% | +100% |
| Money | +5% | +8% | +12% | +20% | +30% | +100% |

Потолок ограничивает сумму баффов трёх экипированных питомцев. Так ветераны не становятся непобедимыми в раунде.
