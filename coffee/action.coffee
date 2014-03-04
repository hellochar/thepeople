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

  class MoveAction extends Action
    constructor: (@direction) ->
      throw "Bad direction" if isNaN(@direction.x) or isNaN(@direction.y)
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

    toString: () -> null

  class SleepAction extends Action
    perform: (human) ->
      human.tired -= 3
      human.hunger += .2

  Action.Consume = ConsumeAction
  Action.Move = MoveAction
  Action.Wander = WanderAction
  Action.Rest = RestAction
  Action.Sleep = SleepAction

  return Action
