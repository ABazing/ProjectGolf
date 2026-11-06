-- Project Golf - Tips / Scorecard window: tips, plus a scorecard for each tracked course (West Maple).
-- Opened from a ball's right-click menu: Golf > Tips / Scorecard. Scores fill in by themselves when you sink a course hole
-- (see PG.Client.recordScore); teeing off on hole 1 starts a fresh card for that course.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Courses"
require "ProjectGolf/PG_Client"

local PG = ProjectGolf

-- ---- the tips page (edit freely; blank strings are paragraph gaps, lines starting with "#" are headings) ----------
PG.GuideTips = PG.GuideTips or {
    "# Taking a shot",
    "Drop a golf ball, hold a golf club and right-click the ball: Golf > Putt, Chip or Drive.",
    "Or right-click a ball in your inventory: Tee up golf ball. You step up to it with the putter, handy for practising putts at home.",
    "Aim with the mouse (or where you look in first person). Hold the left mouse button and let go to swing. Switch clubs with the mouse wheel or 1 / 2 / 3.",
    "Stay out of the red. Swinging past the red line sprays the ball and can shank it.",
    "",
    "# The clubs",
    "Putt: rolls along the ground. For the green.",
    "Chip: a high, soft shot that stops quickly. For getting close.",
    "Drive: long and low. Off the tee and down the fairway.",
    "",
    "# Reading the shot",
    "The dotted line shows where the ball will go. The gold marker on the meter is the power that stops the ball at the hole: every club on West Maple, putts anywhere else.",
    "The cup takes a ball that is rolling gently. Too firm and it lips out, and a ball clipping the rim needs to be slower still.",
    "",
    "# Getting better",
    "Strength makes the ball go further.",
    "Aiming makes shots straighter and overswings safer, shows more of the dotted line, and turns the rough gold band into an exact marker. Golf trains Aiming a little, and sinking the ball trains it more.",
    "",
    "# On the course",
    "West Maple Country Club has 18 holes. Stand on a tee box (the mown square with two tee markers) with a ball and right-click: Golf > Tee off. You step up to the ball with the Driver, or the Chip on a par 3. Teeing off on hole 1 starts a new scorecard.",
    "Water swallows the ball and costs a stroke. Trees catch high shots. Zombies get in the way, and they hear the whack.",
    "Lost your ball? Hold a golf club and turn on foraging (search mode) to spot it.",
    "",
    "# Your own holes",
    "Craft a Golf Hole from an empty tin can, a plank and ripped sheets, then right-click the ground: Golf > Place golf hole here.",
}

-- ---- the window ------------------------------------------------------------------------------------------------
PG_GuideWindow = ISCollapsableWindow:derive("PG_GuideWindow")

