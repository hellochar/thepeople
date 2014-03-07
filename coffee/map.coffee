define [
  'backbone'
  'rectangle'
  'game/drawable'
], (Backbone, Rectangle, Drawable) ->

  # A cell should implement the Drawable interface
  #   which comprises only the spriteLocation method
  class Tile extends Backbone.Model
    initialize: () ->
      @x = @get("cell").get("x")
      @y = @get("cell").get("y")

      depOffsets = @dependencies()
      map = @get("cell").get("map")
      depCells = for offset in depOffsets
        loc = {x: @x + offset.x, y: @y + offset.y}
        map.getCell(loc.x, loc.y)
      @dependenciesCollection = new Backbone.Collection(depCells)
      @listenTo(@dependenciesCollection, "change", @recompute)
      @recompute()

    recompute: () =>
      deps = @dependenciesCollection.map((cell) -> cell.get("type"))
      @sprite = @getSpriteLocation(deps)

    # TODO is this method even used anymore?
    spriteLocation: () =>
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

    draw: (cq) =>
      Drawable::draw.call(this, cq)


  # {x, y, type which is a Tile constructor}
  class Cell extends Backbone.Model
    initialize: () =>
      @listenTo(this, "change:type", (model, type, opts) =>
        if @tileInstance
          @tileInstance.stopListening()
        @tileInstance = new type({cell: this})
      )

  class Map
    constructor: (@world, tileTypeFor) ->
      @width = @world.width
      @height = @world.height
      @bounds = new Rectangle(0, 0, @width, @height)
      @cells =
        for y in [ 0...@height ]
          for x in [ 0...@width ]
            new Cell({x: x, y: y, map: this})

      @pathfindingMatrix =
        for y in [ 0...@height ]
          for x in [ 0...@width ]
            0

      for y in [ 0...@height ]
        for x in [ 0...@width ]
          @setTile(x, y, tileTypeFor(x, y))

    withinMap: (x, y) => @bounds.within(x, y)

    setTile: (x, y, tileType) =>
      if @withinMap(x, y)
        @cells[y][x].set("type", tileType)
        @pathfindingMatrix[y][x] = if tileType.colliding then 1 else 0

    getCell: (x, y) =>
      if @withinMap(x, y)
        @cells[y][x]
      else
        null

    notifyLeaving: (entity) =>
      for pt in entity.getHitbox().allPoints()
        @pathfindingMatrix[pt.y][pt.x] = 0

    notifyEntering: (entity) =>
      for pt in entity.getHitbox().allPoints()
        @pathfindingMatrix[pt.y][pt.x] = 1


  Map.Tile = Tile

  Map
