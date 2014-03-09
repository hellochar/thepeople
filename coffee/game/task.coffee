define [
  'underscore'
  'game/action'
  'game/entity'
  'search'
], (_, Action, Entity, Search) ->
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

    toString: () => @currentTask().toString()

  class WalkNear extends Task

    constructor: (@human, @pt, @subject) ->
      super(@human)
      throw "Point is actually a #{@pt}" unless (_.isNumber(@pt.x) && _.isNumber(@pt.y))
      @pt = @human.world.map.closestAvailableSpot(@human, _.pick(@pt, "x", "y"))

      # this should never happen
      throw "There is no place for you to go!" unless @pt?

      try
        @actions = Search.findPathTo(@human, @pt)
      catch
        console.log("no path!")
        @actions = []

    toString: () => if @subject then "Walking to #{@subject}" else "Walking"

    isComplete: () => _.isEmpty(@actions)

    nextAction: () =>
      return @actions.shift()

  class WalkUntilNextTo extends WalkNear
    # Assumes the entity doesn't move
    constructor: (@human, @entity) ->
      super(@human, _.pick(@entity, "x", "y"), @entity.constructor.name)

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

  class GoHome extends WalkNear
    constructor: (@human) ->
      # find closest free bed and sleep
      House = @human.constructor.__super__.constructor.House
      houses = _.filter(@human.getKnownEntities(), (b) -> b instanceof House)
      freeBeds = _.flatten(
        _.map(houses, (b) => b.getFreeBeds(@human))
      )
      closestBed = _.min(freeBeds, @human.distanceTo)
      super(@human, closestBed, "Home")

  class Sleep extends Task
    constructor: (@human) ->
      super(@human)

    isComplete: () => @human.tired <= 0
    nextAction: () => new Action.Sleep()

  class Build extends Task
    constructor: (@human, @entity) ->
      super(@human)
      throw "Bad entity" if not @entity
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
      @turnsLeft = 10

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
    nextAction: () =>
      if not @human.world.map.hasRoomFor(@entity)
        @cancel("No room to build #{@entity.constructor.name}!")
      if not @entity.isNeighbor(@human)
        @cancel("#{@human.constructor.name} cannot reach building!")
      new BuildAction(this)

  # Walk to an unplaced Entity and Build it
  class Construct extends TaskList
    constructor: (@human, @entity) ->
      super(@human, [new WalkUntilNextTo(@human, @entity), new Build(@human, @entity)])

  Task.CancelledException = CancelledException
  Task.TaskList = TaskList
  Task.WalkNear = WalkNear
  Task.WalkUntilNextTo = WalkUntilNextTo
  Task.Consume = Consume
  Task.Eat     = Eat
  Task.GoHome  = GoHome
  Task.Sleep   = Sleep
  Task.Build   = Build
  Task.Construct = Construct

  Task
