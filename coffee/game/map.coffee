define [
  'backbone'
  'rectangle'
  'game/drawable'
  'game/action'
  'search'
], (Backbone, Rectangle, Drawable, Action, Search) ->

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

    # returns true iff this Entity can occupy the given location
    # assumes the Entity is already in the world
    #
    # It does this by asking if the entity could be added to the place if it wasn't already on the map
    # (to prevent self-collisions)
    canOccupy: (entity, x, y) =>
      throw "Entity not in the world" unless entity.world is @world
      @notifyLeaving(entity)
      hasRoom = @hasRoomFor(entity, x, y)
      @notifyEntering(entity)
      hasRoom

    # returns true iff the given point is free to be occupied by anybody
    isUnoccupied: (x, y) =>
      return false if not @withinMap(x, y)
      unoccupied = not (!!@pathfindingMatrix[y][x])
      return unoccupied

    # returns whether this map could fit rect, if it were added to the world at the given location
    # Call this to check availability of adding an Entity that isn't in the world yet
    hasRoomFor: (entity, x = entity.x, y = entity.y) =>
      _.every(entity.getHitbox(x, y).allPoints(), (pt) =>
        @isUnoccupied(pt.x, pt.y)
      )

    setTile: (x, y, tileType) =>
      if @withinMap(x, y)
        @cells[y][x].set("type", tileType)
        @pathfindingMatrix[y][x] = if tileType.colliding then 1 else 0

    getCell: (x, y) =>
      if @withinMap(x, y)
        @cells[y][x]
      else
        null

    # Assumes entity is in world
    closestAvailableSpot: (entity, wantedPt) ->
      # keep a fringe of possible spots that you haven't checked yet; this fringe
      # is sorted by distance so the closest ones will always be popped off first (it's a queue)
      #
      queue = [wantedPt]
      visited = {} # keys are JSON.stringify({x, y}) objects
      while not _.isEmpty(queue)
        pt = queue.shift()

        continue if visited[JSON.stringify(pt)]
        visited[JSON.stringify(pt)] = true

        if entity.canOccupy(pt.x, pt.y)
          return pt
        else
          for action in Action.Directionals
            nextPt = {x: pt.x + action.offset.x, y: pt.y + action.offset.y}
            queue.push(nextPt)

      return null

    notifyLeaving: (entity) =>
      for pt in entity.getHitbox().allPoints()
        @pathfindingMatrix[pt.y][pt.x] = 0

    notifyEntering: (entity) =>
      for pt in entity.getHitbox().allPoints()
        if @pathfindingMatrix[pt.y][pt.x]
          throw "#{entity} entering on an already occupied location!"
        @pathfindingMatrix[pt.y][pt.x] = 1


  Map.Tile = Tile

  Map
