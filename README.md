# backrooms-explorer

An open-source, sandbox-style game focused on the exploration of the Backrooms.

## Project Vision
_backrooms-explorer_ (Working title) is a sandbox-like videogame about capturing the scale and mystery of the Backrooms as documented in the wiki. 

Unlike many Backgroom games and videos, It is not solely focussed on the horror aspect.
Players can freely walk around and explore different levels, encountering both enemies and friendly entities.

## Goal
The primary goal of _backrooms-explorer_ is to provide an immersive and accurate exploration experience of the Backrooms, based on the extensive documentation from the [Backrooms Wiki](https://backrooms-wiki.wikidot.com).
A way for 'finish' the game would be to escape the Backrooms. However it is not going to be the focus of this game.

## Features
Things to keep in mind when working on this game. 
- **Non euclidian spaces**. Plenty of level have them
- **M.E.G. Bases**. With humans living in them.
- **Filters** There are levels that lets you view the world in a different vision. Such as CRT Black & White.
- **Under water** some levels require you to dive to exit, such as level 7.
- **Vehicles** In level 69 you must drive a car until you reach a tunnel, or get killed by a giant spiders leg if you step out before that.
- **Gravity changes** In Level 7 the gravity changes depending on where you are.
- **Online**: <span style="color:#ff0000">Todo Discuss</span>: _( Massive scale - aka dedicated server, or local host ?. Lets at least target instances where 64 players can be in the system. We may have to deal with cheaters! )_
- **Entity 7 ( Jerry )** can occur in any level. Touching jerry will make you see him as king, or alternatively just give him sunflower seeds and he will never appear again
- **Entity 71 ( The red knight )** can occur in any level, and sometimes helps lost travelers. Specifically travelers who just entered the back rooms.
- **Level 24** You are on the moon. But there is a giant entity many many times bigger than the sun.
- **Level 75** is a cave system made out of gallium. The stuff that melts at body temperature. Tunnels will melt around you and ambient temperatures are occelating, including above melting point.
- **Fail safe** Some levels don't have exists. (documented at least) <span style="color:#ff0000">What should happen then ?</span> 

## Contributing
This is a collaborative project. If you're interested in contributing, feel free to dive into the code, models or sound, and join the effort!
Please keep your contribution true to the [Backrooms Wiki](https://backrooms-wiki.wikidot.com). 
The roadmap is below. But if you want to make any other level not listed in the roadmap, feel free to do so!

# Technical
It depends on the following: 
- **Engine**: [Godot Engine](https://godotengine.org/)
- **Language**: GDScript

Server mode is starting with the argument `--server`
When playing in offline mode, the server is started automatically, but nobody but the player can join.

## Artwork
Please choose any editor to your liking. Prefer free software, as other contributors can then also open the save file and edit it if needed. The saves go into the 'assets' folder


# Design
 - The game will follow the wiki as close as possible. Sometimes creativity is needed as the wiki sometimes goes on about rumors or unknowns.
 - It will be a first person (not shooter per-se) game.
 - When you enter a level, you will be presented with a brief description of the level, shown on a rugged mobile device. The M.E.G. Explorer Device. It will look something like this: ![docs/readme/1.png](docs/readme/1.png)
 - A link to the official wiki page will be presented as well. When clicking on it, the player will be redirected to the official wiki page inside the same phone (if possible). There may be a disclaimer somewhere that this game-level is only X% accurate due to uncertainties / unfinished work.
 - While the phone is active, the game is in a paused state, unless you are in an online session. This seems fair as in some levels require you to run IMMEDIATELY whenever you get into the level.
 - There will be M.E.G. bases, and you can trade stuff like almond water for armor and weapons.

# Financial
It will be sold on Steam for a yet to be discussed price to support the project. The earnings will be spread over the contributors, depending on an estimate on their effort or based on their hours if they provide any. please make sure your tools have the correct licensing. Some free tools require a license if you use them for profit.


# Roadmap

### V0.0.1
| Subject                    | progress (%) |
|----------------------------|--------------|
| **Mechanics**              | -            |
| - Running                  | 0            |
| - Jumping                  | 0            |
| - Moving in between levels | 0            |
| **Scenes**                 | -            |
| - lvl 0                    | 0            |
| - lvl 1                    | 0            |

### V0.0.2
| Subject                                                    | progress |
|------------------------------------------------------------|----------|
| **Multiplayer**                                            | -        |
| - Basic server                                             | 0        |
| - Players can see eachother move ( as placeholder models ) | 0        |

### V0.0.3
| Subject                                    | progress |
|--------------------------------------------|----------|
| **Main menu**                              | -        |
| - Play offline                             | 0        |
| - Play online                              | 0        |
| - Player model                             | 0        |
| - Quit                                     | 0        |
| **Ingame menu**                            | -        |
| - Savegames                                | 0        |
| **Pause/Resume**                           | 0        |
| **Multiplayer**                            | -        |
| - Players can see eachothers player models | 0        |

### V0.0.4
| Subject                     | progress |
|-----------------------------|----------|
| **Inventory system**        | -        |
| - Health system             | 0        |
| - Put thing in inventory    | 0        |
| - Drop thing from inventory | 0        |
| **Items**                   | -        |
| - Almond water              | 0        |
| **Scenes**                  | -        |
| - lvl 2                     | 0        |
| - lvl 3                     | 0        |

### V0.0.5
| Subject                                          | progress |
|--------------------------------------------------|----------|
| **Mechanics**                                    | -        |
| - Mobile phone with level description upon entry | 0        |
| **Entities**                                     | -        |
| - Clumps                                         | 0        |
| - Haunds                                         | 0        |
| **Scenes**                                       | -        |
| - lvl 4                                          | 0        |


### V0.0.6
| Subject                              | progress |
|--------------------------------------|---------|
| **Mechanics**                        | -       |
| - non-Euclidean properties in scenes | 0       |
| **Entities**                         | -       |
| - Smilers                            | 0       |
| - Crawlers                           | 0       |
| **Scenes**                           | -       |
| - lvl 5                              | 0       |
| - lvl 6                              | 0       |

### V0.0.7
| Subject                                          | progress |
|--------------------------------------------------|----------|
| **Mechanics**                                    | -        |
| - Block+Message when going into unfinished level | 0        |
| - Swimming                                       | 0        |
| - Gravity changes                                | 0        |
| **Entities**                                     | -        |
| - Skin-Stealers                                  | 0        |
| **Scenes**                                       | -        |
| - lvl 7                                          | 0        |

### V0.0.8
| Subject                  | progress |
|--------------------------|----------|
| **Mechanics**            | -        |
| - Attack / kill entities | 0        |
| **Items**                | -        |
| - Knife                  | 0        |
| - Headlight              | 0        |

### V0.0.9 
| Subject             | progress |
|---------------------|----------|
| **Mechanics**       | -        |
| - M.E.G. Bases      | 0        |
| - M.E.G. Tradepost  | 0        |
| - Friendly humans   | 0        |

### V0.0.10
| Subject     | progress |
|-------------|----------|
| **Items**   | -        |
| - 'GPS' Map | 0        |

### V0.1 ( entering alpha )
| Subject         | progress |
|-----------------|----------|
| **Items**       | -        |
| - Royal rations | 0        |
| - Firesalt      | 0        |
| **Entities**    | -        |
| - Smilers       | 0        |
| **Scenes**      | -        |
| - lvl 8         | 0        |

### V0.2
| Subject                                  | progress |
|------------------------------------------|----------|
| **Marketing**                            | -        |
| - Basic website                          | 0        |
| - Project subreddit                      | 0        |
| **Mechanics**                            | -        |
| - Completion rate of level on phone      | 0        |
| - 'Mobile' Chat window ( map and local ) | 0        |

**Announcement to Reddit happens when V0.2 is done**
Call for contributors!

### V0.3
| Subject    | progress |
|------------|----------|
| **Scenes** | -        |
| - lvl 9    | 0        |
| - lvl 10   | 0        |
| - lvl 11   | 0        |
| - lvl 12   | 0        |

### V0.4
| Subject         | progress |
|-----------------|----------|
| **Scenes**      | -        |
| - lvl 13        | 0        |
| - lvl 14        | 0        |
| - lvl 15        | 0        |

### V0.5
| Subject    | progress |
|------------|----------|
| **Scenes** | -        |
| - lvl 16   | 0        |
| - lvl 17   | 0        |
| - lvl 18   | 0        |
| - lvl 19   | 0        |
| - lvl 20   | 0        |

**Release on steam as early access**

### V0.6
| Subject                              | progress |
|--------------------------------------|----------|
| **Mechanics**                        | -        |
| - Large dedicated server extension ? | 0        |
| - M.E.G. Base how extension ?        | 0        |
| **Scenes**                           | -        |
| - lvl 21                             | 0        |
| - lvl 22                             | 0        |



# extensions ?
- Access to join a large dedicated server full of other players.
- A home. You can build/buy a home in a M.E.G. Base. **only once!**. It will leave a permanent mark on the map ( if there is room ). Destroying your home will allow you to build it elsewhere.
