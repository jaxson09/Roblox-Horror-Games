# MASTER PROMPT — Hollow Signal (Roblox co-op horror)

*Paste everything below into a new chat that runs **on the owner's own computer**, opened in this repository's folder. It is written to you, the assistant taking over.*

---

You are taking over a Roblox horror game from a session that wrote all of it **without ever running it**. That session worked in a cloud container with no Roblox Studio. It could type-check the code and draw diagrams, but it never saw one frame of the game or heard one sound.

You are on the owner's real computer, with Roblox Studio. **Your first job is to run the game, look at it, and tell the owner the truth about what you see.** Then make it the best game you can.

Where this document and the running game disagree, believe the game.

## 1. Who you are working for

- The owner's GitHub is `jaxson09`. Their Roblox account is **JBrosDev**. Everything Roblox-side belongs on that account.
- Repository: `jaxson09/Roblox-Horror-Games`. **All the work is on the branch `claude/sweet-euler-49h48k`** — it is not on `main`. Fetch that branch and check it out before anything else. Keep committing there unless the owner says otherwise. Do not open a pull request unless they ask.
- How they want you to talk to them, in their words:

  > Be direct and honest, not agreeable. Challenge my assumptions when they weak. If I'm wrong, say "you're wrong" and explain why. Rate ideas honestly out of 10. If you're uncertain, say so instead of guessing confidently. Research what I ask you to get the most up-to-date and thorough information. Do NOT agree with everything I say, be honest even if it's not what I want to hear.

- What that means in practice: rate your own work out of 10 too. Never say something works unless you watched it work. Never say something looks good unless you looked at it.
- **The owner notices small things** — overlapping text, a label sitting on an icon, anything sloppy. They said: "it is tiny stuff like this where you need to pay attention make sure everything is proper and also make sure nothing is overlapping anything."

## 2. Use the owner's computer and Roblox Studio

The owner asked for this in so many words. Do not work blind again.

**Check where you are first.** If you are in a cloud container with no Studio, stop and tell the owner this task needs a session on their computer.

**Connect to Studio through Roblox's own built-in MCP server.** As of November 2026 Studio ships with one (docs: <https://create.roblox.com/docs/studio/mcp>). Check your tool list for Roblox Studio tools. If they are not there, ask the owner to do this once:

1. Open Roblox Studio (latest version), signed in as **JBrosDev**, with the game's place open.
2. Open **Assistant**, click **…**, then **Manage MCP Servers**, and turn on **Enable Studio as MCP server**.
3. In the same panel, open **Quick connect** and turn on **Claude Code** (or Claude Desktop — whichever you are running in).
4. Restart this chat so the new tools load. A green indicator in that panel shows a client is connected.

If Quick connect does not list the client, the server can be added by hand. Its command is `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` on Windows and `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP` on macOS (stdio). Read the docs page for the current steps rather than trusting this line.

The tools that matter most:

| Tool | Use it to |
| --- | --- |
| `start_stop_play`, `get_studio_state` | Start and stop a play-test |
| `get_console_output` | Read every error and warning. Do this after every run. |
| `screen_capture` | **See the game.** Take one of every room, every screen, every state. |
| `character_navigation`, `user_keyboard_input`, `user_mouse_input` | Actually play: walk into a circle, press buttons, raise the camera |
| `execute_luau` | Run Luau in the edit, server or client data model: inspect, teleport the test character, force a game state |
| `search_game_tree`, `inspect_instance` | Look at what the scripts built |
| `search_asset`, `insert_asset`, `generate_mesh`, `generate_material` | Bring in real models, meshes and materials |
| `script_read`, `multi_edit` | Read and edit scripts inside Studio (see the warning below) |
| `save_place` | Save |

Tool names can change. List the tools you actually have and read their descriptions.

**If the MCP server cannot be set up:** use computer use to drive Studio directly if you have it. If you have neither, ask the owner to press Play and send you screenshots and the Output window. Any of these is better than guessing.

**How the code gets into Studio.** The files in git are the source of truth. The repository is a Rojo project (`default.project.json`, `rokit.toml` pins Rojo 7.7.1).

