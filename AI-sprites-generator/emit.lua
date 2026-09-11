-- Builds every tile as an indexed Aseprite sprite with the locked palette and exports PNGs,
-- then paints the combined spritesheet. Driven by the JSON written by build.py.
local f = assert(io.open(app.params["data"], "r"))
local data = json.decode(f:read("a"))
f:close()
local out = app.params["out"]
local tw = math.tointeger(data.tile_w)
local th = math.tointeger(data.tile_h)

local pal = Palette(#data.palette)
for i, hex in ipairs(data.palette) do
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  local a = (#hex == 9) and tonumber(hex:sub(8, 9), 16) or 255
  pal:setColor(i - 1, Color{ r = r, g = g, b = b, a = a })
end

local function newSprite(w, h)
  local spr = Sprite(w, h, ColorMode.INDEXED)
  spr.transparentColor = 0
  spr:setPalette(pal)
  local img = spr.cels[1].image
  img:clear(0)
  return spr, img
end

-- json.decode yields floats (5.0), and drawPixel only treats integers as palette indices
-- (a float silently becomes index 1), so convert explicitly and read every pixel back.
local mismatches = 0
local function paint(img, pixels, ox, oy)
  for i = 0, #pixels - 1 do
    local c = math.tointeger(pixels[i + 1])
    if c ~= 0 then
      local x, y = ox + i % tw, oy + i // tw
      img:drawPixel(x, y, c)
      if img:getPixel(x, y) ~= c then
        mismatches = mismatches + 1
      end
    end
  end
end

for _, t in ipairs(data.tiles) do
  local spr, img = newSprite(tw, th)
  paint(img, t.pixels, 0, 0)
  spr:saveCopyAs(out .. "/" .. t.group .. "/" .. t.name .. ".png")
  spr:close()
end

local sheet, simg = newSprite(math.tointeger(data.sheet.width), math.tointeger(data.sheet.height))
for _, t in ipairs(data.tiles) do
  paint(simg, t.pixels, math.tointeger(t.x), math.tointeger(t.y))
end
sheet:saveCopyAs(out .. "/spritesheet/" .. data.sheet.image)
sheet:close()

print("emitted " .. #data.tiles .. " tiles + " .. data.sheet.image .. ", read-back mismatches: " .. mismatches)
assert(mismatches == 0, "palette index read-back failed")
