require [
  'jquery',
  'underscore'
  'backbone'
  'stats'
  'canvasquery'
  'canvasquery.framework'
  'construct'
  'rectangle'
  'map'
  'action'
  'search'
  'game/drawable'
], ($, _, Backbone, Stats, cq, eveline, construct, Rectangle, Map, Action, Search, Drawable) ->

  'use strict'

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  Math.distance = (a, b) ->
    Math.abs(a.x - b.x) + Math.abs(a.y - b.y)


  #
  #
  #
  #
  # class CollisionBox
  #   constructor: (@owner, @pt, @localRectangles) ->
  #   converted: (pt = @pt) => rectangles relative to pt
  #
  #
  #
  # # A class to handle a set of boxes (comprised of a list of rectangles)
  # # The invariant to be held is that no box intersects with any other box
  # # That is, for every pair of boxes b1, b2
  # #   for every rectangle r1 in b1 and r2 in b2
  # #     intersects(r1, r2) == false
  # #
  # # Internally holds a 2D grid of Box references; the grid reference at (x, y) points to the box occupying that location
  # class CollisionLayer
  #   constructor: (world)
  #     @boxCache = for y in [0...world.width]
  #       for x in [0...world.height]
  #         null
  #
  #   # Adds a box to the list of boxes to collide with
  #   # This method will actually move the box to the closest pt that it can fit into
  #   putBox: (box) => : Boolean
  #     for rect in box.converted
  #       for pt in rect.points
  #         boxAt = collisionBoxAt(pt.x, pt.y)
  #         if boxAt isnt null and boxAt isnt box
  #           # this position isn't good; scoot it into another position
  #
  #
  #   # O(1), *the* optimized method
  #   # returns the CollisionBox at the given location
  #   collisionBoxAt: (x, y) => : CollisionBox | null
  #     return @boxCache[y][x]
  #
  #
  # World:
  #
  # Entity:
  #   constructor: (pt) ->
  #     # Each Entity has exactly one Collision Box
  #     @collisionBox = @createCollisionBox()
  #     couldPut = collisionLayer.putBox(@collisionBox)
  #     throw new Cannot("Overlapping Entities") if not couldPut
  #
  #   pt: () => @collisionBox.pt
  #
  #   @collisionBoxPrototype = [{x: 0, y: 0, width: 1, height: 1}]
  #
  #   createCollisionBox: (pt) => return new CollisionBox(this, pt, constructor.collisionBoxPrototype)
  #






  ###
  #
  # Cell extending Backbone.Events to hold
  # cell type (which in turn controls occupied, sprite, etc.)
  #
  # Backbone library is there; requireConfig not setup; not imported yet
  #
  # Need to find codebase that touches Cell and make it work with Cell, which is a
  # a mutable container Cell with eventing; instead of "replacing"
  # the current cell with a new cell, update the "cell type" of the cell
  # at the given location
  #
  #
  #
  # # Has a "cell" Cell which it lives in
  # class Tile extends Backbone.Model
  #   initialize: () ->
  #     cell = @get("cell")
  #     {x: x, y: y} = cell
  #     @dependenciesCollection = new Backbone.Collection(dependencies())
  #     @listenTo(@dependenciesCollection, "change", @recompute)
  #     @recompute()
  #
  #   dependencies: () ->
  #     throw "not implemented"
  #
  #   recompute: () ->
  #     sprite = @getSpriteLocation()
  #     @cell.set("spriteLocation", sprite)
  #
  #   getSpriteLocation: (deps) ->
  #     throw "not implemented"
  #
  #   @colliding: false
  #
  # class DryGrass extends Tile
  #   dependencies: () ->
  #   [
  #                             @get("cell").world.cellAt(x - 1, y)
  #                             @get("cell").world.cellAt(x + 1, y)
  #                             @get("cell").world.cellAt(x, y - 1)
  #                             @get("cell").world.cellAt(x, y + 1)
  #   ]
  #
  #   getSpriteLocation: (deps) ->
  #     left = deps.at(0)
  #     return {x: 12, y: 26}
  #
  #
  #
  # new DryGrass({cell: this})
  #
  #
  #
  # Tile API:
  #   to create a new type of tile:
  #     call Tile.extend({ dependencies, getSpriteLocation }, {colliding: true or false (default false) })
  #
  #   to use Tiles, you need to: construct with new tileType({cell: cell})
  #                kill tiles with tile.stopListening()
  #
  #   you get:
  #     cell.spriteLocation's invariant is upheld: is always reflective of calling
  #     spriteLocation() on the current cell always
  #     draw: (cq) =>
  #
  # Cell API:
  #   you need to: construct new Cell({x, y}) # DO NOT pass in a type to begin with!
  #                set tiles with cell.set("tile", tile)
  #
  #   you get:
  #     tile pathing matrix's invariant is held: it's the same value as if you called
  #     computeMatrixFromScratch() whenever you needed matrix
  #
  ###

  class World
    constructor: (@width, @height, tileTypeFor) ->
      @age = 0
      @map = new Map(@, tileTypeFor)

      @entities = []
      @addEntity(new House(10, 10))
      @human = @addEntity(new Human(10, 11))

    addEntity: (entity) =>
      entity.world = this
      entity.birth = @age
      @entities.push(entity)
      entity.initialize()
      entity

    removeEntity: (entity) =>
      idx = @entities.indexOf(entity)
      @entities.splice(idx, 1)
      entity

    withinMap: (x, y) => @map.withinMap(x, y)

    isUnoccupied: (x, y, ignoredEntity = null) =>
      return false if not @withinMap(x, y)
      return false if @map.getCell(x, y).get("type").colliding
      return false if @entityAt(x, y) isnt null and @entityAt(x, y) isnt ignoredEntity
      return true

    # TODO make this O(1) by caching entityAt's and only updating them
    # when an Entity moves
    entityAt: (x, y) =>
      return null if not @withinMap(x, y)

      for e in @entities
        rect = e.getHitbox()
        if rect.within(x, y)
          return e

      return null




    stepAll: () =>
      $(this).trigger("prestep")
      for entity in @entities
        entity.step()
      $(this).trigger("poststep")
      @age += 1

    drawAll: (cq) =>
      # ((cell.draw(cq) for cell in row) for row in @map)
      # for entity in @entities
      #   entity.draw(cq)
      cell.draw(cq) for cell in @human.getVisibleTiles()
      for entity in @human.getVisibleEntities()
        entity.draw(cq)

      cq.context.globalAlpha = 0.5
      # now draw only the remembered ones
      cell.draw(cq) for cell in @human.rememberedTiles
      e.draw(cq) for e in @human.rememberedEntities

      cq.context.globalAlpha = 1.0



  class Grass extends Map.Tile
    dependencies: () -> []
    getSpriteLocation: (deps) -> { x: 21, y: 4 }

  class DryGrass extends Map.Tile
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

  class Wall extends Map.Tile
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

  class Entity extends Drawable
    constructor: (@x, @y) ->
      super(@x, @y)

    # Only move Entities through this method
    move: (offset) =>
      @setLocation(@x + offset.x, @y + offset.y)

    setLocation: (x, y) =>
      if @canOccupy(x, y)
        @world.map.notifyLeaving(this, x, y)
        @x = x
        @y = y
        @world.map.notifyEntering(this, x, y)
        @checkConsistency()

    age: () => @world.age - @birth

    distanceTo: (cell) =>
      Math.distance(cell, this)

    findTilesWithin: (manhattanDist) =>
      _.flatten((cell.tileInstance for cell in row when @distanceTo(cell.tileInstance) <= manhattanDist) for row in @world.map.cells)

    findEntitiesWithin: (manhattanDist) =>
      _.filter(@world.entities, (e) => @distanceTo(e) <= manhattanDist)

    checkConsistency: () =>
      throw "bad position" unless @world.withinMap(@x, @y)
      # throw "on top of another entity" if @world.entityAt(@x, @y) isnt this

    isDead: () => not _.contains(@world.entities, this)

    die: () =>
      $(@world).one("poststep", () =>
        @world.removeEntity(this)
      )

    # optionally, declare a hitbox VALUE on the class
    # hitbox is an {x, y, width, height} which specifies how far left and up the hitbox should go, and its width/height (by default 1/1)
    @hitbox: {x: 0, y: 0, width: 1, height: 1}

    # returns a (x, y, width, height) associated with a specified pt (by default this Entity's location)
    getHitbox: (x = @x, y = @y) =>
      hitbox = @constructor.hitbox
      new Rectangle(x + hitbox.x, y + hitbox.y, hitbox.width || 1, hitbox.height || 1)

    # returns true iff this Entity can occupy the given location
    canOccupy: (x, y, world = @world) =>
      rect = @getHitbox(x, y)
      return _.every(rect.allPoints(), (pt) ->
        world.isUnoccupied(pt.x, pt.y, this)
      )


    step: () => throw "not implemented"


  class House extends Entity
    spriteLocation: () => [
      { x: 1, y: 16, dx:  0, dy:  0 }
      { x: 0, y: 15, dx: -1, dy:  0 }
      { x: 5, y: 13, dx:  0, dy: -1 }
      { x: 4, y: 13, dx: -1, dy: -1 }
    ]

    getFreeBeds: (human) =>
      beds = [{ x: @x + 1, y: @y},
              { x: @x, y: @y + 1}]
      _.filter(beds, (pt) => @world.isUnoccupied(pt.x, pt.y, human))

    @hitbox: {x: -1, y: -1, width: 2, height: 2}

    step: () =>

  class Food extends Entity
    constructor: (@x, @y) ->
      super(@x, @y)
      @amount = 300

    consume: (amount) =>
      @amount -= amount
      if @amount <= 0
        @die()

    step: () =>

    spriteLocation: () =>
      x: 14
      y: 15

  # Tasks can be seen as Action generators/iterators/streams
  class Task
    constructor: (@human, nextAction = undefined, isComplete = undefined, toString = undefined) ->
      @nextAction = nextAction if nextAction
      @isComplete = isComplete if isComplete
      @toString = toString if toString

    # Returns the next Action to take for this Task
    # invariant: nextAction() is only called when isComplete() is false
    nextAction: () => throw "Not implemented"
    # returns true/false
    isComplete: () => throw "not implemented"

    # compose this task with another task
    andThen: (@task) =>
      return new TaskList(@human, [this, @task])

    toString: () => @constructor.name

  # A list of Tasks; you do the list by finishing each
  # task sequentially
  class TaskList extends Task
    constructor: (@human, @subtasks) ->
      super(@human)
    isComplete: () => _.every(@subtasks, (task) => task.isComplete())

    currentTask: () => @subtasks[0]

    nextAction: () =>
      # trim off completed actions
      while @currentTask().isComplete()
        @subtasks.shift()
      return @currentTask().nextAction()

    toString: () => @currentTask().toString()

  class WalkTo extends Task

    constructor: (@human, @pt, @distanceThreshold) ->
      super(@human)
      @pt = _.pick(@pt, "x", "y")
      throw "Point is actually a #{@pt}" unless (_.isNumber(@pt.x) && _.isNumber(@pt.y))
      if @distanceThreshold is 0 and not @human.canOccupy(@pt.x, @pt.y)
        console.log("cannot occupy that space!")
        @actions = []
      else
        @actions =
          if @distanceThreshold > 0
            Search.findPath(
              @human,
              (cell) => Math.distance(cell, @pt) <= @distanceThreshold
            )
          else
            Search.findPathTo(@human, @pt)
        if not @actions
          console.log("no path!")
          @actions = []
        # throw "no path!" unless @actions

    isComplete: () => _.isEmpty(@actions)

    nextAction: () =>
      return @actions.shift()

  class Consume extends Task
    constructor: (@human, @food) ->
      super(@human)
    isComplete: () => @food.amount <= 0 or @human.hunger <= 0

    nextAction: () =>
      return new Action.Consume(@food)

  class Eat extends TaskList
    constructor: (@human, @food) ->
      super(@human, [new WalkTo(@human, @food, 1), new Consume(@human, @food)])

  class GoHome extends WalkTo
    constructor: (@human) ->
      # find closest free bed and sleep
      openHouse = _.find(
        _.filter(@human.getKnownEntities(),
          (b) -> b instanceof House),
        (b) => not _.isEmpty(b.getFreeBeds(@human)))

      closestBed = _.min(openHouse.getFreeBeds(@human), @human.distanceTo)

      super(@human, closestBed, 0)

  class Sleep extends Task
    constructor: (@human) ->
      super(@human)

    isComplete: () => @human.tired <= 0
    nextAction: () => new Action.Sleep()

  # returns an Entity or null if you can't build there
  tryConstruct = (human, entityType, args) ->
    entity = construct(entityType, args)
    if entity.canOccupy(entity.x, entity.y, human.world)
      entity
    else
      null

  class Build extends Task
    constructor: (@human, @entity) ->
      super(@human)
      # Optimally we would have a "tryBuild" method that returns
      # the Build task if successful, or otherwise returns null
      #
      # you could have a generic tryTask method like:
      #
      # tryTask(@human, Build, construct)
      #
      # its implementation would wrap the constructor call in a try BadTask/catch,
      # and then the protocol is to have Task constructors throw BadTask
      #
      # instead we'll just ad-hoc some way to not actually "build" the building for now
      if @entity
        @turnsLeft = 10
      else
        # make this task already isComplete(), so nextAction() should never be called
        @turnsLeft = 0

    class BuildAction extends Action
      constructor: (@buildTask) ->
      perform: (human) ->
        @buildTask.turnsLeft -= 1
        human.tired += 2
        human.hunger += 1
        if @buildTask.isComplete()
          entity = @buildTask.entity
          human.world.addEntity(entity)

    isComplete: () => @turnsLeft == 0
    nextAction: () => new BuildAction(this)

  class Human extends Entity
    constructor: (@x, @y) ->
      super(@x, @y)
      @sightRange = 10

      # How hungry you are.
      @hunger = 0

      # How tired you are. Will affect your action taking capabilities if you're too tired
      @tired = 0

      # Your current task
      @currentTask = null

      # Should be the last Action you took; used by the Renderer to display info about what you're doing
      @currentAction = new Action.Rest()

      @visibleTilesCache = null
      @visibleEntitiesCache = null

      # The class of where you're facing
      @facing = Action.Down

    initialize: () =>
      # All cells you have seen previously, but cannot currently see
      @rememberedTiles = []
      # All entities you have seen previously, but cannot currently see
      @rememberedEntities = []

      lastVisibleTiles = []
      lastVisibleEntities = []
      $(@world).on("prestep", () =>
        lastVisibleTiles = @getVisibleTiles()
        lastVisibleEntities = @getVisibleEntities()
      )
      $(@world).on("poststep", () =>
        # to update the rememberedTiles
        # 1. remove cells remembered last frame but visible now
        # 2. add in cells visible last frame but not visible now
        # this is still O( # of remembered cells )! Uh oh
        @rememberedTiles = _.difference(@rememberedTiles, @getVisibleTiles())

        @rememberedTiles = @rememberedTiles.concat(_.difference(lastVisibleTiles, @getVisibleTiles()))

        # to update seenEntities
        # 1. remove entities remembered last frame that *should* be visible now but aren't
        # 2. remove entities remembered last frame but visible now
        # 3. add in entities visible last frame but not visible now
        @rememberedEntities = _.reject(@rememberedEntities, (entity) =>
          @distanceTo(entity) <= @sightRange and not _.contains(@getVisibleEntities(), entity)
        )

        # O( # of remembered entities ) <-- this is better but could be bad
        @rememberedEntities = _.difference(@rememberedEntities, @getVisibleEntities())
        @rememberedEntities = @rememberedEntities.concat(_.difference(lastVisibleEntities, @getVisibleEntities()))
      )


    getVisibleTiles: () =>
      recomputeVisibleTiles = () => @findTilesWithin(@sightRange)
      if not @visibleTilesCache
        @visibleTilesCache = recomputeVisibleTiles()
      @visibleTilesCache

    getVisibleEntities: () =>
      recomputeVisibleEntities = () => @findEntitiesWithin(@sightRange)
      if not @visibleEntitiesCache
        @visibleEntitiesCache = recomputeVisibleEntities()
      @visibleEntitiesCache

    getKnownEntities: () =>
      @rememberedEntities.concat(@getVisibleEntities())


    closestKnown: (entityType) =>
      entities = _.filter(@getKnownEntities(), (e) -> e instanceof entityType)
      if not _.isEmpty(entities)
        _.min(entities, @distanceTo)
      else
        null

    # returns an array of () => (Task or falsy)
    possibleTasks: () =>
      tasks = [ () => @currentTask ]

      if @hunger > 300
        tasks.push( () =>
          closestFood = @closestKnown(Food)
          if closestFood
            new Eat(this, closestFood)
          else
            false
        )

      if @tired > 200
        tasks.push( () =>
          (new GoHome(this)).andThen(new Sleep(this))
        )

      tasks

    getAction: () =>
      tasks = @possibleTasks()

      # find the first task that isn't complete and start doing it
      for taskFn in tasks
        task = taskFn()
        if task && not task.isComplete()
          doableTask = task
          break
      if doableTask
        @currentTask = doableTask
        @currentTask.nextAction()
      else
        @currentTask = null
        return new Action.Rest()

    step: () =>
      action = @getAction()
      action.perform(this)
      @currentAction = action
      if @currentTask && @currentTask.isComplete()
        @currentTask = null
      @visibleTilesCache = null
      @visibleEntitiesCache = null

    spriteLocation: () =>
      spriteIdx = (@animationMillis() / 333) % 4 | 0
      spriteInfo =
        x: [10, 9, 10, 11][spriteIdx]
        y: {Down: 4, Left: 5, Right: 6, Up: 7}[@facing.direction]
        spritesheet: "characters"

      if not (@currentAction instanceof Action.Rest) and not (@currentAction instanceof Action.Sleep)
        spriteInfo.dx = @facing.offset.x * .2
        spriteInfo.dy = @facing.offset.y * .2

      if @currentAction instanceof Action.Sleep
        spriteInfo = _.extend(spriteInfo,
          x: 10
          y: 6
          rotation: 90
        )

      spriteInfo

    draw: (cq) =>
      super(cq)
      CELL_PIXEL_SIZE = cq.CELL_PIXEL_SIZE
      actionString = if @currentAction.toString() then @currentAction.toString() + ", " else ""
      taskString = if @currentTask then @currentTask.toString() + ", " else ""
      text = "#{taskString}#{@hunger | 0} hunger, #{@tired | 0} tired"
      cq.fillStyle("red").font('normal 20pt arial').fillText(text, @x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE)


  setupWorld = () ->
    world = new World(60, 60, (x, y) ->
      if y % 12 <= 1 && (x + y) % 30 > 5
        Wall
      else if Math.sin(x*y / 100) > .90
        Grass
      else
        DryGrass
    )
    for x in [0...world.width]
      for y in [0...world.height] when Math.sin((x + y) / 8) * Math.cos((x - y) / 9) > .9
        if world.isUnoccupied(x, y)
          food = new Food(x, y)
          world.addEntity(food)

    world

  setupDebug = (framework) ->
    {world: world, renderer: renderer} = framework
    statsStep = new Stats()
    statsStep.setMode(0)
    statsStep.domElement.style.position = 'absolute'
    statsStep.domElement.style.left = '0px'
    statsStep.domElement.style.top = '0px'

    statsRender = new Stats()
    statsRender.setMode(0)
    statsRender.domElement.style.position = 'absolute'
    statsRender.domElement.style.left = '0px'
    statsRender.domElement.style.top = '50px'

    $(world).on('prestep', () -> statsStep.begin())
    $(world).on('poststep', () -> statsStep.end())
    $(world).on('prerender', () -> statsRender.begin())
    $(world).on('postrender', () -> statsRender.end())

    $("body").append( statsStep.domElement )
    $("body").append( statsRender.domElement )


  class Renderer
    CELL_PIXEL_SIZE = 32
    constructor: (@world) ->
      @camera = {
        x: 0
        y: 0
      }

    render: (cq, keys, mouseX, mouseY) =>
      # oh god this is so bad
      cq.CELL_PIXEL_SIZE = CELL_PIXEL_SIZE
      $(@world).trigger("prerender")

      mapping = {
        w: () => @camera.y += 1
        s: () => @camera.y -= 1
        a: () => @camera.x += 1
        d: () => @camera.x -= 1
      }

      for key, fn of mapping
        fn() if keys[key]
      cq.clear("black")
      cq.save()
      cq.translate(@camera.x * CELL_PIXEL_SIZE, @camera.y * CELL_PIXEL_SIZE)
      @world.drawAll(cq)


      pt = @cellPosition(mouseX, mouseY)
      if @world.human.canOccupy(pt.x, pt.y) then cq.fillStyle("green") else cq.fillStyle("red")
      cq.globalAlpha(0.5).fillRect(pt.x * CELL_PIXEL_SIZE, pt.y * CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)
      cq.restore()

      $(@world).trigger("postrender")

    cellPosition: (canvasX, canvasY) =>
      x: canvasX / CELL_PIXEL_SIZE - @camera.x | 0
      y: canvasY / CELL_PIXEL_SIZE - @camera.y | 0




  framework = {
    setup: () ->
      @world = setupWorld()
      @renderer = new Renderer(@world)

      @keys = {}
      @mouseX = 0
      @mouseY = 0

      @cq = cq().framework(this, this)
      @cq.canvas.oncontextmenu = () -> false
      @cq.appendTo("body")

      setupDebug(this)

    onstep: (delta, time) ->
      @world.stepAll()

    stepRate: 20

    onrender: () ->
      @renderer.render(@cq, @keys, @mouseX, @mouseY)

    # window resize
    onresize: (width, height) ->
      # resize canvas with window
      # change camera transform
      if @cq
        @cq.canvas.height = height
        @cq.canvas.width = width

    # clickedBehavior: (x, y) ->
    #   entity = @world.entityAt(x, y)
    #   if entity isnt null
    #     {
    #       House: () => new
    #     }

    onmousedown: (x, y, button) ->
      pt = @renderer.cellPosition(x, y)
      if @world.human.canOccupy(pt.x, pt.y)
        @world.human.currentTask = new WalkTo(@world.human, pt, 0)

    onmousemove: (x, y) ->
      @mouseX = x
      @mouseY = y

    onmousewheel: (delta) ->
      # CELL_PIXEL_SIZE *= Math.pow(1.05, delta)

    # keyboard events
    onkeydown: (key) ->
      @keys[key] = true
      if key is 'b'
        pt = @renderer.cellPosition(@mouseX, @mouseY)
        house = tryConstruct(@world.human, House, [pt.x, pt.y])
        if house
          # TODO this is only a preventative measure
          # need to add the actual logic inside the Task itself to ensure that it doesn't happen
          @world.human.currentTask = (new WalkTo(@world.human, pt, 1).andThen(new Build(@world.human, house)))
      else if key is 'h'
        @world.human.currentTask = new GoHome(@world.human)

    onkeyup: (key) ->
      delete @keys[key]
  }

  $(() ->
    framework.setup()
  )
