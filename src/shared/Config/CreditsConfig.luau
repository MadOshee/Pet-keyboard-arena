--!strict
-- Who made what we use (Settings > Credits, Ivan 2026-10-14). ProfileStore
-- is the only piece under a license that asks for its notice (Apache 2.0);
-- Creator Store packs and audio need no credit, but players see them anyway.
-- Add authors' names here when Ivan knows them.

export type Entry = {
	Title: string,
	Text: string,
}

return table.freeze({
	table.freeze({
		Title = "ProfileStore",
		Text = "Player data saving. ProfileStore by loleris (MAD STUDIO). "
			.. "Licensed under the Apache License, Version 2.0: "
			.. 'apache.org/licenses/LICENSE-2.0. Used unchanged, provided "as is", without warranties.',
	}),
	table.freeze({
		Title = "Studs UI Pack 2",
		Text = "Buttons, windows, icons and interface sounds. Roblox Creator Store.",
	}),
	table.freeze({
		Title = "Pets & Eggs",
		Text = "Pet and egg models. Roblox Creator Store.",
	}),
	table.freeze({
		Title = "Free Ocean Keyboard",
		Text = "Keyboard key model, key sound and game sounds. Roblox Creator Store.",
	}),
	table.freeze({
		Title = "Map",
		Text = "Hub plaza and player bases from a map pack. Roblox Creator Store.",
	}),
	table.freeze({
		Title = "Music",
		Text = "GearshockBeach Training, Tug Of War Theme, factory theme mini mix and the You Win track. Roblox audio.",
	}),
	table.freeze({
		Title = "Sound effects",
		Text = "Magic Circle Warp, magic cast 43, Magic Poofs Thumpy, Magic Lock, magic ramen done, "
			.. "Banana collect 9 and the countdown and victory sounds. Roblox audio.",
	}),
}) :: { Entry }
