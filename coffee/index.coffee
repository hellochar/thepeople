window.asdf = (x, y) ->
  [(x/32) | 0, (y/32) | 0]

require [
  'jquery',
  'underscore'
  'canvasquery'
  'action'
], ($, _, cq, Action) ->

  value = (arg) ->
    if _.isFunction(arg) then arg() else arg

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

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
      @entities.push(entity)
      entity

    removeEntity: (entity) =>
      idx = @entities.indexOf(entity)
      @entities.splice(idx, 1)
      entity

    getCell: (x, y) ->
      if x >= 0 && x < @width && y >= 0 && y < @height
        @map[y][x]
      else
        null

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
      cell.draw(cq) for cell in @human.findCellsWithin(@human.sightRange)
      entity.draw(cq) for entity in @human.findEntitiesWithin(@human.sightRange)

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

  class RandomSprite extends Drawable
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

    spriteLocation: () =>
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
        {x: 21, y: 0}


  class Entity extends Drawable
    constructor: (@x, @y) ->

    distanceTo: (cell) =>
      Math.abs(cell.x - @x) + Math.abs(cell.y - @y)

    findCellsWithin: (manhattanDist) =>
      _.flatten((cell for cell in row when @distanceTo(cell) <= manhattanDist) for row in @world.map)

    findEntitiesWithin: (manhattanDist) =>
      _.filter(@world.entities, (e) => @distanceTo(e) <= manhattanDist)

    checkConsistency: () =>
      throw "bad position" unless (@x >= 0 && @x <= @world.width) and
                                  (@y >= 0 && @y <= @world.height)

    die: () =>
      $(@world).one("poststep", () =>
        @world.removeEntity(this)
      )

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
      @subtasks.shift() while @currentTask().isComplete()
      return @currentTask().nextAction()

  class RepeatedActionTask extends Task
    constructor: (@human, @action, @times) ->
    isComplete: () => @times > 0
    nextAction: () =>
      @times -= 1
      return @action

  class WalkTo extends Task
    constructor: (@human, @pt, @distanceThreshold = 1) ->
      throw "Point is actually a #{@pt}" unless (_.isNumber(@pt.x) && _.isNumber(@pt.y))
      super(@human)
    isComplete: () => @human.distanceTo(@pt) <= @distanceThreshold

    nextAction: () =>
      dx = (@pt.x - @human.x)
      dy = if dx == 0 then (@pt.y - @human.y) else 0
      return new Action.Move({x: Math.signum(dx), y: Math.signum(dy)})

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

    getAction: () =>
      if @currentTask
        return @currentTask.nextAction()
      else
        if @hunger > 300
          food = _.filter(@findEntitiesWithin(@sightRange), (cell) -> cell instanceof Food)
          closestFood = if _.isEmpty(food) then null else _.min(food, @distanceTo)
          if closestFood
            @currentTask = new Eat(this, closestFood)
            @currentTask.nextAction()
        if not @currentTask and @tired > 200
          @currentTask = (new GoHome(this)).andThen(new Sleep(this))
          @currentTask.nextAction()
        else
          return new Action.Rest()

    step: () =>
      action = @getAction()
      action.perform(this)
      @currentAction = action
      if @currentTask && @currentTask.isComplete()
        @currentTask = null

    spriteLocation: () =>
      x: 1
      y: 26

    draw: (cq) =>
      super(cq)
      cq.fillStyle("white").fillText("#{if @currentAction.toString() then @currentAction.toString() + ", " else ""}#{@hunger} hunger, #{@tired} tired", @x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE)

  framework = {
    setup: () ->
      @cq = cq().framework(this, this)
      @cq.canvas.oncontextmenu = () -> false

      @world = new World(60, 30, (x, y) ->
        if Math.sin(x*y / 100) > .90
          new DryGrass(x, y)
        else
          new Grass(x, y)
      )
      for x in [0...@world.width]
        for y in [0...@world.height] when Math.sin((x + y) / 8) * Math.cos((x - y) / 9) > .9
          @world.addEntity(new Food(x, y))

      @cq.canvas.width = CELL_PIXEL_SIZE * @world.width
      @cq.canvas.height = CELL_PIXEL_SIZE * @world.height
      @cq.appendTo("body")

    onStep: (delta, time) ->
      @world.stepAll()

    onRender: () ->
      @cq.clear("grey")
      @world.drawAll(@cq)

    # # window resize
    # onResize: (width, height) ->
    #   # resize canvas with window
    #   # change camera transform
    #   if @cq
    #     @cq.canvas.height = height
    #     @cq.canvas.width = width

    onMouseDown: (x, y, button) ->
      pt = {
        y: (y / CELL_PIXEL_SIZE) | 0
        x: (x / CELL_PIXEL_SIZE) | 0
      }
      if not @world.human.currentTask
        @world.human.currentTask = new WalkTo(@world.human, pt, 0)

  }

  $(() ->
    framework.setup()
  )
