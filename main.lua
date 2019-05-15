-- Game constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
local SHOW_BOUNDING_CIRCLES = false
local TIME_BETWEEN_LASERS = 0.4
local NUM_STARTING_ASTEROIDS = 4

-- Game variables
local ship
local lasers
local asteroids

-- Assets
local shipImage
local boostingShipImage
local massiveAsteroidImage
local largeAsteroidImage
local smallAsteroidImage
local spawnSound
local boostSound
local destroyedSound
local laserSound
local asteroidHitSound

-- love.load is called once when our game loads
function love.load()
  -- Set filters
  love.graphics.setDefaultFilter('nearest', 'nearest')

  -- Load assets
  shipImage = love.graphics.newImage('img/ship.png')
  boostingShipImage = love.graphics.newImage('img/ship-boost.png')
  massiveAsteroidImage = love.graphics.newImage('img/asteroid-massive.png')
  largeAsteroidImage = love.graphics.newImage('img/asteroid-large.png')
  smallAsteroidImage = love.graphics.newImage('img/asteroid-small.png')
  spawnSound = love.audio.newSource('sfx/ship-spawn.wav', 'static')
  boostSound = love.audio.newSource('sfx/ship-boost.wav', 'static')
  destroyedSound = love.audio.newSource('sfx/ship-destroyed.wav', 'static')
  laserSound = love.audio.newSource('sfx/laser.wav', 'static')
  asteroidHitSound = love.audio.newSource('sfx/asteroid-hit.wav', 'static')

  -- Create the player-controlled ship
  createShip()

  -- Create an empty array for lasers
  lasers = {}

  -- Create some massive asteroids to start
  asteroids = {}
  for i = 1, NUM_STARTING_ASTEROIDS do
    local vx, vy = createVector(25, math.random(0, 2 * math.pi))
    createAsteroid(math.random(0, GAME_WIDTH), math.random(0, GAME_HEIGHT), vx, vy, 3)
  end
end

-- love.update is called 60 time each second, it's here we update our game
function love.update(dt)
  -- Press the enter key to respawn
  if ship.isDestroyed and love.keyboard.isDown('return') then
    createShip()
    love.audio.play(spawnSound:clone())
  end

  -- Update the ship
  if not ship.isDestroyed then
    ship.invulnerabilityTime = math.max(0.00, ship.invulnerabilityTime - dt)
    ship.boostSoundCooldown = math.max(0.00, ship.boostSoundCooldown - dt)
    -- Rotate the ship when left/right are pressed
    if love.keyboard.isDown('left') then
      ship.rotation = ship.rotation - 6 * dt
    end
    if love.keyboard.isDown('right') then
      ship.rotation = ship.rotation + 6 * dt
    end
    -- Accelerate the ship when up is pressed
    if love.keyboard.isDown('up') then
      local vx, vy = createVector(150, ship.rotation)
      ship.vx = ship.vx + vx * dt
      ship.vy = ship.vy + vy * dt
      if ship.boostSoundCooldown <= 0.00 then
        love.audio.play(boostSound:clone())
        ship.boostSoundCooldown = 0.22
      end
    end
    -- Apply a small amount of friction to the ship
    ship.vx = ship.vx * 0.995
    ship.vy = ship.vy * 0.995
    -- Move the ship
    applyMovement(ship, dt)
    -- Shoot a laser when space is pressed
    ship.laserCooldown = math.max(0.00, ship.laserCooldown - dt)
    if love.keyboard.isDown('space') and ship.laserCooldown <= 0 then
      local vx, vy = createVector(100, ship.rotation)
      createLaser(ship.x, ship.y, ship.vx + vx, ship.vy + vy)
      ship.laserCooldown = TIME_BETWEEN_LASERS
    end
  end

  -- Update the lasers
  for i = #lasers, 1, -1 do
    local laser = lasers[i]
    applyMovement(laser, dt)
    -- Lasers disappear after a bit
    laser.timeUntilDisappear = laser.timeUntilDisappear - dt
    if laser.timeUntilDisappear < 0.00 then
      table.remove(lasers, i)
    end
  end

  -- Update the asteroids
  for i = #asteroids, 1, -1 do
    local asteroid = asteroids[i]
    applyMovement(asteroid, dt)
    -- Check for laser + asteroid hits
    for j = #lasers, 1, -1 do
      local laser = lasers[j]
      if objectsAreTouching(laser, asteroid) then
        table.remove(lasers, j)
        table.remove(asteroids, i)
        love.audio.play(asteroidHitSound:clone())
        -- Spawn smaller asteroids
        if asteroid.size > 1 then
          for k = 1, 2 do
            local vx, vy = createVector(25, math.random(0, 2 * math.pi))
            createAsteroid(asteroid.x, asteroid.y, vx + asteroid.vx, vy + asteroid.vy, asteroid.size - 1)
          end
        end
        break
      end
    end
    -- Check for ship + asteroid hits
    if not ship.isDestroyed and ship.invulnerabilityTime <= 0 and objectsAreTouching(ship, asteroid) then
      ship.isDestroyed = true
      love.audio.play(destroyedSound:clone())
    end
  end

  -- Spawn new asteroids if they all get destroyed
  if #asteroids == 0 then
    for i = 1, NUM_STARTING_ASTEROIDS do
      local vx, vy = createVector(25, math.random(0, 2 * math.pi))
      createAsteroid(math.random(0, GAME_WIDTH), math.random(0, GAME_HEIGHT), vx, vy, 3)
    end
  end
