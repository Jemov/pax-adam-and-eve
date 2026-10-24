# Adam and Eve — From Nothing

A scenario audited against **Pax Universe 0.32.6**, with a tested short online start using DeepSeek 4.1. A connected AI model is required for this scenario. Humanity begins with exactly two adults in a pristine world. Guide their search for water, food and shelter, talk with both characters, and build knowledge through practical actions.

[Русское описание](../README.md)

## Installation and starting

Install **Adam and Eve — From Nothing** from the launcher's official Workshop and enable it under Mods. Alternatively, close the game and place `adam_eve-1.2.3.zip` from GitHub Releases into the user mods folder without extracting it. Open Launcher → Mods → Mods folder to locate it; the usual Windows location is `%APPDATA%\Pax Universe\mods`.

The game's standard **Solar System (`solar_system`)** mod is required. Enable both mods, approve code execution through the normal game prompt if requested, then start a new campaign with **Адам и Ева — с нуля → Эдем** and select the head-of-state role. These are the stable scenario-folder and faction identifiers. Displayed scenario text follows the game language.

Keep one installed copy. Close the game before replacing a manual installation; Workshop copies update through the launcher. Loading an existing scenario save preserves its progress rather than resetting its people and resources.

## The starting world

- Adam and Eve are the only humans. The player is a guiding role outside the world, not a third resident.
- There are no other nations, tribes, settlements, abandoned technologies or earlier human civilization.
- Earth has normal wildlife, forests, rivers and natural resources. Animals are part of the ecosystem, not diplomatic factions.
- Starting money, supplies, enterprises, electricity capacity and load are zero. Resources must be found and gathered.
- There is no ready-made clothing, shelter, fire, farming or advanced technology. Begin with observation, gathering, stone flakes, water and protection from the weather.
- New people require actual births and normal maturation. Death is not reversed automatically. Descendant settlements require real people and reasons.
- The names do not force miracles, a Fall or a predetermined ending. The subsequent history depends on the player.

The assistant interprets interface terms at the scale of a tiny community: reports are a diary, research means experiments and learned skills, and orders are practical tasks. The starting pair cannot perform ten jobs at the same time. Future development levels describe possibilities, not achievements granted at startup.

## Custom environment around 4000 BCE

New campaigns start on **1 March, 4000 BCE**, with a custom mid-Holocene environment: steppe and savanna across much of the Sahara, Mega-Chad of roughly 350,000 km², a larger Turkana and wetter southern Arabia. Persian Gulf and Baltic coastal changes are schematic. Greenland and Antarctica keep their land ice. Canada and Scandinavia have no continental ice sheets.

Sea ice follows a smooth annual cycle in opposite hemispheres: near its northern maximum and southern minimum in March, then the reverse in September. The map works on the globe and flat map; added lakes affect water masks and province picking.

This is an approximate game reconstruction, not a surveyed palaeogeographic map. The two-first-humans story is fictional. Global temperature references are not local province measurements. [Sources and assumptions](map-sources.md).

Restart after enabling the mods so the game's preset installer can register the scenario. If it is missing, close the game and extract only `presets/Адам и Ева — с нуля` from the release archive into `%APPDATA%\Pax Universe\presets` on Windows.

## Languages and saves

Full Russian and English scenario texts follow the game's language. The introduction, character descriptions and all **360 development levels with descriptions** are translated. Object identities and save references remain stable; player-created text is not rewritten.

Scenario changes apply only to worlds carrying this scenario's marker. Other campaigns are not reset. New geography and the ancient date apply to new campaigns; old saves keep their previous geography and date. The package includes the scenario data and a small runtime entry at `src/main.gd`. The banner is an illustration, not a gameplay screenshot.

The interface follows the game language: Russian for RU, English for EN and all other game languages.

## Population and continuation

Exactly two people is the starting condition. Normal native demographic growth and mortality apply afterwards; the former freeze below 20 people is removed, including exact legacy expressions read from older scenario data. User files are preserved. The engine uses aggregate and fractional demographic quantities. This mod does not invent individual pregnancies or turn fractions into child characters.

The founders' deaths do not end humanity while descendants, other communities or populated colonies survive. Empty food or money balances do not mean an empty world. When no people remain, a saved choice appears before a large time jump: end this community's story, or continue the game's native world history after humanity. Closing the game before answering keeps the choice pending and restores it on loading.

Continuation delegates to the native evolution system, including its own time calculations, populations, random events and explanatory cards. The new intelligent species begins a new history of life; it is not resurrected founders or unseen children. The narrator receives the actual knowledge and development left by the previous community. Other scenarios retain their native behaviour.

## 0.32.6 audit limitations

Version 1.2.2 uses the bundled layer if the native preset installer omits any of seven data JSON files. Complete installed presets and other worlds retain the native path. Zero-start initialization, geography, progress preservation and cold loading were checked. A real DeepSeek 4.1 request produced 16 primitive nodes across four spheres, all initially unlearned. Native UI start, prerequisites, time progression, completion, effects and persistence were tested separately from controlled HTTP fixtures.

With no food or water gathering the pair died before a 90-day research deadline, yet the native timer still completed it. This is not proof of survival balance. Offline mode leaves the tree empty and can demand dozens of workers and electricity for the pair's manual tasks. Reports may mention salaries and other countries. Aggregate casualties can diverge from named contacts. Offline play is not supported by this scenario; the engine can launch without AI but uses a coarse keyword fallback.

## 1.2.3 short online verification

Small positive one-time food/water hauls are preserved after the native roll rather than discarded below 0.5 tonnes. Native requirements, workers, cost, deadlines, chance and larger gains remain unchanged. Real water hauling, food gathering and a branch-and-leaf shelter were completed by the pair without manual resource grants. Both founders remained alive on day 20 and a cold restart preserved stocks and development. Water had been consumed by then and needs collecting again. This is a short online survival check, not a multiyear balance guarantee. Native panels and generated prose may round small quantities or contradict exact stock records. The known native research timer can still complete after extinction.
