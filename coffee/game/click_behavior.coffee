define [
  'game/task'
], (Task) ->
  class ClickBehavior
    constructor: (@world) ->

    onleftclick: (cellpt) => throw "not implemented"

    onrightclick: (cellpt) => throw "not implemented"

    tooltip: () => throw "not implemented"


  class DefaultClickBehavior extends ClickBehavior
    constructor: (@world, @keys) ->
      super(@world)

    rightclickTask: (pt) =>
      entity = @world.entityAt(pt.x, pt.y)
      CONTEXT_TASKS = {
        Food: {
          task: Task.Eat
          tooltip: "Eat."
        }
        House:
          task: Task.GoHome
          tooltip: "Go home."
      }
      defaultTask =
        task: Task.WalkNear
        tooltip: "Walk here."
      context = entity?.constructor.name
      CONTEXT_TASKS[context] || defaultTask


    onrightclick: (pt) ->
      {task: taskType} = @rightclickTask(pt)
      entity = @world.entityAt(pt.x, pt.y)
      _.each(@world.selection.units, (unit) ->
        unit.setCurrentTask(new taskType(unit, entity || pt))
      )

    onleftclick: (pt) ->
      entity = @world.entityAt(pt.x, pt.y)
      if entity?.vision is @world.playerVision
        if not @keys["shift"]
          @world.selection.clear()
        @world.selection.add(entity)

    tooltip: (pt) =>
      clicks = []
      entity = @world.entityAt(pt.x, pt.y)
      if entity?.vision is @world.playerVision
        clicks.push("Left-click: select")
      clicks.push("Right-click: #{@rightclickTask(pt).tooltip}")
      clicks

  ClickBehavior.Default = DefaultClickBehavior

  ClickBehavior
