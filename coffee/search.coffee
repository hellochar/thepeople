# Methods for searching through a state space with transition "actions"

define [
  'underscore'
  'pathfinding'
  'action'
], (_, PathFinding, Action) ->

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

  findPathTo = (entity, goal) ->
    map = entity.world.map
    matrix = map.pathfindingMatrix


    grid = new PathFinding.Grid(map.width, map.height, matrix)
    finder = new PathFinding.AStarFinder()
    # [ [x, y], [x, y], [x, y] ]
    states = finder.findPath(entity.x, entity.y, goal.x, goal.y, grid)


    findActionFor = (from, to) ->
      offset = {x: to[0] - from[0], y: to[1] - from[1]}
      _.find(Action.Directionals, (direction) -> _.isEqual(direction.offset, offset))

    for i in [0...states.length - 1]
      action = findActionFor( states[i], states[i + 1] )
      debugger if not action
      action


  Search = {
    findPath: findPath
    findPathTo: findPathTo
  }

  return Search
