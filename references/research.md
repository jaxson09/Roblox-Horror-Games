# Research notes

Gathered in mid-November 2026. **Read the confidence labels.** The sessions that did this research could not open roblox.com, YouTube, the DevForum or most wikis, so a lot of it comes from search-result summaries rather than the pages themselves. Anything that matters for a decision should be checked again from the owner's computer, where those sites open normally.

- **[docs]** — read from Roblox's own documentation (the public mirror at `github.com/Roblox/creator-docs`).
- **[listing]** — from game-statistics sites' summaries (Rolimons, Bloxstatus).
- **[wiki]** — from a fan wiki that reads as auto-generated. Treat as rumour.
- **[guess]** — inference. Nobody said it.

---

## 1. ANALOG

- **What it is [listing]:** "ANALOG 📂[HORROR]" by the group **Kioverse Games**. <https://www.roblox.com/games/105916934349181/ANALOG>. Tagline "REPORT. SURVIVE." Created about 1 October 2026.
- **Size [listing]:** about 8.1 million visits, all-time peak about 4,185 players at once, 87% approval, servers of up to 45. That is a rising niche game, not a breakout hit — the big horror hits peak in the hundreds of thousands.
- **Premise [listing]:** you work for "an organization that doesn't exist", gathering data on "entities that shouldn't exist". The page says "Game still in development.. expect bugs."
- **Where its monster comes from [listing]:** the description says the game is "heavily inspired by" the YouTube animation *I Made A Self-Aware Robot* by **LIGHTS ARE OFF**. The robot, **E.L.B.E.R.R**, is that creator's character: very tall, skeletal, exposed machinery, tennis-ball hands, wants "skin". **It is not ANALOG's to lend, and not ours to take.**
- **Structure [listing]:** released in Parts. Parts 1–3 within about three weeks (Part 3 is "Big Bad Wolf"), Part 4 plus a Halloween mode ("Pumpkin Rabbit") within a month. Each part adapts a different internet horror property.
- **Part 1 loop:** confirmed by the owner's video — see [`analog-part1/NOTES.md`](analog-part1/NOTES.md).
- **Voice chat [wiki + video]:** the robot reacts to players' microphones; the video shows a "TURN ON VC" banner and a tutorial card about it.
- **Its paid items [listing]:** class passes (Hunter 549 R$, Trapper 379, Trickster 349), RADAR 76, one pass at 1,299 and a "Sponsor" pass at 28,500. **[wiki]:** PUSH 99, Infinite Lives 99, night-vision goggles. The video shows "Infinite Lives" and "Hunt Player" buttons on the HUD.
- **The masks on the walls that open a Robux prompt:** the owner described these. **No source found confirms them.** Check in the real game.

### Why it is rising **[guess]**

1. It rides a character that was already viral in short videos.
2. A new part every week or so, each with a fresh monster — a new thumbnail and a new search term each time.
3. A monster that answers the microphone makes clips people share.
4. Codes that unlock at like and visit milestones push players to rate it.

**What that means for an original game:** point 1 is not available to us, and it is probably the biggest of the four. An original monster has to earn attention on its own, which makes the first thirty seconds, the thumbnail and one shareable moment matter far more.

## 2. Similar games, 2025–26 **[listing]**

| Game | What it is | What to learn |
| --- | --- | --- |
| **DOORS** | Room-by-room escape with a cast of entities | Each entity has one clear rule. Revives and a soft currency fund it. |
| **Pressure** | DOORS-like, underwater facility | First revive is earned in play, the second costs Robux. |
| **The Mimic** | Chapter-based story horror | Chapters released over time keep people returning. |
| **Animal Hospital (Anomaly)** | Co-op night shift spotting impostor patients; about 1.27M peak | A hospital and a "job" are a proven setting. Observation can carry horror. |
| **Scary Shawarma Kiosk** | Night-shift job with random anomalies; about 190K peak | A mundane job plus one wrong thing. Spread through TikTok. |
| **99 Nights in the Forest** | Co-op survival; peaks in the hundreds of thousands | Progression and classes keep people playing. |
| **Forsaken** | One killer against survivors | Funded almost entirely by cosmetics. |

One outlet's view **[guess]**: plain jump-scare corridors are losing ground to games with progression, roles and reasons to replay.

## 3. Robux: what others charge **[search summaries — weak]**

