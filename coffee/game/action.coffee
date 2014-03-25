define [
  'construct'
], (construct) ->

  signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  # returns the Direction for human to face too look at pt
  directionalBetween = (human, pt) ->
    directionalFor({x: pt.x - human.x, y: pt.y - human.y})

  # Returns Left, Right, Up, or Down for the provided offset
  # offset can be distance 0, distance 1, or more than distance 1
  # offset can have diagonals
  #
  # Defaults to looking Down for an empty offset
  directionalFor = (offset) ->
    offset.x = signum(offset.x)
    offset.y = signum(offset.y)

    # Prefer left/right to up/down in diagonals (which shouldn't happen to begin with)
    if offset.x and offset.y
      offset.y = 0

    if not offset.x and not offset.y
      Action.Down

    _.find(Directionals, (direction) -> _.isEqual(direction.offset, offset))


  class Action
    perform: (human) ->
    toString: () => this.constructor.name

  # An action that operates on a subject (usually adjacent to the human)
  class SubjectAction
    constructor: (@subject) ->

    perform: (human) ->
      human.facing = directionalBetween(human, @subject)

  class ConsumeAction extends SubjectAction
    constructor: (@food) -> super(@food)
    perform: (human) ->
      super(human)
      @food.consume(20)
      human.hunger -= 20
      human.tired += 1
      human.affect += 10

  class MoveAction extends Action
    constructor: (@offset, @direction) ->
      throw "Bad direction" if isNaN(@offset.x) or isNaN(@offset.y)
    perform: (human) =>
      moved = human.move(@offset)
      human.hunger += 1
      human.tired += 1
      if not moved
        # TODO this is awful, awful awful
        $(this).trigger("failed")

  LeftAction = new MoveAction({x: -1, y: 0}, "Left")
  RightAction = new MoveAction({x: 1, y: 0}, "Right")
  UpAction = new MoveAction({x: 0, y: -1}, "Up")
  DownAction = new MoveAction({x: 0, y: 1}, "Down")

  Directionals = [LeftAction, RightAction, UpAction, DownAction]

  # the "do nothing" action
  class RestAction extends Action
    perform: (human) ->
      human.tired += .1
      human.hunger += 1

    toString: () -> null

  class SleepAction extends Action
    perform: (human) ->
      human.tired -= 4
      human.hunger += .2
      safetyLevel = human.getSafetyLevel()
      if safetyLevel > 1
        human.affect += 3
      else if safetyLevel >= 0
      else if safetyLevel < -1
        human.affect -= 3

  class ChopAction extends SubjectAction
    constructor: (@tree) -> super(@tree)
    perform: (human) ->
      super(human)
      @tree.chop()
      human.tired += 5
      human.hunger += 3

  Action.Consume = ConsumeAction

  Action.Directionals = Directionals
  Action.directionalFor = directionalFor

  Action.Left = LeftAction
  Action.Right = RightAction
  Action.Up = UpAction
  Action.Down = DownAction

  Action.Rest = RestAction
  Action.Sleep = SleepAction

  Action.Chop = ChopAction

  return Action
