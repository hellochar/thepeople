define [
  'backbone'
  'rectangle'
], (Backbone, Rectangle) ->

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
      @bounds = new Rectangle(0, 0, @width - 1, @height - 1)
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

  Map
