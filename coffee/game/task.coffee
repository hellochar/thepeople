define [
  'underscore'
  'game/action'
  'search'
], (_, Action, Search) ->
  class CancelledException
    constructor: (@reason) ->

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

    # isAlsoCompleteWhen: (isComplete) =>
    #   return new Task(@human, @nextAction, () => isComplete() or @isComplete(), @toString)

    # Should only call in nextAction()
    cancel: (reason) -> throw new Task.CancelledException(reason)

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

    toString: () => @subtasks.join(", and then ")

  # This task tries to get the human as close as possible to the given point while
  # maintaing decent performance. This Task is responsible for:
  #
  # Finding a path that will get the human reasonably close to the given point
  # if the point cannot be walked directly into
  #
  # refinding a path in case the one it had found failed
  #
  # It currently does *not* change courses if a new, better path has been
  # established since the task was assigned
  #
  class WalkNear extends Task
    lineRasterize = (start, end) ->
      #create a list to store all of the line segment's points in
      pointArray = []
      #set this function's variables based on the class's starting and ending points
      x0 = start.x | 0
      y0 = start.y | 0
      x1 = end.x | 0
      y1 = end.y | 0

      #define vector differences and other variables required for Bresenham's Algorithm
      dx = Math.abs(x1 - x0)
      dy = Math.abs(y1 - y0)
      sx = (if (x0 < x1) then 1 else -1) #step x
      sy = (if (y0 < y1) then 1 else -1) #step y
      err = dx - dy #get the initial error value
      #set the first point in the array
      pointArray.push {x: x0, y: y0}

      #Main processing loop
      until ((x0 is x1) and (y0 is y1))
        e2 = err * 2 #hold the error value
        #use the error value to determine if the point should be rounded up or down
        if e2 >= -dy
          err -= dy
          x0 += sx
        else if e2 < dx
          err += dx
          y0 += sy

        #add the new point to the array
        pointArray.push {x: x0, y: y0}
      pointArray

    constructor: (@human, @pt, @subject) ->
      super(@human)
      throw "Point is actually a #{@pt}" unless (_.isNumber(@pt.x) && _.isNumber(@pt.y))
      @recomputePath()

    recomputePath: () =>
      walkablePt = @human.world.map.closestWalkablePoint(@human, _.pick(@pt, "x", "y"))
      if walkablePt
        @pt = walkablePt

        try
          @actions = Search.findPathTo(@human, @pt)
        catch err
          if err is Search.NoSolution
            console.log("no path!")
            @actions = []
          else
            throw err
      else
        # Just do a dumb "walk in a straight line until you hit something"
        # TODO find a better default
        @actions = Search.getActionsFromPoints(lineRasterize(@human, @pt))

    toString: () => if @subject then "Walking to #{@subject}" else "Walking"

    isComplete: () => _.isEmpty(@actions)

    nextAction: () =>
      action = @actions.shift()
      $(action).on("failed", @recomputePath)
      return action

  class WalkUntilNextTo extends WalkNear
    # Assumes the entity doesn't move
    constructor: (@human, @entity) ->
      super(@human, _.pick(@entity, "x", "y"))

    # Has the same behavior as (new WalkNear().isAlsoCompleteWhen(nearby check)).
    isComplete: () =>
      super() || @entity.isNeighbor(@human)

  class Consume extends Task
    constructor: (@human, @food) ->
      super(@human)

    isComplete: () => @food.amount <= 0 or @human.hunger <= 0

    nextAction: () =>
      if not @human.isNeighbor(@food)
        @cancel("Cannot reach food!")
      return new Action.Consume(@food)

  class Eat extends TaskList
    constructor: (@human, @food) ->
      super(@human, [new WalkNear(@human, @food, "food"), new Consume(@human, @food)])

  class Sleep extends Task
    constructor: (@human) ->
      super(@human)

    isComplete: () => @human.tired <= 0
    nextAction: () => new Action.Sleep()

  # Makes a human build a blueprint, assuming that the human is neighboring it
  # errors if s/he isn't
  class Build extends Task
    constructor: (@human, @blueprint) ->
      super(@human)
      throw "Bad blueprint" if not @blueprint
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

    class BuildAction extends Action
      constructor: (@blueprint) ->
      perform: (human) ->
        @blueprint.build()
        human.tired += 2
        human.hunger += 1

    isComplete: () => @blueprint.isDead()
    nextAction: () =>
      if not @blueprint.isNeighbor(@human)
        @cancel("#{@human.constructor.name} cannot reach building!")
      new BuildAction(@blueprint)

    toString: () => "Building a #{@entity.constructor.name}"

  # Walk to a blueprint and Build it
  class Construct extends TaskList
    constructor: (@human, @blueprint) ->
      super(@human, [new WalkUntilNextTo(@human, @blueprint), new Build(@human, @blueprint)])

    # thought: () => "Constructing a #{@entity.constructor.name}!"

  class GoHomeAndSleep extends TaskList
    constructor: (@human, @house) ->
      freeBedLoc = @house.getFreeBeds(@human)[0]
      sleepLoc = freeBedLoc || @house.pt()
      super(@human, [new WalkNear(@human, sleepLoc, "home"), new Sleep(@human)])


  class ChopTree extends Task
    constructor: (@human, @tree) ->
      throw "dead tree!" if @tree.isDead()
      super(@human)
      @taskIndex = 0

    isComplete: () => @tree.isDead()
    nextAction: () =>
      action = switch @taskIndex
        when 0 then new Action.Chop(@tree)
        else new Action.Rest()
      @taskIndex = (@taskIndex + 1) % 8
      action

  class WalkAndChopTree extends TaskList
    constructor: (@human, @tree) ->
      super(@human, [new WalkNear(@human, @tree.pt(), "tree"), new ChopTree(@human, @tree)])

  Task.CancelledException = CancelledException
  Task.TaskList = TaskList
  Task.WalkNear = WalkNear
  Task.WalkUntilNextTo = WalkUntilNextTo
  Task.Consume = Consume
  Task.Eat     = Eat
  Task.GoHomeAndSleep = GoHomeAndSleep
  Task.Sleep   = Sleep
  Task.Build   = Build
  Task.Construct = Construct
  Task.ChopTree = ChopTree
  Task.WalkAndChopTree = WalkAndChopTree

  Task