local PAGES = { { id = "tips", label = "Tips" } }
for _, course in ipairs(PG.Courses.list) do PAGES[#PAGES + 1] = { id = course.id, label = course.name, course = course } end

local function fontH(font)
    local ok, h = pcall(function() return getTextManager():getFontHeight(font) end)
    return (ok and h and h > 0) and h or (font == UIFont.Medium and 20 or 15)
end

local function textW(font, s)
    local ok, w = pcall(function() return getTextManager():MeasureStringX(font, s) end)
    return (ok and w) or #s * 7
end

local function wrap(font, text, width)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        local test = line == "" and word or (line .. " " .. word)
        if line ~= "" and textW(font, test) > width then
            lines[#lines + 1] = line
            line = word
        else
            line = test
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

function PG_GuideWindow:new(player)
    local small, medium = fontH(UIFont.Small), fontH(UIFont.Medium)
    local w = 480
    local h = math.max(560, 16 + 2 * medium + 30 * (small + 3) + 40 + small + 18)   -- an 18-hole card fits at any font size
    local core = getCore()
    local x = math.floor((core:getScreenWidth() - w) / 2)
    local y = math.floor((core:getScreenHeight() - h) / 2)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.player = player
    o.page = "tips"
    o.scroll = 0
    o.title = "Golf - Tips / Scorecard"
    return o
end

function PG_GuideWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)
    local top = self:titleBarHeight() + 8
    local bx = 10
    local bh = fontH(UIFont.Small) + 8
    self.tabs = {}
    for _, p in ipairs(PAGES) do
        local label = p.course and (p.course.short or p.course.name) or p.label
        local bw = textW(UIFont.Small, label) + 20
        local b = ISButton:new(bx, top, bw, bh, label, self, PG_GuideWindow.onTab)
        b.internal = p.id
        b:initialise()
        self:addChild(b)
        self.tabs[#self.tabs + 1] = b
        bx = bx + bw + 6
    end
    self.contentTop = top + bh + 10

    -- bottom right: New card (clears this round, keeps the bests)
    local by = self.height - bh - 10
    local cw = textW(UIFont.Small, "New card") + 20
    self.clearBtn = ISButton:new(self.width - cw - 10, by, cw, bh, "New card", self, PG_GuideWindow.onClear)
    self.clearBtn:initialise()
    self:addChild(self.clearBtn)
    -- bottom left: Edit scores (fix a score that was recorded wrong)
    local ew = math.max(textW(UIFont.Small, "Edit scores"), textW(UIFont.Small, "Done editing")) + 20
    self.editBtn = ISButton:new(10, by, ew, bh, "Edit scores", self, PG_GuideWindow.onEdit)
    self.editBtn:initialise()
    self:addChild(self.editBtn)
    self:updateTabs()
end

function PG_GuideWindow:onTab(button)
    self.page = button.internal
    self.scroll = 0
    self.editing = false
    self:updateTabs()
end

function PG_GuideWindow:onClear()
    if self.page ~= "tips" then PG.Client.newScorecard(self.player, self.page) end
end

function PG_GuideWindow:onEdit()
    self.editing = not self.editing
    self:updateTabs()
end

-- Clicks on the little - / + boxes drawn in Edit mode (see addHit); everything else goes to the window.
function PG_GuideWindow:onMouseDown(x, y)
    if self.editing and self.hits then
        for _, h in ipairs(self.hits) do
            if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h then
                h.fn()
                return true
            end
        end
    end
    return ISCollapsableWindow.onMouseDown(self, x, y)
end

-- Draws a small "-" or "+" box and remembers where it is for onMouseDown.
function PG_GuideWindow:addHit(x, y, size, label, fn)
    local over = self:isMouseOver() and self:getMouseX() >= x and self:getMouseX() <= x + size
        and self:getMouseY() >= y and self:getMouseY() <= y + size
    self:drawRect(x, y, size, size, over and 0.9 or 0.6, 0.2, 0.35, 0.2)
    self:drawRectBorder(x, y, size, size, 0.9, 0.7, 0.9, 0.7)
    self:drawTextCentre(label, x + size / 2, y - 1, 1, 1, 1, 1, UIFont.Small)
    self.hits[#self.hits + 1] = { x = x, y = y, w = size, h = size, fn = fn }
end

function PG_GuideWindow:updateTabs()
    for _, b in ipairs(self.tabs) do
        if b.internal == self.page then
            b:setBackgroundRGBA(0.25, 0.45, 0.25, 1)
        else
            b:setBackgroundRGBA(0, 0, 0, 1)
        end
    end
    self.clearBtn:setVisible(self.page ~= "tips")
    self.editBtn:setVisible(self.page ~= "tips")
    self.editBtn:setTitle(self.editing and "Done editing" or "Edit scores")
    if self.editing then self.editBtn:setBackgroundRGBA(0.25, 0.45, 0.25, 1) else self.editBtn:setBackgroundRGBA(0, 0, 0, 1) end
end

function PG_GuideWindow:onMouseWheel(del)
    if self.page == "tips" then
        self.scroll = math.max(0, math.min(self.maxScroll or 0, self.scroll + del * fontH(UIFont.Small) * 3))
        return true
    end
    return false
end

function PG_GuideWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    if self.page == "tips" then self:renderTips() else self:renderCard(self.page) end
end

function PG_GuideWindow:renderTips()
    local left, width = 16, self.width - 32
    local top, bottom = self.contentTop, self.height - 12
    local small, medium = fontH(UIFont.Small), fontH(UIFont.Medium)
    self:setStencilRect(0, top, self.width, bottom - top)
    local y = top - self.scroll
    for _, para in ipairs(PG.GuideTips) do
        if para == "" then
            y = y + small * 0.6
        elseif para:sub(1, 1) == "#" then
            self:drawText(para:sub(2):match("^%s*(.-)%s*$"), left, y, 0.55, 0.9, 0.55, 1, UIFont.Medium)
            y = y + medium + 4
        else
            for _, line in ipairs(wrap(UIFont.Small, para, width)) do
                self:drawText(line, left, y, 0.9, 0.9, 0.9, 1, UIFont.Small)
                y = y + small + 1
            end
            y = y + 4
        end
    end
    self:clearStencilRect()
    self.maxScroll = math.max(0, (y + self.scroll) - bottom)
    if self.maxScroll > 0 then
        self:drawTextRight("scroll for more", self.width - 12, bottom - small, 0.6, 0.6, 0.6, 0.8, UIFont.Small)
    end
end

local function scoreColour(score, par)
    if not score then return 0.5, 0.5, 0.5 end
    if score < par then return 0.4, 1, 0.4 end
    if score == par then return 1, 1, 1 end
    return 1, 0.55, 0.45
end

local function toPar(d)
    if d == 0 then return "E" end
    return d > 0 and ("+" .. d) or tostring(d)
end

function PG_GuideWindow:renderCard(courseId)
    local course
    for _, c in ipairs(PG.Courses.list) do if c.id == courseId then course = c end end
    if not course then return end
    local card = PG.Client.getScorecard(self.player, courseId)
    self.hits = {}
    local small, medium = fontH(UIFont.Small), fontH(UIFont.Medium)
    local y = self.contentTop
    self:drawTextCentre(course.name, self.width / 2, y, 0.55, 0.9, 0.55, 1, UIFont.Medium)
    y = y + medium + 8

    local W = self.width
    local cols = { W * 0.17, W * 0.37, W * 0.60, W * 0.83 }   -- column centres: Hole, Par, Score, Best
    local function row(a, b, c, d, r, g, bl, cr, cg, cb)
        self:drawTextCentre(a, cols[1], y, r, g, bl, 1, UIFont.Small)
        self:drawTextCentre(b, cols[2], y, r, g, bl, 1, UIFont.Small)
        self:drawTextCentre(c, cols[3], y, cr or r, cg or g, cb or bl, 1, UIFont.Small)
        self:drawTextCentre(d, cols[4], y, r, g, bl, 1, UIFont.Small)
    end
    row("Hole", "Par", "Score", "Best", 1, 0.85, 0.4)
    y = y + small + 2
    self:drawRect(16, y, self.width - 32, 1, 0.6, 1, 1, 1)
    y = y + 4

    local function totals(from, to)
        local par, played, parPlayed, score = 0, 0, 0, 0
        for i = from, to do
            local h = course.holes[i]
            par = par + h.par
            local s = card.holes[i] and card.holes[i].last
            if s then played = played + 1; parPlayed = parPlayed + h.par; score = score + s end
        end
        return par, played, parPlayed, score
    end
    local function totalRow(label, from, to)
        local par, played, parPlayed, score = totals(from, to)
        local s = played > 0 and (score .. "  (" .. toPar(score - parPlayed) .. ")") or "-"
        self:drawRect(16, y - 1, self.width - 32, small + 2, 0.12, 1, 1, 1)
        row(label, tostring(par), s, "", 1, 0.85, 0.4)
        y = y + small + 4
    end

    local n = #course.holes
    for i, h in ipairs(course.holes) do
        local e = card.holes[i] or {}
        local r, g, b = scoreColour(e.last, h.par)
        row(tostring(i), tostring(h.par), e.last and tostring(e.last) or "-", e.best and tostring(e.best) or "-",
            0.9, 0.9, 0.9, r, g, b)
        if self.editing then
            local box, player = small, self.player
            for _, f in ipairs({ { col = cols[3], field = "last" }, { col = cols[4], field = "best" } }) do
                self:addHit(f.col - 22 - box, y, box, "-", function()
                    PG.Client.adjustScore(player, courseId, i, f.field, -1, h.par) end)
                self:addHit(f.col + 22, y, box, "+", function()
                    PG.Client.adjustScore(player, courseId, i, f.field, 1, h.par) end)
            end
        end
        y = y + small + 2
        if n == 18 and i == 9 then totalRow("Out", 1, 9) end
    end
    if n == 18 then totalRow("In", 10, 18) end
    totalRow("Total", 1, n)

    y = y + 6
    local best = card.bestRound and (card.bestRound .. " (" .. toPar(card.bestRound - totals(1, n)) .. ")") or "none yet"
    local bestText = "Best full round: " .. best
    self:drawText(bestText, 16, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
    if self.editing then
        local bx, coursePar, player = 16 + textW(UIFont.Small, bestText) + 12, (totals(1, n)), self.player
        self:addHit(bx, y, small, "-", function() PG.Client.adjustBestRound(player, courseId, -1, coursePar, n) end)
        self:addHit(bx + small + 6, y, small, "+", function() PG.Client.adjustBestRound(player, courseId, 1, coursePar, n) end)
    end
    y = y + small + 2
    local note = self.editing and "Click - / + to fix a score. An empty box starts at par."
        or "Scores fill in when you sink a hole. Teeing off on hole 1 starts a new card."
    for _, line in ipairs(wrap(UIFont.Small, note, self.width - 32)) do
        self:drawText(line, 16, y, 0.6, 0.6, 0.6, 1, UIFont.Small)
        y = y + small + 1
    end
end

function PG_GuideWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if PG.Guide.window == self then PG.Guide.window = nil end
end

-- ---- opening it ------------------------------------------------------------------------------------------------
PG.Guide = PG.Guide or {}

function PG.Guide.open(player)
    if PG.Guide.window then PG.Guide.window:close() end
    local w = PG_GuideWindow:new(player)
    w:initialise()
    w:addToUIManager()
    PG.Guide.window = w
    return w
end
