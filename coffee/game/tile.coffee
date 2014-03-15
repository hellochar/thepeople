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

  class Grass extends Tile
    spriteLocation: () -> { x: 21, y: 4 }

  class DryGrass extends Tile
    spriteLocation: () -> {x: 21, y: 0}

  class Wall extends Tile
    @colliding: true
    spriteLocation: () -> {x: 22, y: 6}

  Tile.DryGrass = DryGrass
  Tile.Grass = Grass
  Tile.Wall = Wall

  Tile
