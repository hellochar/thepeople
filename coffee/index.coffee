window.asdf = (x, y) ->
  [(x/32) | 0, (y/32) | 0]

require [
  'jquery',
  'underscore'
  'stats'
  'canvasquery'
  'action'
], ($, _, Stats, cq, Action) ->

  'use strict'

  value = (arg) ->
    if _.isFunction(arg) then arg() else arg

  withinRect = (x, y, xmin, xmax, ymin, ymax) ->
    return (x >= xmin && x <= xmax && y >= ymin && y <= ymax)

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  Math.distance = (a, b) ->
    Math.abs(a.x - b.x) + Math.abs(a.y - b.y)


  CELL_PIXEL_SIZE = 32

  class World
    constructor: (@width, @height, @cellFor) ->
      @map = ((@cellFor(x, y) for x in [ 0...@width ]) for y in [ 0...@height ])
      ((cell.world = this for cell in row) for row in @map)
      @entities = []
      home = @addEntity(new House(10, 10))
      @human = @addEntity(new Human(10, 11, home))

    addEntity: (entity) =>
      entity.world = this
      $(this).on("poststep", entity.poststep) if entity.poststep
      @entities.push(entity)
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

    canOccupy: (x, y) =>
      return false if not @withinMap(x, y)
      cellHitbox = @getCell(x, y).getHitboxes()
      return false if cellHitbox isnt null

      for e in @entities
        hitboxes = e.getHitboxes()
        continue if not hitboxes
        hitboxes = [hitboxes] unless _.isArray(hitboxes)
        for hitbox in hitboxes
          xmin = e.x + hitbox.x
          ymin = e.y + hitbox.y
          width = hitbox.width || 1
          height = hitbox.height || 1
          return false if withinRect(x, y, xmin, xmin + width - 1, ymin, ymin + height - 1)

      return true


    stepAll: () =>
      $(this).trigger("prestep")
      for entity in @entities
        entity.step()
        entity.checkConsistency()
      $(this).trigger("poststep")

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


  class Drawable
    @SPRITESHEET = (
      s = new Image()
      s.src = "/images/hyptosis_tile-art-batch-1.png"
      s.TILE_SIZE = 32
      s
    )
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
    # }
    # or an array of those objects
    spriteLocation: () => throw "not implemented"

    # optionally, declare a hitbox
    # which looks like an array of {x, y, width, height} which specifies how far left and up the hitbox should go, and its width/height (by default 1/1)
    # true is an alias for {x: 0, y: 0}

    getHitboxes: () =>
      if not value(@hitbox)
        null
      else
        hitbox = value(@hitbox)
        if hitbox == true
          hitbox = {x: 0, y: 0, width: 1}
        hitbox

    draw: (cq) =>
      sprites = value(@spriteLocation)
      if not _.isArray(sprites)
        sprites = [sprites]

      tileSize = Entity.SPRITESHEET.TILE_SIZE

      for sprite in sprites
        throw "bad sprite #{sprite}" unless _.isObject(sprite)
        sx = sprite.x
        sy = sprite.y
        width = sprite.width || 1
        height = sprite.height || 1
        dx = sprite.dx || 0
        dy = sprite.dy || 0
        cq.drawImage(Entity.SPRITESHEET, sx * tileSize, sy * tileSize, width * tileSize, height * tileSize, (@x + dx) * CELL_PIXEL_SIZE, (@y + dy) * CELL_PIXEL_SIZE, width * CELL_PIXEL_SIZE, height * CELL_PIXEL_SIZE)


  class Cell extends Drawable
    constructor: (@x, @y) ->

  class RandomSpriteCell extends Cell
    constructor: (@x, @y) ->
      super(@x, @y)
      sprites = value(@sprites)
      idx = Math.random() * sprites.length | 0
      @spriteLocation = sprites[idx]

    sprites: () -> throw "not implemented"

  class Grass extends Cell
    constructor: (@x, @y) ->
      super(@x, @y)

    spriteLocation: { x: 21, y: 4 }

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

    hitbox: true

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

    distanceTo: (cell) =>
      Math.distance(cell, this)

    findCellsWithin: (manhattanDist) =>
      _.flatten((cell for cell in row when @distanceTo(cell) <= manhattanDist) for row in @world.map)

    findEntitiesWithin: (manhattanDist) =>
      _.filter(@world.entities, (e) => @distanceTo(e) <= manhattanDist)

    checkConsistency: () =>
      throw "bad position" unless @world.withinMap(@x, @y)

    isDead: () => not _.contains(@world.entities, this)

    die: () =>
      $(@world).one("poststep", () =>
        @world.removeEntity(this)
      )

    hitbox: true

    step: () => throw "not implemented"


  class House extends Entity
    spriteLocation: [
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

    hitbox: [
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
    constructor: (@human) ->
    # Returns the next Action to take for this Task
    # invariant: nextAction() is only called when isComplete() is false
    nextAction: () => throw "Not implemented"
    # returns true/false
    isComplete: () => throw "not implemented"

    # compose this task with another task
    andThen: (@task) =>
      return new TaskList(@human, [this, @task])

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

  class RepeatedActionTask extends Task
    constructor: (@human, @action, @times) ->
    isComplete: () => @times > 0
    nextAction: () =>
      @times -= 1
      return @action

  class WalkTo extends Task
    ACTIONS = [{ x: -1, y: 0},
       { x: +1, y: 0},
       { x: 0, y: -1},
       { x: 0, y: +1},
      ]

    # returns an array of actions to get from start to within the distance threshold
    bfs: (@start) =>
      # immutable class representing a path to get to an end state
      class Path
        constructor: (@endState, @actions = []) ->
        addSegment: (action) =>
          newLoc = {x: @endState.x + action.x, y: @endState.y + action.y}
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
          for action in ACTIONS
            newPath = path.addSegment(action)
            if @human.world.canOccupy(newPath.endState.x, newPath.endState.y)
              queue.push(newPath)
      return null

    constructor: (@human, @pt, @distanceThreshold = 1) ->
      super(@human)
      @pt = _.pick(@pt, "x", "y")
      throw "Point is actually a #{@pt}" unless (_.isNumber(@pt.x) && _.isNumber(@pt.y))
      if not @human.world.canOccupy(@pt.x, @pt.y)
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
      return new Action.Move(@actions.shift())

  class Consume extends Task
    constructor: (@human, @food) ->
      super(@human)
    isComplete: () => @food.amount <= 0

    nextAction: () =>
      return new Action.Consume(@food)

  class Eat extends TaskList
    constructor: (@human, @food) ->
      super(@human, [new WalkTo(@human, @food), new Consume(@human, @food)])

  class GoHome extends WalkTo
    constructor: (@human) ->
      super(@human, @human.home, 0)

  class Sleep extends RepeatedActionTask
    constructor: (@human) ->
      # super(@human, SleepAction, 40)
    isComplete: () => @human.tired <= 0
    nextAction: () => new Action.Sleep()

  class Human extends Entity
    constructor: (@x, @y, @home) ->
      super(@x, @y)
      @sightRange = 10
      @hunger = 0
      @tired = 0
      @currentTask = null
      @currentAction = new Action.Rest()

      # All cells you have seen previously, but cannot currently see
      @rememberedCells = []
      # All entities you have seen previously, but cannot currently see
      @rememberedEntities = []

    getVisibleCells: () => @findCellsWithin(@sightRange)
    getVisibleEntities: () => @findEntitiesWithin(@sightRange)

    getAction: () =>
      if @currentTask && @currentTask.isComplete()
        @currentTask = null
      if @currentTask
        return @currentTask.nextAction()
      else
        if @hunger > 300
          food = _.filter(@rememberedEntities.concat(@getVisibleEntities()), (cell) -> cell instanceof Food)
          closestFood = if _.isEmpty(food) then null else _.min(food, @distanceTo)
          if closestFood
            @currentTask = new Eat(this, closestFood)
            return @currentTask.nextAction()
        if not @currentTask and @tired > 200
          @currentTask = (new GoHome(this)).andThen(new Sleep(this))
          return @currentTask.nextAction()
        else
          return new Action.Rest()

    step: () =>
      @lastVisibleCells = @getVisibleCells()
      @lastVisibleEntities = @getVisibleEntities()

      action = @getAction()
      action.perform(this)
      @currentAction = action
      if @currentTask && @currentTask.isComplete()
        @currentTask = null

    poststep: () =>
      # to update the rememberedCells
      # 1. remove cells remembered last frame but visible now
      # 2. add in cells visible last frame but not visible now
      @rememberedCells = _.difference(@rememberedCells, @getVisibleCells())

      @rememberedCells = @rememberedCells.concat(_.difference(@lastVisibleCells, @getVisibleCells()))

      # to update seenEntities
      # 1. remove entities remembered last frame that *should* be visible now but aren't
      # 2. remove entities remembered last frame but visible now
      # 3. add in entities visible last frame but not visible now
      @rememberedEntities = _.reject(@rememberedEntities, (entity) =>
        @distanceTo(entity) <= @sightRange and not _.contains(@getVisibleEntities(), entity)
      )

      @rememberedEntities = _.difference(@rememberedEntities, @getVisibleEntities())
      @rememberedEntities = @rememberedEntities.concat(_.difference(@lastVisibleEntities, @getVisibleEntities()))

    spriteLocation: () =>
      x: 1
      y: 26

    draw: (cq) =>
      super(cq)
      cq.fillStyle("white").fillText("#{if @currentAction.toString() then @currentAction.toString() + ", " else ""}#{@hunger} hunger, #{@tired} tired", @x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE)

  framework = {
    setup: () ->
      @world = new World(600, 30, (x, y) ->
        if y % 12 <= 1 && (x + y) % 30 > 5
          new Wall(x, y)
        else if Math.sin(x*y / 100) > .90
          new Grass(x, y)
        else
          new DryGrass(x, y)
      )
      for x in [0...@world.width]
        for y in [0...@world.height] when Math.sin((x + y) / 8) * Math.cos((x - y) / 9) > .9
          if @world.canOccupy(x, y)
            @world.addEntity(new Food(x, y))

      @camera = {
        x: 0
        y: 0
      }

      @keys = {}

      @cq = cq().framework(this, this)
      @cq.canvas.oncontextmenu = () -> false
      @cq.appendTo("body")

      @statsStep = new Stats()
      @statsStep.setMode(0)
      @statsStep.domElement.style.position = 'absolute'
      @statsStep.domElement.style.left = '0px'
      @statsStep.domElement.style.top = '0px'

      @statsRender = new Stats()
      @statsRender.setMode(0)
      @statsRender.domElement.style.position = 'absolute'
      @statsRender.domElement.style.left = '0px'
      @statsRender.domElement.style.top = '50px'

      $("body").append( @statsStep.domElement )
      $("body").append( @statsRender.domElement )

    onStep: (delta, time) ->
      @statsStep.begin()
      @world.stepAll()
      @statsStep.end()

    onRender: () ->
      @statsRender.begin()
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
      if @world.canOccupy(pt.x, pt.y) then @cq.fillStyle("green") else @cq.fillStyle("red")
      @cq.globalAlpha(0.5).fillRect(pt.x * CELL_PIXEL_SIZE, pt.y * CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)
      @cq.restore()
      @statsRender.end()

    # window resize
    onResize: (width, height) ->
      # resize canvas with window
      # change camera transform
      if @cq
        @cq.canvas.height = height
        @cq.canvas.width = width

    cellPosition: (canvasX, canvasY) ->
      x: canvasX / CELL_PIXEL_SIZE - @camera.x | 0
      y: canvasY / CELL_PIXEL_SIZE - @camera.y | 0

    onMouseDown: (x, y, button) ->
      pt = @cellPosition(x, y)
      if @world.canOccupy(pt.x, pt.y)
        @world.human.currentTask = new WalkTo(@world.human, pt, 0)

    onMouseMove: (x, y) ->
      @mouseX = x
      @mouseY = y

    # keyboard events
    onKeyDown: (key) ->
      @keys[key] = true
    onKeyUp: (key) ->
      delete @keys[key]
  }

  $(() ->
    framework.setup()
  )
