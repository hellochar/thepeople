# Methods for searching through a state space with transition "actions"

define [
  'underscore'
  'pathfinding'
  'game/action'
], (_, PathFinding, Action) ->

  NoSolution = {}

  # immutable class representing a path to get to an end state
  class Path
    constructor: (@states) ->
      @endState = _.last(@states)
    addSegment: (state) =>
      new Path(@states.concat([state]))

  # returns the Path to get from start to the closest goal that satisfies the predicate
  # throws NoSolution if no such path exists (goalPredicate could always evaluate to false, or
  # there could be no path)
  #
  # properties:
  #   start: State
  #   goalPredicate: (state) -> true iff state is a goal
  #   successors: (state) -> [States] that are valid neighbors
  #   hashFunction: (state) -> a string that uniquely represents state
  #
  # returns an array of states [start, ..., end] that goes from start to end only using successors
  # returns null if no place exists
  bfs = (properties) ->
    {start: start, goalPredicate: goalPredicate, hashFunction: hashFunction, successors: successors} = properties

    queue = [new Path([start])]
    visited = {}
    while not _.isEmpty(queue)
      path = queue.shift()

      continue if visited[hashFunction(path.endState)]
      visited[hashFunction(path.endState)] = true

      if goalPredicate(path.endState)
        return path.states
      else
        queue.push(path.addSegment(newState)) for newState in successors(path.endState) # [Action.Left, Action.Right, Action.Up, Action.Down]

    return null

  # Assumes Goal is walkable, Entity is in world
  # makeGoalWalkable - set walkability of the goal to be true when finding a path to it
  # Returns array of MoveActions for entity to take to go to goal
  # throws NoSolution if entity cannot get there
  findPathTo = (entity, goal, makeGoalWalkable = false) ->
    throw "Not in world!" unless entity.world?

    return [] if entity.x is goal.x and entity.y is goal.y

    map = entity.world.map

    # Remove the Entity from pathfinding so it doesn't block itself
    map.notifyLeaving(entity)
    if makeGoalWalkable
      oldValue = map.pathfindingMatrix[goal.y][goal.x]
      map.pathfindingMatrix[goal.y][goal.x] = 0
    grid = new PathFinding.Grid(map.width, map.height, map.pathfindingMatrix)
    map.notifyEntering(entity)
    if makeGoalWalkable
      map.pathfindingMatrix[goal.y][goal.x] = oldValue

    throw "Goal isn't walkable!" if not grid.isWalkableAt(goal.x, goal.y)

    finder = new PathFinding.AStarFinder()
    # [ [x, y], [x, y], [x, y] ]
    states = finder.findPath(entity.x, entity.y, goal.x, goal.y, grid)

    # states is empty iff there's no way to walk to the goal
    # for now just don't walk anywhere
    # in the future make him walk as close as possible
    throw NoSolution if _.isEmpty(states)

    getActionsFromPoints(states)

  # points: [ {x, y} or [x, y] ]
  getActionsFromPoints = (points) ->
    findActionFor = (from, to) ->
      offset =
        if _.isArray(from)
          {x: to[0] - from[0], y: to[1] - from[1]}
        else if _.isObject(from)
          {x: to.x - from.x, y: to.y - from.y}
      Action.directionalFor(offset)

    for i in [0...points.length - 1]
      action = findActionFor( points[i], points[i + 1] )
      debugger if not action
      action


  Search = {
    bfs: bfs
    findPathTo: findPathTo
    getActionsFromPoints: getActionsFromPoints
    NoSolution: NoSolution
  }

  return Search