end

-- love.draw is called after love.update, we just render the game here
function love.draw()
  -- Clear the screen
  love.graphics.clear(37 / 255, 2 / 255, 72 / 255)

  -- Draw the ship
  love.graphics.setColor(1, 1, 1)
  if ship.isDestroyed then
    love.graphics.setColor(251 / 255, 238 / 255, 230 / 255)
    love.graphics.print('Press enter to respawn', 10, 10)
  elseif ship.invulnerabilityTime % 0.3 < 0.2 then
    local image = love.keyboard.isDown('up') and boostingShipImage or shipImage
    love.graphics.draw(image, ship.x, ship.y, ship.rotation, 1, 1, image:getWidth() / 2, image:getHeight() / 2)
  end

  -- Draw the lasers
  love.graphics.setColor(1, 1, 1)
  for _, laser in ipairs(lasers) do
    love.graphics.rectangle('fill', laser.x - 1, laser.y - 1, 2, 2)
  end

  -- Draw the asteroids
  for _, asteroid in ipairs(asteroids) do
    local image
    if asteroid.size == 1 then
      image = smallAsteroidImage
    elseif asteroid.size == 2 then
      image = largeAsteroidImage
    else
      image = massiveAsteroidImage
    end
    love.graphics.draw(image, asteroid.x, asteroid.y, 0, 1, 1, image:getWidth() / 2, image:getHeight() / 2)
  end

  -- Draw bounding circles (for debugging)
  if SHOW_BOUNDING_CIRCLES then
    love.graphics.setColor(1, 1, 0)
    if not ship.isDestroyed then
      love.graphics.circle('line', ship.x, ship.y, ship.radius)
    end
    for _, laser in ipairs(lasers) do
      love.graphics.circle('line', laser.x, laser.y, laser.radius)
    end
    for _, asteroid in ipairs(asteroids) do
      love.graphics.circle('line', asteroid.x, asteroid.y, asteroid.radius)
    end
  end
end

-- Creates the player ship
function createShip()
  ship = {
    x = GAME_WIDTH / 2,
    y = GAME_HEIGHT / 2,
    vx = 0,
    vy = 0,
    radius = 4,
    rotation = 0,
    laserCooldown = 0.00,
    isDestroyed = false,
    invulnerabilityTime = 1.50,
    boostSoundCooldown = 0.00
  }
end

-- Creates a laser where the ship is, making it look like it fired the laser
function createLaser(x, y, vx, vy)
  table.insert(lasers, {
    x = x,
    y = y,
    vx = vx,
    vy = vy,
    radius = 2,
    timeUntilDisappear = 1.50
  })
  love.audio.play(laserSound:clone())
end

-- Creates an asteroid, size=1 is small, size=3 is massive
function createAsteroid(x, y, vx, vy, size)
  table.insert(asteroids, {
    x = x,
    y = y,
    vx = vx,
    vy = vy,
    radius = 1 + 3 * size,
    size = size
  })
end

-- Generates a <x,y> pair with the given magnitude and pointing in the given angle
function createVector(magnitude, angle)
  return magnitude * math.cos(angle), magnitude * math.sin(angle)
end

-- Returns true if the objects' bounding circles are overlapping
function objectsAreTouching(obj1, obj2)
  local dx = obj2.x - obj1.x
  local dy = obj2.y - obj1.y
  local distance = math.sqrt(dx * dx + dy * dy)
  return distance < obj1.radius + obj2.radius
end

-- Applies the object's velocity to its position, and wraps it around the edges of the screen
function applyMovement(obj, dt)
  -- Move the game object
  obj.x = obj.x + obj.vx * dt
  obj.y = obj.y + obj.vy * dt
  -- Wrap the game object around the edges of the screen
  obj.x = (obj.x + GAME_WIDTH) % GAME_WIDTH
  obj.y = (obj.y + GAME_HEIGHT) % GAME_HEIGHT
end
