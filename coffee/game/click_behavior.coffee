define [
  'underscore'
  'game/task'
  'game/entity'
], (_, Task, Entity) ->
  class ClickBehavior
    constructor: () ->
    onclick: () -> return
    tooltip: () -> null

  # A tooltip
  # An action to take
  class SelectingClickBehavior extends ClickBehavior
    constructor: (@selection) ->

    onclick: (pt, tile, entity) =>
      if entity and @selection.canSelect(entity)
        @selection.clear()
        @selection.add(entity)

    tooltip: (pt, tile, entity) =>
      if entity and @selection.canSelect(entity)
        "Select."
      else
        null

  class GiveTaskClickBehavior extends ClickBehavior
    constructor: (@playerVision, @selection) ->

    # Returns a task constructor
    # assumes the task constructor takes 2 arguments: [the human, the entity or tile at the given location]
    taskFor: (pt, tile, entity) =>
      entityToControl = @selection.units[0]
      if entityToControl instanceof Entity.Human and entityToControl.vision is @playerVision
        CONTEXT_TASKS = {
          Food:
            task: Task.Eat
            tooltip: "Eat."

          House:
            task: Task.GoHomeAndSleep
            tooltip: "Sleep."

          Tree:
            task: Task.WalkAndChopTree
            tooltip: "Cut down."

          BluePrint:
            task: Task.Construct
            tooltip: "Build."

        }
        defaultTask =
          task: Task.WalkNear
          tooltip: "Walk."
        context = entity?.constructor.name
        CONTEXT_TASKS[context] || defaultTask
      else
        null

    onclick: (pt, tile, entity) =>
      taskInfo = @taskFor(pt, tile, entity)
      if taskInfo
        _.each(@selection.units, (unit) ->
          unit.setCurrentTask(new taskInfo.task(unit, entity || pt))
        )

    tooltip: (pt, tile, entity) => @taskFor(pt, tile, entity)?.tooltip


  class LeftAndRightClickBehavior
    constructor: (@left, @right) ->

    onleftclick: (pt, tile, entity) => @left.onclick(pt, tile, entity)

    onrightclick: (pt, tile, entity) => @right.onclick(pt, tile, entity)

    tooltip: (pt, tile, entity) => 
      rightTooltip = @right.tooltip(pt, tile, entity)
      leftTooltip = @left.tooltip(pt, tile, entity)

      tooltips = []

      tooltips.push("Right-click: #{rightTooltip}") if rightTooltip
      tooltips.push("Left-click: #{leftTooltip}") if leftTooltip

      tooltips

  class DefaultClickBehavior extends LeftAndRightClickBehavior
    constructor: (@world) ->
      left = new SelectingClickBehavior(world.selection)
      right = new GiveTaskClickBehavior(@world.playerVision, world.selection)
      super(left, right)

  ClickBehavior.Default = DefaultClickBehavior

  ClickBehavior
