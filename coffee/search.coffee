# Methods for searching through a state space with transition "actions"

define [
  'underscore'
  'pathfinding'
  'game/action'
], (_, PathFinding, Action) ->

  NoSolution = {}

  # immutable class representing a path to get to an end state
  class Path
    constructor: (@endState, @actions = []) ->
    addSegment: (action) =>
      newLoc = {x: @endState.x + action.offset.x, y: @endState.y + action.offset.y}
      new Path(newLoc, @actions.concat([action]))

  # returns the Path to get from start to the closest goal that satisfies the predicate
  # throws NoSolution if no such path exists (goalPredicate could always evaluate to false, or
  # there could be no path)
  bfs = (properties) ->
    {start: start, goalPredicate: goalPredicate, entity: entity} = properties

    queue = [new Path(start)]
    visited = {} # keys are JSON.stringify({x, y}) objects
    while not _.isEmpty(queue)
      path = queue.shift()

      continue if visited[JSON.stringify(path.endState)]
      visited[JSON.stringify(path.endState)] = true

      if goalPredicate(path.endState)
        return path
      else
        for action in [Action.Left, Action.Right, Action.Up, Action.Down]
          newPath = path.addSegment(action)
          if entity.canOccupy(newPath.endState.x, newPath.endState.y)
            queue.push(newPath)
    throw NoSolution

  # Assumes Goal is walkable, Entity is in world
  # Returns array of MoveActions for entity to take to go to goal
  # throws NoSolution if entity cannot get there
  findPathTo = (entity, goal) ->
    throw "Not in world!" unless entity.world?

    return [] if entity.x is goal.x and entity.y is goal.y

    map = entity.world.map

    # Remove the Entity from pathfinding so it doesn't block itself
    map.notifyLeaving(entity)
    grid = new PathFinding.Grid(map.width, map.height, map.pathfindingMatrix)
    map.notifyEntering(entity)

    throw "Goal isn't walkable!" if not grid.isWalkableAt(goal.x, goal.y)

    finder = new PathFinding.AStarFinder()
    # [ [x, y], [x, y], [x, y] ]
    states = finder.findPath(entity.x, entity.y, goal.x, goal.y, grid)

    # states is empty iff there's no way to walk to the goal
    # for now just don't walk anywhere
    # in the future make him walk as close as possible
    throw NoSolution if _.isEmpty(states)


    findActionFor = (from, to) ->
      offset = {x: to[0] - from[0], y: to[1] - from[1]}
      _.find(Action.Directionals, (direction) -> _.isEqual(direction.offset, offset))

    for i in [0...states.length - 1]
      action = findActionFor( states[i], states[i + 1] )
      debugger if not action
      action


  Search = {
    bfs: bfs
    findPathTo: findPathTo
    NoSolution: NoSolution
  }

  return Search
