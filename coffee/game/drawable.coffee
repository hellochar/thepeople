define [
  'assets'
  'canvasquery'
], (Assets, CanvasQuery) ->

  class Spritesheets
    @get: (name) ->
      Assets.get("/images/spritesheets/#{name}.png")

  # mapping from json.stringify(location) to canvasquery object
  cqCache = {}

  createCqFromLocation = (location) ->
    CELL_PIXEL_SIZE = 32
    {sx: sx, sy: sy, width: width, height: height, dx: dx, dy: dy, spritesheet: spritesheet, tileSize: tileSize, rotation: rotation, preprocess: preprocess} = location

    img = CanvasQuery(width * CELL_PIXEL_SIZE, height * CELL_PIXEL_SIZE)
    img.drawImage(spritesheet, sx * tileSize, sy * tileSize, width * tileSize, height * tileSize, 0, 0, width * CELL_PIXEL_SIZE, height * CELL_PIXEL_SIZE)

    preprocess(img) if preprocess

    img

  getCq = (location) ->
    key = [location.sx, location.sy, location.width, location.height, location.dx, location.dy, location.spritesheet.src, location.preprocess].join("|")
    cacheEntry = cqCache[key]
    if not cacheEntry
      cacheEntry = cqCache[key] = createCqFromLocation(location)
    return cacheEntry


  class Drawable
    constructor: (@x, @y) ->
      @timeCreated = Date.now()

    pt: () =>
      x: @x
      y: @y

    animationMillis: () => Date.now() - @timeCreated

    # {
    #   -- sprite sheet top-left location
    #   x, y,
    #
    #   -- dimensions of the sprite sheet cells (going down and to the right)
    #   width: 1, height: 1
    #
    #   -- cell offset from your pt() to draw
    #   dx: 0 (float)
    #   dy: 0 (float)
    #
    #
    #   -- rotation (ccw in degrees)
    #   rotation: 0
    #
    #   spritesheet: "tiles1"
    # }
    #
    # or an array of those objects
    spriteLocation: () => throw "not implemented"

    # returns an array of {spritesheet, sx, sy, width, height, rotation} to be used with drawImage
    getSpriteTemplates: () =>
      sprites = @spriteLocation()
      if not _.isArray(sprites)
        sprites = [sprites]

      for sprite in sprites
        sprite = {x: sprite[0], y: sprite[1], dx: sprite[2], dy: sprite[3]} if _.isArray(sprite)
        throw "bad sprite #{sprite}" unless _.isObject(sprite)
        sx = sprite.x
        sy = sprite.y
        width = sprite.width || 1
        height = sprite.height || 1
        dx = sprite.dx || 0
        dy = sprite.dy || 0
        spritesheetName = sprite.spritesheet || "tiles1"
        spritesheet = Spritesheets.get(spritesheetName)
        tileSize = 32
        rotation = (-sprite.rotation || 0) * Math.PI / 180

        spritesheet: spritesheet
        sx: sx
        sy: sy
        dx: dx
        dy: dy
        width: width
        height: height
        tileSize: tileSize
        rotation: rotation
        preprocess: sprite.preprocess


    draw: (renderer) =>
      cq = renderer.cq
      CELL_PIXEL_SIZE = renderer.CELL_PIXEL_SIZE

      for sprite in @getSpriteTemplates()
        {sx: sx, sy: sy, width: width, height: height, dx: dx, dy: dy, spritesheet: spritesheet, tileSize: tileSize, rotation: rotation, preprocess: preprocess} = sprite

        if rotation != 0
          cq.save()
          imageWidth = width * CELL_PIXEL_SIZE
          imageHeight = height * height * CELL_PIXEL_SIZE
          cq.translate((@x + dx) * CELL_PIXEL_SIZE + imageWidth / 2, (@y + dy) * CELL_PIXEL_SIZE + imageHeight / 2)
          cq.rotate(rotation)
          cq.drawImage(spritesheet, sx * tileSize, sy * tileSize, width * tileSize, height * tileSize, -imageWidth / 2, -imageHeight / 2, imageWidth, imageHeight)
          cq.restore()
        else
          # optimize the unrotated case (which are most cases)
          img = getCq(sprite)
          cq.drawImage(img.canvas, (@x + dx) * CELL_PIXEL_SIZE, (@y + dy) * CELL_PIXEL_SIZE)


    initialize: () ->


  Drawable
