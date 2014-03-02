require [
  'jquery',
  'underscore'
  'canvasquery'
  'action'
], ($, _, cq, Action) ->

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  CELL_PIXEL_SIZE = 32

  class World
    constructor: (@width, @height) ->
      @entities = []
      home = @addEntity(new House(10, 10))
      @human = @addEntity(new Human(@width/3 | 0, @height/3 | 0, home))

    addEntity: (entity) =>
      entity.world = this
      @entities.push(entity)
      entity

    removeEntity: (entity) =>
      idx = @entities.indexOf(entity)
      @entities.splice(idx, 1)
      entity

    stepAll: () =>
      $(this).trigger("prestep")
      for entity in @entities
        entity.step()
        entity.checkConsistency()
      $(this).trigger("poststep")

    drawAll: (cq) =>
      for entity in @entities
        entity.draw(cq)

  class Entity
    @SPRITESHEET = (
      s = new Image()
      s.src = "/images/hyptosis_tile-art-batch-1.png"
      s.TILE_SIZE = 32
      s
    )
    constructor: (@x, @y) ->

    distanceTo: (cell) =>
      Math.abs(cell.x - @x) + Math.abs(cell.y - @y)

    findEntitiesWithin: (manhattanDist) =>
      _.filter(@world.entities, (e) => @distanceTo(e) <= manhattanDist)

    checkConsistency: () =>
      throw "bad position" unless (@x >= 0 && @x <= @world.width) and
                                  (@y >= 0 && @y <= @world.height)

    die: () =>
      $(@world).one("poststep", () =>
        @world.removeEntity(this)
      )

    spriteLocation: () => throw "not implemented"

    step: () => throw "not implemented"

    draw: (cq) =>
      # cq.fillStyle(@color()).fillRect(@x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)
      {x: sx, y: sy} = @spriteLocation()
      tileSize = Entity.SPRITESHEET.TILE_SIZE
      cq.drawImage(Entity.SPRITESHEET, sx * tileSize, sy * tileSize, tileSize, tileSize, @x * CELL_PIXEL_SIZE, @y * CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)

  class House extends Entity
    spriteLocation: () =>
      x: 1
      y: 16

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
      @hunger = 0
      @tired = 0
      @currentTask = null
      @currentAction = new Action.Rest()

    getAction: () =>
      if @currentTask
        return @currentTask.nextAction()
      else
        if @hunger > 300
          food = _.filter(@findEntitiesWithin(20), (cell) -> cell instanceof Food)
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

      @world = new World(60, 30)
      @world.addEntity(new Food(i % 60, (i/60) | 0)) for i in [0...(@world.width * @world.height)] by 96

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
