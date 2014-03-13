define [
  'backbone'
  'game/drawable'
], (Backbone, Drawable) ->
  # A cell should implement the Drawable interface
  #   which comprises only the spriteLocation method
  class Tile extends Drawable

    @colliding: false

    constructor: (@x, @y) ->
      super(@x, @y)
      @visionInfo = 0 # 0 == unknown, 1 = remembered, 2 = visible

    recompute: () =>
      @sprite = null

    # TODO is this method even used anymore?
    spriteLocation: () =>
      if not @sprite
        @sprite = @getSpriteLocation()
      @sprite

    getSpriteLocation: () ->
      throw "not implemented"

  class Grass extends Tile
    getSpriteLocation: () -> { x: 21, y: 4 }

  class DryGrass extends Tile
    getSpriteLocation: () -> {x: 21, y: 0}

  class Wall extends Tile
    @colliding: true
    getSpriteLocation: () -> {x: 22, y: 6}

  Tile.DryGrass = DryGrass
  Tile.Grass = Grass
  Tile.Wall = Wall

  Tile