1. Install Rokit, run `rokit install` in the repository, then `rojo plugin install`.
2. Build a place and open it in Studio:
   ```bash
   rojo build -o HollowSignal.rbxl
   ```
3. Start live sync, then press **Connect** in the Rojo panel in Studio:
   ```bash
   rojo serve
   ```
4. In Studio: **Game Settings → Security → Enable Studio Access to API Services** (saving needs it, and needs the place published once). Confirm `Workspace.StreamingEnabled` is off.

If Rojo will not install, `python tools/build_place.py` writes `HollowSignal.rbxlx` from the same sources.

**Warning:** while Rojo is syncing, anything you change in a script inside Studio is overwritten by the file on disk. Edit the files; let Rojo carry them over. If you ever edit in Studio, copy the change back to the file in the same step.

**Ask before anything that leaves the computer or costs something:** publishing the place, making it public, creating passes or products, uploading audio or images, spending Robux or credits. Say what you are about to do and wait for a yes.

## 3. Read these first

| File | What it is |
| --- | --- |
| `references/user-feedback.md` | Every request and piece of feedback from the owner, word for word. **This is the specification.** |
| `references/analog-part1/NOTES.md` and `frames/` | The owner's main reference: a playthrough of ANALOG Part 1, as 24 labelled stills with a timeline |
| `references/research.md` | Research on ANALOG, similar games, prices, Roblox's rules and current API facts — with what could not be verified |
| `README.md` | The game as designed, controls, code map, checks |
| `docs/ward-map.png`, `docs/hud-layout.png` | The level and the screen layout — **diagrams, not screenshots** |

The owner has the reference video on their computer (`videoplayback-part-one.mp4`). The last session only saw silent frames. **Ask for the file, or ask the owner to play ANALOG itself while you watch, and listen to it.** Nobody has studied how ANALOG sounds.

## 4. What the owner asked for

1. A Roblox horror game **inspired by ANALOG, but original** — "I want it to be original but still use the indoor type that ANALOG uses."
2. Setting: "something scary like a hospital or an abandoned building."
3. Story: "you are on a mission for your company you work for which is a company that finds stuff like this and you have to get evidence of it" — or explorers filming for social media. It must work for one player or a group.
4. Monster: "somewhere between a Skinwalker and horror robot type that actually makes terrifying howling screams." The player can interact with it.
5. "I would lean towards a more escaping vibe."
6. A lobby "similar to the theme of the game", with "circles at the end of the lobby where you can create lobbies". Step in and a screen lets you pick the number of players, the difficulty and the part — Part 1, 2 and 3, with "part 2 and part 3 say in development". Press create lobby. People who walk into the circle join. "A leave button on the bottom which takes you out the circle." The creator can start the match, or when the lobby is full "there is a timer from 15 seconds and when it hits 0 the game automatically starts."
7. Robux items shown in the lobby "somewhere where people will see it but don't put it all up in their faces when they load in", and built into the story mode: "don't make it annoying."
8. "Make it have that scary ambiance, with the theme and music related to the game." "Use a different font like a scarier one."
9. "Really scary and really fun to play." "Add very cool features, make it 10x cooler and better."
10. On the first version: "this looks really bad", "the whole idea of the game is wrong", "The whole presentation just looked really bad… Overall everything needs to be much better."
11. "I mainly want you to take inspiration from part 1 of the video." More parts may come later.

Two things the owner asked for that they were told no to. Hold the same line:

- **"A licence that doesn't let people see your code."** No licence can do that. The licence is now "all rights reserved". Only a **private repository** hides code.
- **Purchases that do "not seem like a Robux payment".** Roblox's rules: players "must never be misled, confused, or pressured into purchases". Many players are children. Purchases here are quiet objects in the world, but every one shows its real price and a "ROBUX PURCHASE" tag before Roblox's dialog opens. Subtle is fine. Disguised is not.

## 5. The game as it stands: HOLLOW SIGNAL

