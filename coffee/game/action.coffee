define [
  'construct'
], (construct) ->
  class Action
    perform: (human) ->
    toString: () => this.constructor.name

  class ConsumeAction extends Action
    constructor: (@food) ->
    perform: (human) ->
      @food.consume(20)
      human.hunger -= 20
      human.tired += 1
      human.affect += 10

  class MoveAction extends Action
    constructor: (@offset, @direction) ->
      throw "Bad direction" if isNaN(@offset.x) or isNaN(@offset.y)
    perform: (human) =>
      human.move(@offset)
      human.facing = this
      human.hunger += 1
      human.tired += 1

  LeftAction = new MoveAction({x: -1, y: 0}, "Left")
  RightAction = new MoveAction({x: 1, y: 0}, "Right")
  UpAction = new MoveAction({x: 0, y: -1}, "Up")
  DownAction = new MoveAction({x: 0, y: 1}, "Down")

  # the "do nothing" action
  class RestAction extends Action
    perform: (human) ->
      human.tired += .1
      human.hunger += 1

    toString: () -> null

  class SleepAction extends Action
    perform: (human) ->
      safetyLevel = human.getSafetyLevel()
      if safetyLevel > 1
        human.tired -= 3
        human.affect += 3
      else if safetyLevel >= 0
        human.tired -= 3
      else if safetyLevel < -1
        human.tired -= 1.5
        human.affect -= 3

      human.hunger += .2

  Action.Consume = ConsumeAction

  Action.Directionals = [LeftAction, RightAction, UpAction, DownAction]

  Action.Left = LeftAction
  Action.Right = RightAction
  Action.Up = UpAction
  Action.Down = DownAction

  Action.Rest = RestAction
  Action.Sleep = SleepAction

  return Action
