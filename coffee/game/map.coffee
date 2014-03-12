define [
  'backbone'
  'rectangle'
  'game/drawable'
  'game/action'
  'game/tile'
  'game/entity'
  'search'
], (Backbone, Rectangle, Drawable, Action, Tile, Entity, Search) ->

  # {x, y, type which is a Tile constructor}
  class Cell
    constructor: (@x, @y, @map, type) ->
      @setType(type)

    setType: (type) =>
      @type = type
      @tileInstance = new type(@x, @y)

  class Map
    constructor: (@world) ->
      @width = @world.width
      @height = @world.height
      @bounds = new Rectangle(0, 0, @width, @height)
      @cells =
        for y in [ 0...@height ]
          for x in [ 0...@width ]
            new Cell(x, y, this, Tile.DryGrass)

      # entry at <x, y> is an Entity, 1 or 0
      @pathfindingMatrix =
        for y in [ 0...@height ]
          for x in [ 0...@width ]
            0

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
        previouslyCollided = @cells[y][x].type?.colliding || 0
        entityHere = @pathfindingMatrix[y][x] instanceof Entity
        # entity exists, previouslyCollided       -> shouldn't ever happen
        # entity exists, not previouslyCollided -> update type, don't touch pathfindingMatrix
        # entity doesn't exist, previouslyCollided -> update pathfindingMatrix
        # entity doesn't exist, not previouslyCollided -> update pathfindingMatrix
        @cells[y][x].setType(tileType)
        if entityHere
          if previouslyCollided
            throw "bad!"
          else
            "do nothing"
        else
          @pathfindingMatrix[y][x] = if tileType.colliding then 1 else 0

    getCell: (x, y) =>
      if @withinMap(x, y)
        @cells[y][x]
      else
        null

    # Assumes entity is in world
    # Returns the closest location to wantedPt that entity can walk to
    closestWalkablePath: (entity, wantedPt) ->
      # "wave expansion" outward from wantedPt, check the perimeter of the wave
      # at every iteration for the closest spot you can walk to
      # if no walkable spots make the wave bigger
      perimeter = [wantedPt]
      visited = {} # keys are JSON.stringify({x, y}) objects
      while not _.isEmpty(perimeter)
        # array of [pt, array of actions]
        paths = []

        for pt in perimeter
          try
            if entity.canOccupy(pt.x, pt.y)
              paths.push([pt, Search.findPathTo(entity, pt)])
          catch err
            if err is Search.NoSolution
              "no-op"
            else
              throw err

        if not _.isEmpty(paths)
          shortestPath = _.min(paths, (path) -> path[1].length)
          return shortestPath[0]
        else
          newPerimeter = []
          visited[JSON.stringify(pt)] = true for pt in perimeter
          for pt in perimeter
            for action in Action.Directionals
              nextPt = {x: pt.x + action.offset.x, y: pt.y + action.offset.y}
              continue if visited[JSON.stringify(nextPt)]
              newPerimeter.push(nextPt)
          perimeter = newPerimeter

      # Technically this should never happen since the search should eventually reach the point the entity's at now
      throw "oh god it happened"

    notifyLeaving: (entity) =>
      for pt in entity.getHitbox().allPoints()
        @pathfindingMatrix[pt.y][pt.x] = 0

    notifyEntering: (entity) =>
      for pt in entity.getHitbox().allPoints()
        if @pathfindingMatrix[pt.y][pt.x]
          throw "#{entity} entering on an already occupied location!"
        @pathfindingMatrix[pt.y][pt.x] = entity

  Map