- DOORS: revive packs around 145 / 239 / 479 R$ for 5 / 10 / 25. A single revive around 30 R$.
- 99 Nights: self-revive 45 R$; "revive friend" and "revive everyone" exist.
- Pressure: pet pass 149; currency boost 599.
- The Mimic: 2× lantern 30–50; VIP 699–799.
- Forsaken: emote pack 149; skin pack 299.
- Forum opinion only: revives and consumables that fit the story are liked; a speed pass that decides who lives is the usual example of "pay to win".
- No hard data was found on what converts best. Our prices are educated guesses and should be tuned with real numbers after launch.

## 4. Roblox's rules **[docs]**

- **Purchases must be honest.** "You must present monetization products in a way that's transparent, honest, and user-friendly." "Users must never be misled, confused, or pressured into purchases in ways they did not intend." No fake countdowns; no permanent "sale".
- **Roblox Plus members get 10–20% off**, paid for by Roblox. So never write a price into the UI — read the live price.
- **Random paid items** must show their odds and be hidden where they are restricted. We sell none.
- **Content rating:** frequent scares with no blood most likely lands on **Moderate**. An unrated game cannot be played at all.
- **New games start visible to players 16 and over only**, until 250 "highly engaged, age-checked" players have played within 60 days. The creator needs an age check, two-step verification, and either a refundable fee or two months of Plus/Premium. **This affects launch: a horror game aimed at younger teenagers will not reach them on day one.**
- **Audio:** uploads are free (2,000 a month if ID-verified, 100 if not), under 20 MB and under 7 minutes each. Your own audio always works in your own games.
- **Rewarded video ads** need 2,000 monthly visitors and may not be used as a gate on progress.

## 5. Technical facts **[docs]**

- **Roblox Studio has a built-in MCP server** — this is how an AI session on the owner's computer should work. Turn it on in Studio: **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**, then use **Quick connect** for Claude Code. Its tools include `execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`, `character_navigation`, `user_keyboard_input`, `user_mouse_input`, `script_read`, `multi_edit`, `search_asset`, `insert_asset`, `generate_mesh`, `generate_material` and `save_place`. Page: <https://create.roblox.com/docs/studio/mcp>. Roblox's older stand-alone MCP server is no longer developed.
- **Purchases:** `ProcessReceipt` can run twice and on two servers; grants must be safe to repeat (keyed on `PurchaseId`). Use `GetProductInfoAsync`, not the deprecated `GetProductInfo`. Grant passes on `PromptGamePassPurchaseFinished`.
- **Private match servers:** `ReserveServer` and `TeleportToPrivateServer` are deprecated. The current way is `TeleportOptions.ReservedServerId = HttpService:GenerateGUID(false)` with `TeleportAsync`. **Our lobby uses this and it has never been tested.** Teleporting does not work in Studio at all; it needs a published place.
- **Lighting:** `Lighting.Technology` is deprecated; use `LightingStyle` and `PrioritizeLightingQuality`. Roblox has no film-grain, vignette or chromatic-aberration effect — those have to be drawn as UI, which is what `src/client/UI/Vhs.luau` does.
- **Sound:** the old `Sound` object still works but Roblox now steers people to the newer audio objects (`AudioPlayer` → `AudioEmitter` → `AudioListener`), which support real occlusion through walls. Worth a look for a game where hearing the monster through a wall matters.
- **Fonts built into Roblox:** Creepster, Special Elite, Press Start 2P, Permanent Marker, Grenze Gotisch, Inconsolata, Roboto Mono, Michroma, Jura and others. Nosifer and VT323 are not built in.
- **Highlights:** at most 255 at once.
- **Rojo:** 7.7.1 is current. `rojo serve` syncs files into Studio; `rojo build` writes a place file. Installed with Rokit (`rokit.toml` is already in the repository).
- **Chat:** only the new TextChatService exists; the old chat was removed in 2025.

## 6. Still unknown — check from the owner's computer

1. What ANALOG **sounds** like: the robot's voice, the ambience, the music.
2. Whether the wall masks exist and what they sell.
3. What ANALOG's lobby looks like.
4. How ANALOG's voice-chat reaction actually works. **[guess]** Roblox's newer audio objects appear to let a game wire a player's microphone (`AudioDeviceInput`) into an `AudioAnalyzer` and read how loud it is — loudness only, never words. That would be enough to feed a noise meter. This was not confirmed from the documentation. **Do not promise this feature until it is confirmed possible and allowed.**
5. What players complain about (13% of ratings are dislikes; nobody could say why).
