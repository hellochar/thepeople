require [
  'jquery',
  'underscore'
  'canvasquery'
], ($, _, cq) ->

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  CELL_PIXEL_SIZE = 20

  class World
    constructor: (@width, @height, @cellFor) ->
      @map = ((@cellFor(x, y) for x in [ 0...@width ]) for y in [ 0...@height ])
      @map[10][10] = home = new House(this, 10, 10)
      @human = new Human(this, @width/3 | 0, @height/3 | 0, home)


  class Cell
    constructor: (@world, @x, @y) ->


    step: () =>

    color: () =>
      "black"

    draw: (cq) =>
      cq.fillStyle(@color()).fillRect(@x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)

  class House extends Cell
    constructor: (@world, @x, @y) ->
      super(@world, @x, @y)

    color: () => "yellow"

  class Food extends Cell
    constructor: (@world, @x, @y) ->
      super(@world, @x, @y)
      @amount = 300

    consume: (amount) =>
      @amount -= amount
      if @amount <= 0
        @world.map[@y][@x] = new Cell(@world, @x, @y)

    color: () =>
      if @amount > 0 then "rgb(0, #{@amount}, 0)" else "grey"

  class Action
    perform: (human) ->

  class ConsumeAction extends Action
    constructor: (@food) ->
    perform: (human) ->
      @food.consume(20)
      human.hunger -= 20
      human.tired += 1

  class MoveAction extends Action
    constructor: (@direction) ->
    perform: (human) ->
      human.x += @direction.x
      human.y += @direction.y
      human.hunger += 1
      human.tired += 1

  class WanderAction extends MoveAction
    constructor: () ->
      dir = [{ x: -1, y: 0},
       { x: +1, y: 0},
       { x: 0, y: -1},
       { x: 0, y: +1},
      ][Math.floor(Math.random() * 4)]
      super(dir)

  class RestAction extends Action
    perform: (human) ->
      human.tired += .1
      human.hunger += 1

  class SleepAction extends Action
    perform: (human) ->
      human.tired -= 3
      human.hunger += .2

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
    constructor: (@human, @cell, @distanceThreshold = 1) ->
      throw "Cell undefined" unless @cell
      super(@human)
    isComplete: () => @human.distanceTo(@cell) <= @distanceThreshold

    nextAction: () =>
      dx = (@cell.x - @human.x)
      dy = if dx == 0 then (@cell.y - @human.y) else 0
      return new MoveAction({x: Math.signum(dx), y: Math.signum(dy)})

  class Consume extends Task
    constructor: (@human, @food) ->
      super(@human)
    isComplete: () => @food.amount <= 0

    nextAction: () =>
      return new ConsumeAction(@food)

  class Eat extends TaskList
    constructor: (@human) ->
      food = _.filter(@human.findCellsWithin(20), (cell) -> cell instanceof Food)
      closestFood = _.min(food, human.distanceTo)
      if closestFood
        super(@human, [new WalkTo(@human, closestFood), new Consume(@human, closestFood)])
      else super(@human, [])

  class GoHome extends WalkTo
    constructor: (@human) ->
      super(@human, @human.home, 0)

  class Sleep extends RepeatedActionTask
    constructor: (@human) ->
      # super(@human, SleepAction, 40)
    isComplete: () => @human.tired <= 0
    nextAction: () => new SleepAction()

  class Human
    constructor: (@world, @x, @y, @home) ->
      @hunger = 0
      @tired = 0
      @currentTask = null
      @currentAction = new RestAction()

    distanceTo: (cell) =>
      Math.abs(cell.x - @x) + Math.abs(cell.y - @y)

    findCellsWithin: (manhattanDist) =>
      _.flatten((cell for cell in row when @distanceTo(cell) <= manhattanDist) for row in @world.map)

    getAction: () =>
      if @currentTask
        return @currentTask.nextAction()
      else
        if @hunger > 300
          @currentTask = new Eat(this)
          @currentTask.nextAction()
        else if @tired > 200
          @currentTask = (new GoHome(this)).andThen(new Sleep(this))
          @currentTask.nextAction()
        else
          return new RestAction()

    step: () =>
      action = @getAction()
      action.perform(this)
      @currentAction = action

      if @currentTask && @currentTask.isComplete()
        @currentTask = null

    draw: (cq) =>
      cq.fillStyle("red").fillRect(@x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)
      cq.fillStyle("white").fillText("#{@currentAction.constructor.name}, #{@hunger} hunger, #{@tired} tired", @x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE)

  framework = {
    setup: () ->
      @cq = cq().framework(this, this)
      @cq.canvas.oncontextmenu = () -> false
      @cq.appendTo("body")
      @world = new World(60, 30, (x, y) ->
        if (x + y*40) % 56 == 0
          new Food(this, x, y)
        else
          new Cell(this, x, y)
      )

    onStep: (delta, time) ->
      ((cell.step() for cell in row) for row in @world.map)
      @world.human.step()

    onRender: () ->
      @cq.clear("grey")
      ((cell.draw(@cq) for cell in row) for row in @world.map)
      @world.human.draw(@cq)

    # window resize
    onResize: (width, height) ->
      # resize canvas with window
      # change camera transform
      if @cq
        @cq.canvas.height = height
        @cq.canvas.width = width

    onMouseDown: (x, y, button) ->
      cell = @world.map[(y / CELL_PIXEL_SIZE) | 0][(x / CELL_PIXEL_SIZE) | 0]
      if not @world.human.currentTask
        @world.human.currentTask = new WalkTo(@world.human, cell, 0)

  }

  $(() ->
    framework.setup()
  )