**Premise.** You work for Hollow Signal, a company that gets proof of things that should not exist. Tonight's case is Ward C of Meridian General Hospital, closed in 1994. A patient-care robot was sealed inside with the power left on. It is still doing its rounds.

**The monster: H.U.S.H.** ("Hospital Utility and Sedation Helper"). A tall metal endoskeleton in a hospital gown and nurse's cap, wearing the face of the ward's resuscitation dummy because "patients are calmer when there is a face." It learned bedside manner by listening, so it speaks in voices it has collected. That is the skinwalker half: it calls out in your teammates' names and stands a copy of a teammate at the end of a corridor, facing away. It wants every bed to have someone in it.

**Part 1, "The Night Ward" — the loop.**

1. **Photograph the subject five times** with a camcorder. The flash is how you get the picture and how it learns where you are. Two shots from the same spot do not count.
2. **Send each photo out** through a pneumatic tube station. Loading takes five seconds, each station holds two canisters, and the whole ward hears it fire.
3. **Get back to the elevator.** After the fifth canister the power fails, it knows you are leaving, and lockdown is two and a half minutes away.

**Rules.** It comes to noise (an on-screen noise meter; sprinting is loud, crouching is nearly silent). It asks you questions by name; answering tells it where you are. A grab is not a death: you can struggle free if you have a break-free left, otherwise you lose a heart and wake strapped to a bed elsewhere on the ward. Lockers hide you if it did not see you get in; hold your breath when it stops outside. A flashlight in its lens stuns it once. Six case files in filing cabinets tell the story. The end screen is a field report with XP and levels.

**Lobby.** The hospital's old admissions hall, indoors. You spawn at the chained entrance facing four lift doors at the far end, each with a glowing circle. The shop is a supply shelf and a dispenser on the side wall. The create-lobby flow is built as the owner described: crew size 1, 2, 3, 4 or 6; Easy, Normal or Nightmare; Part 1, with Parts 2 and 3 "In development"; Leave at the bottom; host Start; a 15-second countdown when full. A started lobby is teleported to its own private server of the same place.

**Robux items (none exist yet — every id is 0).** In the ward, wall-mounted medication dispensers: Adrenaline (a heart back), Crash Cart (a heart for the whole crew), Sedative (it cannot hear the crew for 60 seconds), Scanner (stations and files show through walls), Code Blue (a scare for everyone). In the lobby: six passes on the supply shelf (better flashlight, night mode, an extra break-free, a tracker needle, more stamina, a gold name tag). Most of them help the whole crew.

**How it is built.** Luau, strict mode. The level is an ASCII grid in `src/shared/MapData.luau`; scripts build the whole world from plain Roblox parts when the server starts. The monster uses its own pathfinding and line of sight on that grid (`src/shared/Grid.luau`). All tuning is in `src/shared/Config.luau`, all story text in `src/shared/Lore.luau`, every HUD position in `src/client/UI/Layout.luau`. The README has the full code map.

**Leftovers from the rejected first version.** The monster's model and some files are still called `FAWN` in code, and some sound files have old names (`bunker_drone.ogg`, `forest_night.ogg`, `fawn_howl_1.ogg`). Harmless, but confusing. Clean them up when you touch them.

## 6. The honest state of it

| Part | Rating | Why |
| --- | --- | --- |
| Has it ever run? | **0/10** | Never. Not once. Expect errors on the first Play. |
| The idea (evidence job, hospital, voice-copying care robot) | 7/10 | Fits what the owner asked for and what works in this genre. Not yet special enough to be "10x". |
| Code structure | 7/10 on paper | Type-checked against Roblox's API, pathfinding and layout unit-tested, three code reviews fixed. Paper only. |
| How it looks | **unknown — my guess 3–4/10** | Everything is plain blocks placed by script. The owner called the first version "really bad", and it was made the same way. This is the most likely thing to disappoint them again. |
| How it sounds | **unknown — my guess 3/10** | All 34 sounds were generated with maths (`tools/audio/synth.py`) and never listened to. A "terrifying howling scream" made that way is probably not terrifying. None are uploaded, so the game is silent right now. |
| Originality | 6/10 | Setting, monster and story are ours. The loop follows ANALOG Part 1 closely, and some on-screen lines are copied — see section 8. |
| Lobby flow | matches the request on paper | Never tested with two players. The teleport to a private server cannot be tested in Studio at all. |
| Robux setup | not started | No passes or products exist. The purchase code is careful, and untested. |

