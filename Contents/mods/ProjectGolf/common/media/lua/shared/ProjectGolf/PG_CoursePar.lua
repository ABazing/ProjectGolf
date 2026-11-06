-- Project Golf - par for every course hole. Edit the numbers freely (restart the game afterwards).
-- The comment on each line is the hole's tee-to-cup distance, as a guide.
-- For scale: a full drive carries about 68 squares (metres) plus some roll at average Strength (Strength 0: about 40, 10: about 96).

ProjectGolf = ProjectGolf or {}

ProjectGolf.CoursePar = {
    WestMaple = {       -- West Maple Country Club
        [1]  = 5,       -- 201 m
        [2]  = 5,       -- 162 m
        [3]  = 4,       -- 152 m
        [4]  = 5,       -- 155 m
        [5]  = 4,       -- 117 m
        [6]  = 5,       -- 192 m
        [7]  = 4,       -- 144 m
        [8]  = 4,       -- 152 m
        [9]  = 4,       -- 136 m
        [10] = 3,       -- 106 m
        [11] = 4,       --  83 m, but tricky: short and tight, played as a par 4
        [12] = 4,       -- 125 m
        [13] = 4,       -- 112 m
        [14] = 4,       -- 152 m
        [15] = 4,       -- 153 m
        [16] = 4,       -- 149 m
        [17] = 4,       -- 136 m
        [18] = 4,       -- 144 m
    },
    WellingtonHeights = {   -- Wellington Heights Golf Club (parked for now: enabled = false in PG_Courses.lua)
        [1]  = 3,       --  29 m
        [2]  = 3,       --  63 m
        [3]  = 3,       --  17 m
        [4]  = 3,       --  55 m
        [5]  = 3,       --  68 m
        [6]  = 3,       --  49 m
        [7]  = 3,       --  93 m
        [8]  = 3,       --  24 m
        [9]  = 3,       --  36 m
    },
}
