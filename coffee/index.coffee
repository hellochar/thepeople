window.asdf = (x, y) ->
  [(x/32) | 0, (y/32) | 0]

require [
  'jquery',
  'underscore'
  'stats'
  'canvasquery'
  'canvasquery.framework'
  'construct'
  'action'
], ($, _, Stats, cq, eveline, construct, Action) ->

  'use strict'

  withinRect = (x, y, xmin, xmax, ymin, ymax) ->
    return (x >= xmin && x <= xmax && y >= ymin && y <= ymax)

  intersectRect = (r1, r2) ->
    return !(r2.x > r1.x + r1.width ||
             r2.x + r2.width < r1.x ||
             r2.y > r1.height + r1.y ||
             r2.height + r2.y < r1.y)

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  Math.distance = (a, b) ->
    Math.abs(a.x - b.x) + Math.abs(a.y - b.y)

  CELL_PIXEL_SIZE = 32

  class World
    constructor: (@width, @height, @cellFor) ->
      @age = 0
      @map = ((@cellFor(x, y) for x in [ 0...@width ]) for y in [ 0...@height ])
      ((cell.world = this for cell in row) for row in @map)
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

    withinMap: (x, y) => withinRect(x, y, 0, @width - 1, 0, @height - 1)

    getCell: (x, y) =>
      if @withinMap(x, y)
        @map[y][x]
      else
        null

    isUnoccupied: (x, y, ignoredEntity = null) =>
      return false if not @withinMap(x, y)
      return false if @getCell(x, y).constructor.colliding
      return false if @entityAt(x, y) isnt null and @entityAt(x, y) isnt ignoredEntity
      return true

    # TODO make this O(1) by caching entityAt's and only updating them
    # when an Entity moves
    entityAt: (x, y) =>
      return null if not @withinMap(x, y)

      for e in @entities
        hitboxes = e.getHitboxes()
        for rect in hitboxes
          if withinRect(x, y, rect.x, rect.x + rect.width - 1, rect.y, rect.y + rect.height - 1)
            return e

      return null




    stepAll: () =>
      $(this).trigger("prestep")
      for entity in @entities
        entity.step()
        entity.checkConsistency()
      $(this).trigger("poststep")
      @age += 1

    drawAll: (cq) =>
      # ((cell.draw(cq) for cell in row) for row in @map)
      # for entity in @entities
      #   entity.draw(cq)
      cell.draw(cq) for cell in @human.getVisibleCells()
      entity.draw(cq) for entity in @human.getVisibleEntities()

      cq.context.globalAlpha = 0.5
      # now draw only the remembered ones
      cell.draw(cq) for cell in @human.rememberedCells
      e.draw(cq) for e in @human.rememberedEntities

      cq.context.globalAlpha = 1.0


  class Spritesheets
    @mapping: {}

    @get: (name, tileSize = 32) ->
      if not @mapping[name]
        s = new Image()
        s.src = "/images/spritesheets/#{name}.png"
        @mapping[name] = s
      @mapping[name]

  class Drawable
    constructor: (@x, @y) ->
      @timeCreated = new Date().valueOf()

    animationMillis: () => (new Date()).valueOf() - @timeCreated

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
    #   spritesheet: "tiles1"
    # }
    # or an array of those objects
    spriteLocation: () => throw "not implemented"

    draw: (cq) =>
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
        cq.drawImage(spritesheet, sx * tileSize, sy * tileSize, width * tileSize, height * tileSize, (@x + dx) * CELL_PIXEL_SIZE, (@y + dy) * CELL_PIXEL_SIZE, width * CELL_PIXEL_SIZE, height * CELL_PIXEL_SIZE)

    initialize: () ->


  class Cell extends Drawable
    constructor: (@x, @y) ->
      super(@x, @y)

    @colliding: false

  class Grass extends Cell
    constructor: (@x, @y) ->
      super(@x, @y)

    spriteLocation: () => { x: 21, y: 4 }

  class DryGrass extends Cell
    constructor: (@x, @y) ->
      super(@x, @y)

    maybeGrassSprite: () =>
      left = (@world.cellFor(@x-1, @y) instanceof Grass)
      right = (@world.cellFor(@x+1, @y) instanceof Grass)
      up = (@world.cellFor(@x, @y-1) instanceof Grass)
      down = (@world.cellFor(@x, @y+1) instanceof Grass)
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

    maybeWallSprite: () =>
      down = (@world.cellFor(@x, @y+1) instanceof Wall)
      if down
        {x: 23, y: 10}
      else
        null

    spriteLocation: () =>
      @maybeGrassSprite() || @maybeWallSprite() || {x: 21, y: 0}

  class Wall extends Cell
    constructor: (@x, @y) ->
      super(@x, @y)

    @colliding: true

    maybeDryGrassSprite: () =>
      down = (@world.cellFor(@x, @y+1) instanceof DryGrass)
      if down
        {x: 23, y: 13}
      else
        null

    spriteLocation: () =>
      # [ {x: 22, y: 6}, {x: 23, y: 6}, {x: 22, y: 7}, {x: 23, y: 7} ]
      @maybeDryGrassSprite() || {x: 22, y: 6}

  class Entity extends Drawable
    constructor: (@x, @y) ->
      super(@x, @y)

    age: () => @world.age - @birth

    distanceTo: (cell) =>
      Math.distance(cell, this)

    findCellsWithin: (manhattanDist) =>
      _.flatten((cell for cell in row when @distanceTo(cell) <= manhattanDist) for row in @world.map)

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
    # hitbox is an array of {x, y, width, height} which specifies how far left and up the hitbox should go, and its width/height (by default 1/1)
    @hitbox: [{x: 0, y: 0, width: 1, height: 1}]

    # returns an array of rectangles (x, y, width, height) associated with a specified pt (by default this Entity's location)
    getHitboxes: (x = @x, y = @y) =>
      hitboxBlueprints = @constructor.hitbox
      for hitbox in hitboxBlueprints
        x: x + hitbox.x
        y: y + hitbox.y
        width: hitbox.width || 1
        height: hitbox.height || 1

    # returns true iff this Entity can occupy the given location
    canOccupy: (x, y, world = @world) =>
      for rect in @getHitboxes(x, y)
        for x in [rect.x...rect.x + rect.width]
          for y in [rect.y...rect.y + rect.height]
            return false if not world.isUnoccupied(x, y, this)
      return true


    step: () => throw "not implemented"


  class House extends Entity
    spriteLocation: () => [
      {
      x: 1
      y: 16
      }
      {
      x: 0
      y: 15
      dx: -1
      }
      {
        x: 4
        y: 13
        dx: -1
        dy: -1
      }
      {
        x: 5
        y: 13
        dx: 0
        dy: -1
      }
    ]

    @hitbox: [
      {x: -1, y: -1, width: 1, height: 2}
      {x: 0, y: -1}
    ]


    draw: (cq) =>
      super(cq)

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

  class RepeatedActionTask extends Task
    constructor: (@human, @action, @times) ->
    isComplete: () => @times > 0
    nextAction: () =>
      @times -= 1
      return @action

  class WalkTo extends Task

    # returns an array of actions to get from start to within the distance threshold
    bfs: (@start) =>
      # immutable class representing a path to get to an end state
      class Path
        constructor: (@endState, @actions = []) ->
        addSegment: (action) =>
          newLoc = {x: @endState.x + action.direction.x, y: @endState.y + action.direction.y}
          new Path(newLoc, @actions.concat([action]))

      # queue is an array of path objects
      queue = [new Path(@start)]
      visited = {} # keys are JSON.stringify({x, y}) objects
      while not _.isEmpty(queue)
        path = queue.shift()

        continue if visited[JSON.stringify(path.endState)]
        visited[JSON.stringify(path.endState)] = true

        if Math.distance(path.endState, @pt) <= @distanceThreshold
          return path.actions
        else
          for action in [Action.Left, Action.Right, Action.Up, Action.Down]
            newPath = path.addSegment(action)
            if @human.canOccupy(newPath.endState.x, newPath.endState.y)
              queue.push(newPath)
      return null

    constructor: (@human, @pt, @distanceThreshold = 1) ->
      super(@human)
      @pt = _.pick(@pt, "x", "y")
      throw "Point is actually a #{@pt}" unless (_.isNumber(@pt.x) && _.isNumber(@pt.y))
      if @distanceThreshold is 0 and not @human.canOccupy(@pt.x, @pt.y)
        console.log("cannot occupy that space!")
        @actions = []
      else
        @actions = @bfs(_.pick(@human, "x", "y"))
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
      super(@human, [new WalkTo(@human, @food), new Consume(@human, @food)])

  class GoHome extends WalkTo
    constructor: (@human) ->
      super(@human, @human.closestVisible(House), 0)

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

    initialize: () =>
      # All cells you have seen previously, but cannot currently see
      @rememberedCells = []
      # All entities you have seen previously, but cannot currently see
      @rememberedEntities = []

      lastVisibleCells = []
      lastVisibleEntities = []
      $(@world).on("prestep", () =>
        lastVisibleCells = @getVisibleCells()
        lastVisibleEntities = @getVisibleEntities()
      )
      $(@world).on("poststep", () =>
        # to update the rememberedCells
        # 1. remove cells remembered last frame but visible now
        # 2. add in cells visible last frame but not visible now
        @rememberedCells = _.difference(@rememberedCells, @getVisibleCells())

        @rememberedCells = @rememberedCells.concat(_.difference(lastVisibleCells, @getVisibleCells()))

        # to update seenEntities
        # 1. remove entities remembered last frame that *should* be visible now but aren't
        # 2. remove entities remembered last frame but visible now
        # 3. add in entities visible last frame but not visible now
        @rememberedEntities = _.reject(@rememberedEntities, (entity) =>
          @distanceTo(entity) <= @sightRange and not _.contains(@getVisibleEntities(), entity)
        )

        @rememberedEntities = _.difference(@rememberedEntities, @getVisibleEntities())
        @rememberedEntities = @rememberedEntities.concat(_.difference(lastVisibleEntities, @getVisibleEntities()))
      )


    getVisibleCells: () => @findCellsWithin(@sightRange)
    getVisibleEntities: () => @findEntitiesWithin(@sightRange)

    closestVisible: (entityType) =>
      entities = _.filter(@rememberedEntities.concat(@getVisibleEntities()), (e) -> e instanceof entityType)
      if not _.isEmpty(entities)
        _.min(entities, @distanceTo)
      else
        null

    # returns an array of () => (Task or falsy)
    possibleTasks: () =>
      tasks = [ () => @currentTask ]

      if @hunger > 300
        tasks.push( () =>
          closestFood = @closestVisible(Food)
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

    spriteLocation: () =>
      spriteIdx = (@animationMillis() / 333) % 4 | 0
      x: [10, 9, 10, 11][spriteIdx]
      y: 4
      spritesheet: "characters"

    draw: (cq) =>
      super(cq)
      actionString = if @currentAction.toString() then @currentAction.toString() + ", " else ""
      taskString = if @currentTask then @currentTask.toString() + ", " else ""
      text = "#{taskString}#{@hunger | 0} hunger, #{@tired | 0} tired"
      cq.fillStyle("red").font('normal 20pt arial').fillText(text, @x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE)


  setupWorld = () ->
    world = new World(600, 30, (x, y) ->
      if y % 12 <= 1 && (x + y) % 30 > 5
        new Wall(x, y)
      else if Math.sin(x*y / 100) > .90
        new Grass(x, y)
      else
        new DryGrass(x, y)
    )
    for x in [0...world.width]
      for y in [0...world.height] when Math.sin((x + y) / 8) * Math.cos((x - y) / 9) > .9
        food = new Food(x, y)
        world.addEntity(food)

    world

  setupDebug = (world) ->
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


  framework = {
    setup: () ->
      @world = setupWorld()
      setupDebug(@world)

      @camera = {
        x: 0
        y: 0
      }

      @keys = {}

      @cq = cq().framework(this, this)
      @cq.canvas.oncontextmenu = () -> false
      @cq.appendTo("body")

    onstep: (delta, time) ->
      @world.stepAll()

    onrender: () ->
      $(@world).trigger("prerender")
      mapping = {
        w: () => @camera.y += 1
        s: () => @camera.y -= 1
        a: () => @camera.x += 1
        d: () => @camera.x -= 1
      }
      for key, fn of mapping
        fn() if @keys[key]
      @cq.clear("black")
      @cq.save()
      @cq.translate(@camera.x * CELL_PIXEL_SIZE, @camera.y * CELL_PIXEL_SIZE)
      @world.drawAll(@cq)

      pt = @cellPosition(@mouseX, @mouseY)
      if @world.human.canOccupy(pt.x, pt.y) then @cq.fillStyle("green") else @cq.fillStyle("red")
      @cq.globalAlpha(0.5).fillRect(pt.x * CELL_PIXEL_SIZE, pt.y * CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)
      @cq.restore()
      $(@world).trigger("postrender")

    # window resize
    onresize: (width, height) ->
      # resize canvas with window
      # change camera transform
      if @cq
        @cq.canvas.height = height
        @cq.canvas.width = width

    cellPosition: (canvasX, canvasY) ->
      x: canvasX / CELL_PIXEL_SIZE - @camera.x | 0
      y: canvasY / CELL_PIXEL_SIZE - @camera.y | 0

    # clickedBehavior: (x, y) ->
    #   entity = @world.entityAt(x, y)
    #   if entity isnt null
    #     {
    #       House: () => new 
    #     }

    onmousedown: (x, y, button) ->
      pt = @cellPosition(x, y)
      if @world.human.canOccupy(pt.x, pt.y)
        @world.human.currentTask = new WalkTo(@world.human, pt, 0)

    onmousemove: (x, y) ->
      @mouseX = x
      @mouseY = y

    onmousewheel: (delta) ->
      console.log(delta)

    # keyboard events
    onkeydown: (key) ->
      @keys[key] = true
      if key is 'b'
        pt = @cellPosition(@mouseX, @mouseY)
        house = tryConstruct(@world.human, House, [pt.x, pt.y])
        if house
          # TODO this is only a preventative measure
          # need to add the actual logic inside the Task itself to ensure that it doesn't happen
          @world.human.currentTask = (new WalkTo(@world.human, pt, 1).andThen(new Build(@world.human, house)))
    onkeyup: (key) ->
      delete @keys[key]
  }

  $(() ->
    framework.setup()
  )
