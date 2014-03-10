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
        Food: Task.Eat
        House: Task.GoHome
      }
      defaultTask = Task.WalkNear
      context = entity?.constructor.name
      taskConstructor = CONTEXT_TASKS[context] || defaultTask


    onrightclick: (pt) ->
      taskType = @rightclickTask(pt)
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
      ["Right-click: #{@rightclickTask(pt).name}"]

  ClickBehavior.Default = DefaultClickBehavior

  ClickBehavior
