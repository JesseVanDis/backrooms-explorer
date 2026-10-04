
# Technical
### The Stack
- **Engine**: Godot
- **Language**: GDScript

### Layout
 - The godot scenes (levels) are located in the 'scenes' folder. There are folders for each level, and the always start with `lvl_`.
   - It is possible that some levels will not have a number as postfix. such as level FUN
 - In the 'docs' folder of each godot scene (level) you can find the TECHNICAL.md of its level, with technical details about the scene. 
   - if not please make it. No need to put more than 2 sentences on it unless it gets complicated 
 - The level with have its own script 'lvl_X.gd' for the global handling of the level. basically some kind of main entry point.
 - Prefer the PRY over the DRY principle, ( Please Repeat Yourself ) for level specific stuff. This is to avoid breaking a random level by changing something central.
 - In blender, if a node starts with an '_', it means godot is using this node. It marks as a warning that when you change the name or path, godot will no longer be able to find it in some of its logic.   

# Sound
### Voices
 - Currently AI. Planning to ask a real voice actor once the game is nearing completion.
   - Done trough https://elevenlabs.io/app/speech-synthesis/text-to-speech
     - Stability: 0 = Creative, 1 = Robust, 0.5 = in between
     - Similarity: 0 = Low, 1 = High, 0.5 = in between
     - Starting lines: Always let it play these lines first, as it changes the tone of the AI. Then type the line you wish to voice, and cut that bit out.

     | Voice  | Actor                     | Model     | Stability | Similarity | Starting lines                                                                                                                                                             |
     |--------|---------------------------|-----------|---------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
     | Player | Rob - Tough & Calloused   | Eleven V4 | 0       | 0        | - `[Steps off parked bysicle] [outside in the wind] aaaah.. finally home again after a long day of work`<br> - `[pause][excited] Time to unpack some more moving boxes!`.  |
