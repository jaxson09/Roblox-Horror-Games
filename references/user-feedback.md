# The owner's requests and feedback, word for word

Everything the owner has asked for, in order, exactly as typed. This is the specification. Short notes in *italics* say what was built in response — and where it still falls short.

---

## 1. The original request

> I want you to make a Roblox Horror Game inspired by the rising game by the name of ANALOG. For the repo, can you please remove the MIT licence. Use a licence that doesn't let people see your code. I want you to find all your own references and do your absolute best work. You need to implement the features in the other games but you also need to use new and cool features that people will love that will enhance the experience. You also need to look at how these games are rising and use your strategy to implement Robux payments and the best type of monster and story for this game. I want you to find gameplay for these types of games and use that for your work. Also, add a lobby area that is in all Roblox Story Horror games that presents the things that cost Robux like a scare all thing or like extra speed or something but like put it somewhere where people will see it but don't put it all up in their faces when they load in. Make it have that scary ambiance, with the theme and music related to the game. Use the correct text fonts and make the whole game just really scary and really fun to play for somebody. Make the monster somewhere between a Skinwalker and horror robot type that actually makes terrifying howling screams and also choose how you want the game to be. You are escaping somewhere scary, or you are in a forest of some sorts. I would lean towards a more escaping vibe. Make sure to add the Robux payments into the actual story mode of the game, but don't make it annoying. For example, in ANALOG, there are masks that are like the the monster on some of the walls where when you get close to it you can select it and the Robux payment just pops up but it is very subtle and doesn't seem like a Robux payment so it intrigues the player. I want you to do all this on the JBrosDev account.

*Built: a first version set in an underground bunker with a deer-skull monster. The owner rejected it (see 4 and 5).*

*Two things the owner was told plainly:*
- *A licence cannot hide code. The MIT licence was replaced with an "all rights reserved" one, which forbids use. Only keeping the repository **private** stops people seeing the code.*
- *Purchases will not be made to "not seem like a Robux payment". Roblox's rules say players "must never be misled, confused, or pressured into purchases", and many players are children. Purchases are objects in the world and stay out of the way, but each one shows its price and a "ROBUX PURCHASE" tag before Roblox's own dialog opens.*

## 2.

> Show me some gameplay

*No real gameplay could be shown: that session had no Roblox Studio. Only diagrams were produced. This is still the biggest gap.*

## 3.

> Can you give me the file

*A place file (`HollowSignal.rbxlx`) was generated and sent.*

## 4. After opening the first version

> Ok this looks really bad. I will attach refence videos for you to look at because the whole idea of the game is wrong. I want it to be original but still use the indoor type that ANALOG uses. https://www.youtube.com/watch?v=bdI7y9X2ry0 I attached a link of a video of gameplay. Also, you didn't even do the lobby part I was talking about. You should load into something where all players load into that is similar to the theme of the game and then there are circles at the end of the lobby where you can create lobbies and when you go in them a screen pops up and you select how many players (however many you think is good), the difficulty, and then put which part like part 1 part 2 part 3 and add all of them but make the part 2 and part 3 say in development. And then you press create lobby and then when people come in the circle they join in but there is a leave button on the bottom which takes you out the circle. Then the lobby creator can choose whether to start the match, or if the amount of players that are the same as the lobby amount join there is a timer from 15 seconds and when it hits 0 the game automatically starts.

*Built: the lobby exactly as described — an indoor admissions hall, four circles at the far end, a Create Lobby screen (crew size 1/2/3/4/6, difficulty, part; Parts 2 and 3 "In development"), join by walking in, Leave at the bottom, host Start, 15-second countdown when full. Never tested with real players.*

## 5. With the uploaded video (ANALOG Part 1)

> I want it to be something scary like a hospital or an abandoned building, something along those lines that you think will be good. It should be something original, based off what the monster is, the player can interact with it first, or you are on a mission for your company you work for which is a company that finds stuff like this and you have to get evidence of it or you and your friends are abandoned building explorers, or just one player if it is one playing and you are trying to find stuff to post on social media. The whole presentation just looked really bad. I didn't even play the full game but I think you just got the wrong idea with everything, and you can improve. Overall everything needs to be much better, and if you don't know what I mean, don't worry I attached a video. I mainly want you to take inspiration from part 1 of the video. If you want after, I will include the other parts of the game but mainly use this for reference and remember to make it original and add very cool features, make it 10x cooler and better, and just overall do your best work.

*Built: the game was rebuilt from scratch as **Hollow Signal** — you work for a company that gets evidence of things that should not exist; the case is an abandoned hospital ward; the subject is H.U.S.H., a patient-care robot that copies voices. See `../MASTER_PROMPT.md` for the full description.*

*Not yet answered: "the whole presentation just looked really bad" was about the first version. Nobody has seen the rebuild running, so nobody knows whether it looks better. "10x cooler and better" has not been proven.*

## 6.

> Just so you know the computer is going to restart in 4 minutes

> Ok continue your work now it restarted

## 7. After seeing the map and screen diagrams

> Use a different font like a scarier one and also on the map like for example at the part where it says elevator the text is overlapping the icons and it is tiny stuff like this where you need to pay attention make sure everything is proper and also make sure nothing is overlapping anything and can you give me the download to test the game after you are completely done

*Built: Creepster for headlines and the monster's lines, Special Elite (worn typewriter) for body text; every HUD position moved into one layout table with an automated test that fails if any two elements overlap on 12 screen sizes; the map drawing refuses to render if any label overlaps anything. A new download was sent.*

*The lesson to keep: **the owner notices small things.** Overlapping text, misaligned labels, anything sloppy. Check every screen by looking at it before saying it is done.*

## 8. The request that produced this folder

> Can you give me a huge master prompt and rundown for a new chat of what the game is about and all the feedback I've given you to make the best game possible and tell it to use my actual computer for roblox studio and also make a references folder with all the references I've given you

---

## How the owner wants to be spoken to

From their standing preferences:

> Be direct and honest, not agreeable. Challenge my assumptions when they weak. If I'm wrong, say "you're wrong" and explain why. Rate ideas honestly out of 10. If you're uncertain, say so instead of guessing confidently. Research what I ask you to get the most up-to-date and thorough information. Do NOT agree with everything I say, be honest even if it's not what I want to hear.

## The feedback in one list

1. **Original**, but the same kind of game as ANALOG: indoors, a job to do, a monster hunting you.
2. Setting: **a hospital or an abandoned building**. Not a forest, not a bunker.
3. Story frame: **you work for a company that finds things like this and you have to get evidence** (chosen), or explorers filming for social media. Works with one player or a crew.
4. Monster: **between a skinwalker and a horror robot**, with **terrifying howling screams**. The player can interact with it.
5. An **escaping** feel.
6. **Lobby** that matches the theme, with **circles at the far end** to create and join lobbies (players, difficulty, part), a **Leave** button at the bottom, host **Start**, and a **15-second** auto-start when full. Parts 2 and 3 marked **in development**.
7. Robux items shown in the lobby **where people will see them but not in their faces when they load in**, and woven into the story mode **without being annoying**.
8. **Scary ambience and music** that fit the theme. **Scary fonts.**
9. **Really scary and really fun.** New, cool features people will love. "10x cooler and better."
10. **Presentation matters most.** The first version "looked really bad". Everything needs to look much better.
11. **Nothing overlapping anything.** Pay attention to tiny details.
12. Everything on the **JBrosDev** Roblox account.
13. Take inspiration **mainly from Part 1** of the ANALOG video; more parts may be sent later.
