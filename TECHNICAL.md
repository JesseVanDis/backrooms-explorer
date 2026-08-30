
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