# Methods for searching through a state space with transition "actions"

define [
  'underscore'
  'action'
], (_, Action) ->

  # immutable class representing a path to get to an end state
  class Path
    constructor: (@endState, @actions = []) ->
    addSegment: (action) =>
      newLoc = {x: @endState.x + action.offset.x, y: @endState.y + action.offset.y}
      new Path(newLoc, @actions.concat([action]))

  # returns an array of actions to get from start to within the distance threshold

  bfs = (properties) ->
    {start: start, goalPredicate: goalPredicate, entity: entity} = properties

    queue = [new Path(start)]
    visited = {} # keys are JSON.stringify({x, y}) objects
    while not _.isEmpty(queue)
      path = queue.shift()

      continue if visited[JSON.stringify(path.endState)]
      visited[JSON.stringify(path.endState)] = true

      if goalPredicate(path.endState)
        return path.actions
      else
        for action in [Action.Left, Action.Right, Action.Up, Action.Down]
          newPath = path.addSegment(action)
          if entity.canOccupy(newPath.endState.x, newPath.endState.y)
            queue.push(newPath)
    return null

  findPath = (entity, goalPredicate) ->
    return bfs(
      entity: entity
      start: _.pick(entity, "x", "y")
      goalPredicate: goalPredicate
    )


  Search = {
    findPath: findPath
  }

  return Search
