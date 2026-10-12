# Баланс питомцев

Дата: 2026-10-12. Цифры взяты из `src/shared/Config/PetConfig.luau` и `EggConfig.luau`. Таблицы ниже печатает `lune run tools/pet-balance`, поэтому после правки конфига их легко обновить.

## Как это устроено

- В игре все 22 яйца и 171 питомец из пака Pets & Eggs. Яйца идут от самого частого (Basic) к самому редкому (Sparkletime).
- После раунда игрок выбирает 1 из 4 яиц. У каждого яйца своя тема (какое это яйцо) и своя редкость.
- Тема решает, каких питомцев можно получить, сколько они приносят монет и какой у них главный бафф. Каждое следующее яйцо выпадает в 0.75 раза реже предыдущего.
- Редкость яйца решает, какой питомец из этого яйца вылупится. В каждом яйце питомцы идут от слабого к лучшему: лучший Legendary, следующий Epic, примерно пятая часть Rare, четверть Uncommon, остальные Common. В маленьких яйцах (4 питомца) Common нет: такое яйцо даёт ближайшую редкость.
- Доход в секунду = доход редкости × множитель яйца, округлённый до целого. Доход редкости: Common 1, Uncommon 3, Rare 10, Epic 40, Legendary 200.
- Питомец на платформе базы приносит монеты каждую секунду, даже когда игрок не в игре. Оффлайн считается не больше 24 часов.
- Экипированный питомец (до 3 штук) даёт баффы. Один и тот же питомец не может одновременно стоять на платформе и быть экипирован.

## Баффы

| Бафф | Цвет | Что даёт |
|---|---|---|
| Speed | жёлтый | Скорость бега в раунде |
| Power | красный | Сила удара битой: соперник отлетает дальше |
| Area | голубой | Размер кисти: сколько клавиш красится вокруг игрока |
| Luck | зелёный | Шанс на более редкие яйца после раунда |
| Money | зелёный | Больше монет за раунд |

- У питомца не больше 3 баффов. У лучшего питомца яйца 3 баффа, у следующего 2, у остальных 1.
- Первый бафф всегда главный бафф яйца. Второй и третий равны половине главного значения той же редкости, с округлением вверх до целого процента.
- Каждое следующее яйцо даёт баффы на 5% сильнее предыдущего: у Sparkletime они в 2.05 раза больше, чем у Basic.

## Яйца

| Яйцо | Шанс в слоте | Главный бафф | Множитель дохода |
|---|---|---|---|
| Basic | 25.04% | Money | ×1 |
| Forest | 18.78% | Speed | ×1.2 |
| Slime | 14.09% | Area | ×1.4 |
| Surfing | 10.57% | Speed | ×1.6 |
| Arctic | 7.92% | Area | ×1.9 |
| Ice | 5.94% | Power | ×2.2 |
| Volcanic | 4.46% | Luck | ×2.6 |
| Infernal | 3.34% | Power | ×3 |
| Dragon | 2.51% | Power | ×3.5 |
| Holographic | 1.88% | Luck | ×4 |
| Space | 1.41% | Speed | ×5 |
| Cyborg | 1.06% | Power | ×6 |
| Nebula | 0.79% | Luck | ×7 |
| Underworld | 0.6% | Area | ×8 |
| Dark | 0.45% | Power | ×9.5 |
| Glitched | 0.34% | Money | ×11 |
| Glitch | 0.25% | Luck | ×13 |
| Patriotic | 0.19% | Speed | ×15 |
| Season 1 | 0.14% | Money | ×17.5 |
| SpinToWin | 0.11% | Luck | ×20 |
| Royal | 0.08% | Money | ×25 |
| Sparkletime | 0.06% | Luck | ×30 |

«Шанс в слоте» означает, как часто это яйцо выпадает в одном из 4 слотов выбора. Sparkletime выпадает примерно в 1 слоте из 1 700.

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

