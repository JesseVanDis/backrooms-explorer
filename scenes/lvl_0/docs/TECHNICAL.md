# Technical

 - The level is procedualy generated, by the help of the script `generate_level.gd` It generates a bitmap with white and black pixels. 
   - The black pixels are walls, the bright ( not white per-se ) pixels are empty space.
   - Each pixel ( any color ) will have flooring. for now the only pick is `part_1x1_floor`.
   - Each pixel ( any color ) will have a ceiling. for now the only pick is `part_1x1_ceiling`.
   - Each black pixel bordering a white pixel means a wall. The wall to use is `part_1x1_wall`. It consists of only 1 face pointing to the positive Y, located at exacly [0,0,0]
   - ect... 
 

