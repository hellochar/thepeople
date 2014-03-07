define [
], () ->
  class Spritesheets
    @mapping: {}

    @get: (name) ->
      if not @mapping[name]
        s = new Image()
        s.src = "/images/spritesheets/#{name}.png"
        @mapping[name] = s
      @mapping[name]

  class Drawable
    constructor: (@x, @y) ->
      @timeCreated = Date.now()

    animationMillis: () => Date.now() - @timeCreated

    # {
    #   -- sprite sheet location
    #   x, y,
    #
    #   -- dimensions of the sprite sheet cells
    #   width: 1, height: 1
    #
    #   -- offset to draw on the map
    #   dx: 0 (float)
    #   dy: 0 (float)
    #
    #
    #   -- rotation (ccw in degrees)
    #   rotation: 0
    #
    #   spritesheet: "tiles1"
    # }
    # or an array of those objects
    spriteLocation: () => throw "not implemented"

    draw: (cq) =>
      CELL_PIXEL_SIZE = cq.CELL_PIXEL_SIZE
      sprites = @spriteLocation()
      if not _.isArray(sprites)
        sprites = [sprites]

      for sprite in sprites
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

        if rotation != 0
          cq.save()
          imageWidth = width * CELL_PIXEL_SIZE
          imageHeight = height * height * CELL_PIXEL_SIZE
          cq.translate((@x + dx) * CELL_PIXEL_SIZE + imageWidth / 2, (@y + dy) * CELL_PIXEL_SIZE + imageHeight / 2)
          cq.rotate(rotation)
          cq.drawImage(spritesheet, sx * tileSize, sy * tileSize, width * tileSize, height * tileSize, -imageWidth / 2, -imageHeight / 2, imageWidth, imageHeight)
          cq.restore()
        else
          # optimize the unrotated case (which is most cases)
          cq.drawImage(spritesheet, sx * tileSize, sy * tileSize, width * tileSize, height * tileSize, (@x + dx) * CELL_PIXEL_SIZE, (@y + dy) * CELL_PIXEL_SIZE, width * CELL_PIXEL_SIZE, height * CELL_PIXEL_SIZE)


    initialize: () ->


  Drawable