| Яйцо | Питомец | Редкость | Доход на платформе, монет/с | Баффы при экипировке | Шанс за одно яйцо (поражение) |
|---|---|---|---|---|---|
| Basic | Doggy | Common | 1 | +5% Money | 4.17% |
| Basic | Kitty | Common | 1 | +5% Money | 4.17% |
| Basic | Bunny | Common | 1 | +5% Money | 4.17% |
| Basic | Piggy | Uncommon | 3 | +8% Money | 2.34% |
| Basic | Chicken | Uncommon | 3 | +8% Money | 2.34% |
| Basic | Ducky | Uncommon | 3 | +8% Money | 2.34% |
| Basic | Rat | Rare | 10 | +12% Money | 1.88% |
| Basic | Bear | Rare | 10 | +12% Money | 1.88% |
| Basic | Fox | Epic | 40 | +4% Speed, +20% Money | 1.5% |
| Basic | Cow | Legendary | 200 | +6% Speed, +15% Luck, +30% Money | 0.25% |
| Forest | Squirrel | Common | 1 | +2% Speed | 2.35% |
| Forest | Deer | Common | 1 | +2% Speed | 2.35% |
| Forest | Owl | Common | 1 | +2% Speed | 2.35% |
| Forest | Moose | Common | 1 | +2% Speed | 2.35% |
| Forest | Panda | Uncommon | 4 | +3% Speed | 1.75% |
| Forest | Lynx | Uncommon | 4 | +3% Speed | 1.75% |
| Forest | Eagle | Uncommon | 4 | +3% Speed | 1.75% |
| Forest | Bull | Rare | 12 | +5% Speed | 1.41% |
| Forest | Elephant | Rare | 12 | +5% Speed | 1.41% |
| Forest | Tiger | Epic | 48 | +8% Speed, +7% Area | 1.13% |
| Forest | Lion | Legendary | 240 | +13% Speed, +10% Area, +16% Money | 0.19% |
| Slime | Slime Cube | Uncommon | 4 | +6% Area | 10.99% |
| Slime | Slime Doggy | Rare | 14 | +9% Area | 2.11% |
| Slime | Slime Kitty | Epic | 56 | +5% Speed, +13% Area | 0.85% |
| Slime | Slime Bat | Legendary | 280 | +7% Speed, +20% Area, +17% Luck | 0.14% |
| Surfing | Floaty Ducky | Common | 2 | +2% Speed | 1.76% |
| Surfing | Surfing Doggy | Common | 2 | +2% Speed | 1.76% |
| Surfing | Surfing Kitty | Common | 2 | +2% Speed | 1.76% |
| Surfing | Shark | Uncommon | 5 | +3% Speed | 1.48% |
| Surfing | Beach Boi | Uncommon | 5 | +3% Speed | 1.48% |
| Surfing | Bucket O' Shells | Rare | 16 | +6% Speed | 0.79% |
| Surfing | Seaweed Monster | Rare | 16 | +6% Speed | 0.79% |
| Surfing | Seaside Dogcat | Epic | 64 | +9% Speed, +12% Money | 0.63% |
| Surfing | Tidal God | Legendary | 320 | +14% Speed, +11% Area, +18% Money | 0.11% |
| Arctic | Penguin | Common | 2 | +4% Area | 1.32% |
| Arctic | Snow Squirrel | Common | 2 | +4% Area | 1.32% |
| Arctic | Walrus | Common | 2 | +4% Area | 1.32% |
| Arctic | Arctic Fox | Uncommon | 6 | +6% Area | 1.11% |
| Arctic | Polar Bear | Uncommon | 6 | +6% Area | 1.11% |
| Arctic | Mammoth | Rare | 19 | +10% Area | 0.59% |
| Arctic | Snow Tiger | Rare | 19 | +10% Area | 0.59% |
| Arctic | King Penguin | Epic | 76 | +9% Power, +14% Area | 0.48% |
| Arctic | Frost Defender | Legendary | 380 | +7% Speed, +15% Power, +22% Area | 0.08% |
| Ice | Ice Doggy | Common | 2 | +5% Power | 2.97% |
| Ice | Ice Kitty | Uncommon | 7 | +8% Power | 1.66% |
| Ice | Ice Golem | Rare | 22 | +13% Power | 0.89% |
| Ice | Frost Wisp | Epic | 88 | +19% Power, +8% Area | 0.36% |
| Ice | Frigidus | Legendary | 440 | +8% Speed, +31% Power, +11% Area | 0.06% |
| Volcanic | Volcanic Doggy | Common | 3 | +7% Luck | 0.74% |
| Volcanic | Volcanic Kitty | Common | 3 | +7% Luck | 0.74% |
| Volcanic | Inferno Cube | Common | 3 | +7% Luck | 0.74% |
| Volcanic | Molten Piggy | Uncommon | 8 | +10% Luck | 0.62% |
| Volcanic | Volcanic Golem | Uncommon | 8 | +10% Luck | 0.62% |
| Volcanic | Molten Cow | Rare | 26 | +16% Luck | 0.33% |
| Volcanic | Fire Panda | Rare | 26 | +16% Luck | 0.33% |
| Volcanic | Inferno Dragon | Epic | 104 | +10% Power, +26% Luck | 0.27% |
| Volcanic | Blazing Phoenix | Legendary | 520 | +17% Power, +39% Luck, +20% Money | 0.04% |
| Infernal | Imp | Common | 3 | +5% Power | 0.84% |
| Infernal | Hell Bat | Common | 3 | +5% Power | 0.84% |
| Infernal | Inferno Mimic | Uncommon | 9 | +8% Power | 0.47% |
| Infernal | Flame Wisp | Uncommon | 9 | +8% Power | 0.47% |
| Infernal | Infernus | Rare | 30 | +14% Power | 0.25% |
| Infernal | Infernal Revenant | Rare | 30 | +14% Power | 0.25% |
| Infernal | Cerberus | Epic | 120 | +20% Power, +14% Luck | 0.2% |
| Infernal | Blazing Guardian | Legendary | 600 | +8% Speed, +34% Power, +21% Luck | 0.03% |
| Dragon | Dragon | Common | 4 | +6% Power | 0.42% |
| Dragon | Bone Dragon | Common | 4 | +6% Power | 0.42% |
| Dragon | Ruby Dragon | Common | 4 | +6% Power | 0.42% |
| Dragon | Dark Dragon | Uncommon | 11 | +8% Power | 0.23% |
| Dragon | Rex | Uncommon | 11 | +8% Power | 0.23% |
| Dragon | Phoenix | Uncommon | 11 | +8% Power | 0.23% |
| Dragon | Dark Phoenix | Rare | 35 | +14% Power | 0.19% |
| Dragon | Hydra | Rare | 35 | +14% Power | 0.19% |
| Dragon | Kitsune | Epic | 140 | +21% Power, +14% Money | 0.15% |
| Dragon | King Hydra | Legendary | 700 | +35% Power, +21% Luck, +21% Money | 0.03% |
| Holographic | Holo Doggy | Common | 4 | +7% Luck | 0.47% |
| Holographic | Holo Kitty | Common | 4 | +7% Luck | 0.47% |
| Holographic | Holo Butterfly | Uncommon | 12 | +12% Luck | 0.26% |
| Holographic | Holo Dino | Uncommon | 12 | +12% Luck | 0.26% |
| Holographic | Rainbow Shock | Rare | 40 | +17% Luck | 0.14% |
| Holographic | Chroma Wisp | Rare | 40 | +17% Luck | 0.14% |
| Holographic | Holocorn | Epic | 160 | +9% Area, +29% Luck | 0.11% |
| Holographic | Prisma | Legendary | 800 | +13% Area, +44% Luck, +22% Money | 0.02% |
| Space | Space Snail | Common | 5 | +3% Speed | 0.24% |
| Space | Space Mouse | Common | 5 | +3% Speed | 0.24% |
| Space | Space Doggy | Common | 5 | +3% Speed | 0.24% |
| Space | Space Kitty | Uncommon | 15 | +5% Speed | 0.2% |
| Space | Astronaut | Uncommon | 15 | +5% Speed | 0.2% |
| Space | Alien | Rare | 50 | +8% Speed | 0.11% |
| Space | Cool Sun | Rare | 50 | +8% Speed | 0.11% |
| Space | Cyber Comet | Epic | 200 | +12% Speed, +15% Luck | 0.08% |
| Space | Planetarium | Legendary | 1 000 | +18% Speed, +19% Power, +23% Luck | 0.01% |
| Cyborg | Cyborg Doggy | Common | 6 | +6% Power | 0.26% |
| Cyborg | Cyborg Owl | Common | 6 | +6% Power | 0.26% |
| Cyborg | Cyborg Deer | Uncommon | 18 | +9% Power | 0.15% |
| Cyborg | Cyborg Racoon | Uncommon | 18 | +9% Power | 0.15% |
| Cyborg | Omega One | Rare | 60 | +16% Power | 0.16% |
| Cyborg | Robotic Leviathan | Epic | 240 | +6% Speed, +23% Power | 0.06% |
| Cyborg | Giant Robot | Legendary | 1 200 | +10% Speed, +39% Power, +14% Area | 0.01% |
| Nebula | Nebula Bunny | Common | 7 | +8% Luck | 0.2% |
| Nebula | Nebula Bear | Common | 7 | +8% Luck | 0.2% |
| Nebula | Nebula Golem | Uncommon | 21 | +13% Luck | 0.11% |
| Nebula | Hexarium | Uncommon | 21 | +13% Luck | 0.11% |
| Nebula | Luminous | Rare | 70 | +19% Luck | 0.06% |
| Nebula | Nebular Demon | Rare | 70 | +19% Luck | 0.06% |
| Nebula | Astra | Epic | 280 | +7% Speed, +32% Luck | 0.05% |
| Nebula | Astra Hydra | Legendary | 1 400 | +10% Speed, +48% Luck, +24% Money | 0.0079% |
| Underworld | Bat | Common | 8 | +5% Area | 0.15% |
| Underworld | Ghost | Common | 8 | +5% Area | 0.15% |
| Underworld | Crawler | Uncommon | 24 | +8% Area | 0.08% |
| Underworld | Punk Bat | Uncommon | 24 | +8% Area | 0.08% |
| Underworld | Werewolf | Rare | 80 | +13% Area | 0.04% |
| Underworld | Crimson Eye | Rare | 80 | +13% Area | 0.04% |
| Underworld | Phantom | Epic | 320 | +13% Power, +20% Area | 0.04% |
| Underworld | Messor | Legendary | 1 600 | +21% Power, +30% Area, +25% Luck | 0.006% |
| Dark | Sapphire Demon | Common | 10 | +7% Power | 0.22% |
| Dark | Vesp | Uncommon | 29 | +10% Power | 0.06% |
| Dark | Dark Berserker | Uncommon | 29 | +10% Power | 0.06% |
| Dark | Neon Abyss | Rare | 95 | +17% Power | 0.07% |
| Dark | Dark Defender | Epic | 380 | +26% Power, +17% Luck | 0.03% |
| Dark | The Overseer | Legendary | 1 900 | +43% Power, +26% Luck, +26% Money | 0.0045% |
| Glitched | Bruh | Common | 11 | +9% Money | 0.08% |
| Glitched | Coder Pet | Common | 11 | +9% Money | 0.08% |
| Glitched | Glitched Cube | Uncommon | 33 | +14% Money | 0.05% |
| Glitched | Glitched Doggy | Uncommon | 33 | +14% Money | 0.05% |
| Glitched | Glitched Bunny | Rare | 110 | +21% Money | 0.03% |
| Glitched | Glitched Fox | Rare | 110 | +21% Money | 0.03% |
| Glitched | Glitched Crawler | Epic | 440 | +18% Luck, +35% Money | 0.02% |
| Glitched | Missing 404 | Legendary | 2 200 | +22% Power, +27% Luck, +53% Money | 0.0034% |
| Glitch | Virus Cube | Common | 13 | +9% Luck | 0.13% |
| Glitch | Tetra Cube | Uncommon | 39 | +14% Luck | 0.04% |
| Glitch | Glitch | Uncommon | 39 | +14% Luck | 0.04% |
| Glitch | Fracture | Rare | 130 | +22% Luck | 0.04% |
| Glitch | Virus CORE | Epic | 520 | +36% Luck, +18% Money | 0.02% |
| Glitch | CORE | Legendary | 2 600 | +11% Speed, +54% Luck, +27% Money | 0.0025% |
| Patriotic | Patriotic Doggy | Common | 15 | +4% Speed | 0.03% |
| Patriotic | Patriotic Shock | Common | 15 | +4% Speed | 0.03% |
| Patriotic | Parade Cube | Common | 15 | +4% Speed | 0.03% |
| Patriotic | Patriot Cuboid | Uncommon | 45 | +6% Speed | 0.02% |
| Patriotic | Patriotic Star | Uncommon | 45 | +6% Speed | 0.02% |
| Patriotic | Patriotic Robot | Uncommon | 45 | +6% Speed | 0.02% |
| Patriotic | Patriotic Mimic | Rare | 150 | +9% Speed | 0.01% |
| Patriotic | Patriot Dragon | Rare | 150 | +9% Speed | 0.01% |
| Patriotic | Patrius | Epic | 600 | +15% Speed, +14% Power | 0.01% |
| Patriotic | Liberty | Legendary | 3 000 | +22% Speed, +23% Power, +28% Money | 0.0019% |
| Season 1 | Mimic | Common | 18 | +10% Money | 0.07% |
| Season 1 | Sunny Bunny | Uncommon | 53 | +15% Money | 0.02% |
| Season 1 | Sunny Bear | Uncommon | 53 | +15% Money | 0.02% |
| Season 1 | Dogcat | Rare | 175 | +23% Money | 0.02% |
| Season 1 | Unicorn | Epic | 700 | +8% Speed, +38% Money | 0.0084% |
| Season 1 | Delightful Trio | Legendary | 3 500 | +12% Speed, +17% Area, +57% Money | 0.0014% |
| SpinToWin | Crystal Doggy | Common | 20 | +10% Luck | 0.03% |
| SpinToWin | Crystal Kitty | Common | 20 | +10% Luck | 0.03% |
| SpinToWin | Crystal Bat | Uncommon | 60 | +16% Luck | 0.01% |
| SpinToWin | Crystal Butterfly | Uncommon | 60 | +16% Luck | 0.01% |
| SpinToWin | Crystal Cuboid | Rare | 200 | +23% Luck | 0.02% |
| SpinToWin | Amethyst Golem | Epic | 800 | +39% Luck, +20% Money | 0.0063% |
| SpinToWin | Brilliant Gem | Legendary | 4 000 | +18% Area, +59% Luck, +30% Money | 0.0011% |
| Royal | Royal Heart | Uncommon | 75 | +16% Money | 0.06% |
| Royal | Aureus | Rare | 250 | +24% Money | 0.01% |
| Royal | Empyreus | Epic | 1 000 | +20% Luck, +40% Money | 0.0048% |
| Royal | Queen Kitty | Legendary | 5 000 | +25% Power, +30% Luck, +60% Money | 0.0008% |
| Sparkletime | Red Sparkletime | Common | 30 | +10% Luck | 0.01% |
| Sparkletime | Pink Sparkletime | Common | 30 | +10% Luck | 0.01% |
| Sparkletime | Purple Sparkletime | Common | 30 | +10% Luck | 0.01% |
| Sparkletime | Blue Sparkletime | Uncommon | 90 | +16% Luck | 0.0084% |
| Sparkletime | Cyan Sparkletime | Uncommon | 90 | +16% Luck | 0.0084% |
| Sparkletime | Green Sparkletime | Rare | 300 | +25% Luck | 0.0045% |
| Sparkletime | White Sparkletime | Rare | 300 | +25% Luck | 0.0045% |
| Sparkletime | Black Sparkletime | Epic | 1 200 | +41% Luck, +21% Money | 0.0036% |
| Sparkletime | Gold Sparkletime | Legendary | 6 000 | +13% Speed, +61% Luck, +31% Money | 0.0006% |

«Шанс за одно яйцо» посчитан для худшего случая: поражение без Luck. После победы с лучшим вкладом легендарные выпадают примерно в 4 раза чаще. Самый редкий питомец, Gold Sparkletime, приносит 6 000 монет в секунду и выпадает примерно в 1 яйце из 170 000.

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