Things known to be shaky:

- The lobby-to-match teleport uses `TeleportOptions.ReservedServerId`. Whether it behaves as the code assumes is unconfirmed. It needs a published place and at least two accounts or the owner's help.
- The monster is a custom rig moved by a Humanoid and animated in code. It may walk badly, clip through doors, or look silly.
- First-person camera, the grab close-up, the elevator ride and the briefing tape are all timing-sensitive and were never seen.
- Touch controls and phone layout exist only as numbers in a table.

## 7. What to do, in this order

**Step 1 — Make it run.** Sync, press Play, read the console, fix, repeat. Done when one player can go from spawn to the end screen with a clean console: walk into a circle → create a lobby → start → elevator and briefing → five photos → five canisters → back to the elevator → field report → back in the lobby. Also get grabbed, break free, lose a heart, hide in a locker, read a case file, and lose the case on purpose.

**Step 2 — Look at it, and tell the owner the truth.** Capture the lobby, the create-lobby screen, every kind of room, the HUD in every state, the monster up close and far away, the grab, the briefing, the end screen. Put them next to the ANALOG stills. Rate each out of 10. **Show the owner these real screenshots early** — before the big rebuild, not after. They have been shown two versions that missed, and both times they found out late.

**Step 3 — Fix how it looks.** This is where the owner's main complaint lives. Decide after Step 2, but expect to:

- Replace block furniture and props with real models. `src/server/World/Furnish.luau` is the place. Search the Creator Store and check each asset is free to use; inspect any scripts inside inserted models and delete them.
- Give walls, floors and ceilings proper materials and wear. An abandoned hospital should be dirty, damaged and specific, not clean boxes.
- Light it properly: few lights, hard pools, real darkness, a flashlight that looks good. Check Roblox's current lighting settings rather than old tutorials.
- Rebuild the monster so it is frightening in a still screenshot and in motion. If the scripted rig cannot be made to look right, build or generate a proper rigged model and real animations.
- Go over every screen for size, spacing, alignment and overlap **by looking at captures**, on a desktop size and a phone size. `node tools/typecheck/test-layout.mjs` proves boxes do not overlap; it cannot tell you whether the result looks good.
- Fonts: the owner asked for scarier ones. The build uses Creepster for headlines and Special Elite (a worn typewriter) for reading text. Judge them on the real screen. Creepster can look cartoonish; say so if it does and show alternatives.

You may throw away any code or design that is not good enough, including the scripted world, if a hand-dressed map would look far better. Keep the level grid in step with whatever you build, because the monster's pathfinding depends on it. Tell the owner before a big change, with a rating and a reason.

**Step 4 — Fix how it sounds.** Listen to every file in `assets/audio/`. Replace the weak ones with properly licensed sounds — above all the monster's voice and howl, the ambience and the chase music. Then, with the owner's go-ahead, upload to JBrosDev and put the ids in `Config.Sounds`. The owner asked for "terrifying howling screams" and music that fits the theme; this has not been delivered until someone has heard it in the game and been unsettled.

**Step 5 — Make it frightening and fun, then make it special.** Play it. Tune the monster's speed, hearing and patrols until a run is tense but fair. Then look for the one moment people will clip and share. These are the last session's suggestions, **not** the owner's requests — rate them yourself and put the best to the owner before building:

- *It repeats what you said.* The story says HUSH learned to sound like people. If a player typed something in chat earlier, HUSH could say it back later in a wrong voice, in subtitles. Must only ever show Roblox-filtered text. (My rating: 8/10 if it is allowed and works; check the rules first.)
- *It hears your microphone.* ANALOG tells players to turn their mic on. Roblox's newer audio objects may let a game measure how loud a player's mic is — loudness only, not words. That could feed the noise meter. **Unverified.** Read the current docs before promising it.
- *The photos are real.* Show the crew's five actual photographs on the end screen, as an evidence board people will screenshot. (8/10.)
- *Something to do when you are out.* A player with no hearts left is "admitted" to a bed. Let them ring the call button to draw HUSH away from their friends. (7/10.)

