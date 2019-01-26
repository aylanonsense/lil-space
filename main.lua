local GAME_WIDTH = 200
local GAME_HEIGHT = 200
local RENDER_SCALE = 3

local ship = {}
local asteroids = {}

function love.load()
end

function love.update(dt)
end

function love.draw()
  -- Set some drawing filters
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)

  -- Make the canvas black
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle('fill', 0, 0, GAME_WIDTH, GAME_HEIGHT)

  -- Draw the game
  love.graphics.setColor(1, 1, 1, 1)
  -- ...
end
