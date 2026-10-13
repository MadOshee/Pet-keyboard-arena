# Пожелания игроков (кнопка Feedback)

Игрок нажимает **Feedback** справа вверху, пишет текст (3–500 символов) и жмёт **Send**. Отправлять можно раз в 30 секунд.

## Где хранятся

- **DataStore `Feedback`** — одна запись на сообщение. Ключ `<время unix>_<userId>_<номер>`, поэтому записи идут по времени. Значение:
  `{ UserId, Name, Text, Time, PlaceVersion }`.
- **Лог сервера** — строка `[FeedbackService] Имя (userId): текст`. Видно в Output в Studio и в Creator Hub → Analytics → Error Report / Server logs (в живой игре логи хранятся недолго, поэтому основной источник — DataStore).

DataStore работает только в опубликованной игре. В неопубликованном месте Studio пишет «You must publish this place to the web to access DataStore», и сообщение остаётся только в Output.

## Как читать

**Способ 1, без кода.** Creator Hub → твоя игра → **Data Stores** (Data Stores Manager) → `Feedback` → список ключей, у каждого виден текст.

**Способ 2, все сразу в Studio.** Открыть опубликованную игру в Studio, Game Settings → Security → включить **Enable Studio Access to API Services**. Потом вставить в Command Bar (View → Command Bar) и нажать Enter:

```lua
local store = game:GetService("DataStoreService"):GetDataStore("Feedback")
local pages = store:ListKeysAsync()
while true do
	for _, key in pages:GetCurrentPage() do
		local entry = store:GetAsync(key.KeyName)
		if entry then
			print(os.date("%Y-%m-%d %H:%M", entry.Time), entry.Name, entry.UserId, entry.Text)
		end
	end
	if pages.IsFinished then
		break
	end
	pages:AdvanceToNextPageAsync()
end
```

Все сообщения появятся в Output, старые сверху.

## Удалить прочитанное

В Data Stores Manager можно удалить ключ. Или в Command Bar: `game:GetService("DataStoreService"):GetDataStore("Feedback"):RemoveAsync("<ключ>")`.