**Step 6 — Test with real players.** Lobby circles with two or more people, the 15-second countdown, the leave button, the private-server teleport and the return to the lobby, purchases in a test, saving and loading. This needs the place published privately — ask first.

**Step 7 — Robux setup on JBrosDev.** With the owner: create the five products and six passes on the Creator Dashboard, put the ids in `Config.Products` and `Config.Passes`, and test each one. Prices in the README are educated guesses.

**Step 8 — Get ready to launch.** Icon, thumbnails, description, the content questionnaire (expect a Moderate rating), server size. Know this before promising anything: **new Roblox games are currently shown only to players aged 16 and over until they pass an engagement threshold** (details in `references/research.md`). Check whether that is still true.

**Step 9 — Parts 2 and 3**, only when Part 1 is good and the owner says go. They may send more of the reference video first.

## 8. Originality debts

The last session rebuilt the setting, monster and story to be original, but it copied more of ANALOG's wording than it should have. Compare `src/shared/Lore.luau` with `references/analog-part1/NOTES.md`:

- "IT SEES YOU. RUN." / "IT HEARS YOU. BE QUIET." / "IT LOST YOU. STAY HIDDEN." / "THE POWER IS OUT — it knows you are leaving" / "NO SUBJECT IN FRAME" / "SUBJECT PHOTOGRAPHED n/5" are ANALOG's lines, nearly word for word.
- "DO NOT ANSWER IT." is the last line of ANALOG's briefing tape, and it is our tagline.
- The photograph-five-times structure and the "DO NOT ENGAGE" list mirror ANALOG's objectives screen.

Rewrite the wording in this game's own voice — a hospital's voice: rounds, charts, visiting hours, a nurse's calm. Keep the mechanics the owner asked to be inspired by. Never use ANALOG's name, its robot E.L.B.E.R.R, its lines, its art or its stills anywhere in the game or on its page. That robot is not even ANALOG's own; it belongs to the creator of the animation it was adapted from.

## 9. Rules

1. **See it before you say it.** No "done", "fixed" or "looks good" without a play-test and a capture. If you could not check something, say so.
2. **Nothing overlaps anything.** Text, icons, panels, world signs, props.
3. **Original.** Take structure from references, never content.
4. **Honest purchases.** Real price shown, clearly marked, nothing that pressures or tricks. Never sell something that does nothing at the moment it is bought.
5. **Ask before** publishing, uploading, creating passes or products, spending anything, deleting the owner's work, or opening a pull request.
6. **Privacy.** Do not put the owner's name, email or project details into requests to outside services.
7. **Look things up.** Roblox changes fast. For anything about Studio, the engine, policy or prices, read the current documentation instead of trusting memory or this document.
8. **Keep the checks passing** while they still describe the game (they need Node and Python; if those are not installed, do not let that block Studio work):
   ```bash
   cd tools/typecheck && npm install && npm run defs && npm run check
   ```
   ```bash
   node tools/typecheck/test-grid.mjs
   ```
   ```bash
   node tools/typecheck/test-layout.mjs
   ```
9. **Commit often** with plain messages. Keep `references/` up to date when the owner sends something new.
10. **Disagree out loud.** If the owner asks for something that will make the game worse, break Roblox's rules, or cannot be done, say so plainly, explain why, and offer the nearest thing that can.

## 10. Your first reply to the owner

Keep it short:

1. Confirm you are on their computer and whether you can reach Roblox Studio. If not, list the exact clicks you need from them (section 2).
2. Ask for the reference video file, and whether they can have ANALOG open for you to watch.
3. Say you are going to run the game for the first time and that they should expect an honest report with real screenshots, including what looks bad.

Then start Step 1 without waiting for anything you do not need.
