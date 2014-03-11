define [
  'backbone'
  'game/drawable'
], (Backbone, Drawable) ->
  # A cell should implement the Drawable interface
  #   which comprises only the spriteLocation method
  class Tile extends Backbone.Model
    initialize: () ->
      @x = @get("cell").get("x")
      @y = @get("cell").get("y")
      @visionInfo = 0 # 0 == unknown, 1 = remembered, 2 = visible

      depOffsets = @dependencies()
      map = @get("cell").get("map")
      depCells = for offset in depOffsets
        loc = {x: @x + offset.x, y: @y + offset.y}
        map.getCell(loc.x, loc.y)
      @dependenciesCollection = new Backbone.Collection(depCells)
      @listenTo(@dependenciesCollection, "change", @recompute)
      @recompute()

    recompute: () =>
      @sprite = null

    # TODO is this method even used anymore?
    spriteLocation: () =>
      if not @sprite
        deps = @dependenciesCollection.map((cell) -> cell.get("type"))
        @sprite = @getSpriteLocation(deps)
      @sprite

    @colliding: false

    # an Array[ {x, y} ]
    dependencies: () ->
      throw "not implemented"

    neighbors: () => [
      { x: -1, y: 0},
      { x: +1, y: 0},
      { x: 0, y: -1},
      { x: 0, y: +1}
    ]

    getSpriteLocation: (deps) ->
      throw "not implemented"

    draw: (renderer) =>
      Drawable::draw.call(this, renderer)

  class Grass extends Tile
    dependencies: () -> []
    getSpriteLocation: (deps) -> { x: 21, y: 4 }

  class DryGrass extends Tile
    dependencies: () => @neighbors()

    maybeGrassSprite: (namedDeps) =>
      left = (namedDeps.left is Grass)
      right = (namedDeps.right is Grass)
      up = (namedDeps.up is Grass)
      down = (namedDeps.down is Grass)
      if left
        if up
          {x: 24, y: 5}
        else if down
          {x: 24, y: 4}
        else
          {x: 22, y: 4}
      else if right
        if up
          {x: 23, y: 5}
        else if down
          {x: 23, y: 4}
        else
          {x: 20, y: 4}
      else if down #we've accounted for down-left and down-right already
        {x: 21, y: 3}
      else if up # same w/ up-left and up-right
        {x: 21, y: 5}
      else
        null

    maybeWallSprite: (namedDeps) =>
      down = (namedDeps.down == Wall)
      if down
        {x: 23, y: 10}
      else
        null

    getSpriteLocation: (deps) =>
      namedDeps = {left: deps[0], right: deps[1], up: deps[2], down: deps[3]}
      @maybeGrassSprite(namedDeps) || @maybeWallSprite(namedDeps) || {x: 21, y: 0}

  class Wall extends Tile
    @colliding: true

    dependencies: () => @neighbors()

    maybeDryGrassSprite: (namedDeps) =>
      down = namedDeps.down is DryGrass
      if down
        {x: 23, y: 13}
      else
        null

    getSpriteLocation: (deps) =>
      namedDeps = {left: deps[0], right: deps[1], up: deps[2], down: deps[3]}
      # [ {x: 22, y: 6}, {x: 23, y: 6}, {x: 22, y: 7}, {x: 23, y: 7} ]
      @maybeDryGrassSprite(namedDeps) || {x: 22, y: 6}

  Tile.DryGrass = DryGrass
  Tile.Grass = Grass
  Tile.Wall = Wall

  Tile
