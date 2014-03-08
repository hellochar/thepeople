define [
  'game/action'
  'game/task'
  'game/drawable'
], (Action, Task, Drawable) ->

  class Entity extends Drawable
    constructor: (@x, @y, @vision) ->
      super(@x, @y)
      @sightRange = @constructor.sightRange

    # Only move Entities through this method
    move: (offset) =>
      @setLocation(@x + offset.x, @y + offset.y)

    # returns true or false if the move actually succeeds
    setLocation: (x, y) =>
      if @canOccupy(x, y)
        @world.map.notifyLeaving(@)
        @x = x
        @y = y
        @world.map.notifyEntering(@)
        @checkConsistency()
        true
      else
        false

    age: () => @world.age - @birth

    emitsVision: () => @vision and @sightRange?

    distanceTo: (cell) =>
      Math.distance(cell, this)

    findTilesWithin: (manhattanDist) =>
      _.flatten((cell.tileInstance for cell in row when @distanceTo(cell.tileInstance) <= manhattanDist) for row in @world.map.cells)

    # Return Entities with distance <= manhattanDist (compares Entity locations, no hitbox information)
    findEntitiesWithin: (manhattanDist) =>
      _.filter(@world.entities, (e) => @distanceTo(e) <= manhattanDist)

    # Returns true iff the given entity's location is within 1 square of this Entity's hitbox
    # NOTE e1.isNeighbor(e2) is not always the same as e2.isNeighbor(e1); if e1 and e2 are both
    # large (bigger than 1 unit hitbox), isNeighbor may return false even though the two entities
    # are touching.
    #
    # Always do biggerEntity.isNeighbor(smallerEntity)
    isNeighbor: (entity) =>
      _.findWhere(@getHitbox().neighbors(), _.pick(entity, "x", "y"))? or _.findWhere(entity.getHitbox().neighbors(), _.pick(this, "x", "y"))?

    checkConsistency: () =>
      throw "bad position" unless @world.withinMap(@x, @y)

    isDead: () => not _.contains(@world.entities, this)

    die: () =>
      $(@world).one("poststep", () =>
        @world.removeEntity(this)
      )

    # optionally, declare a hitbox VALUE on the class
    # hitbox is an {x, y, width, height} which specifies how far left and up the hitbox should go, and its width/height (by default 1/1)
    @hitbox: {x: 0, y: 0, width: 1, height: 1}

    # returns a (x, y, width, height) associated with a specified pt (by default this Entity's location)
    getHitbox: (x = @x, y = @y) =>
      hitbox = @constructor.hitbox
      new Rectangle(x + hitbox.x, y + hitbox.y, hitbox.width || 1, hitbox.height || 1)

    canOccupy: (x, y) =>
      @world.map.canOccupy(this, x, y)

    toString: () =>
      if @world
        "[#{@constructor.name}, age #{@age()} (#{@x}, #{@y})]"
      else
        "[#{@constructor.name}, not in world, (#{@x}, #{@y})]"

    step: () => throw "not implemented"


  class House extends Entity
    spriteLocation: () => [
      { x: 1, y: 16, dx:  0, dy:  0 }
      { x: 0, y: 15, dx: -1, dy:  0 }
      { x: 5, y: 13, dx:  0, dy: -1 }
      { x: 4, y: 13, dx: -1, dy: -1 }
    ]

    @sightRange: 3

    getFreeBeds: (human) =>
      beds = [{ x: @x + 1, y: @y},
              { x: @x, y: @y + 1}]
      _.filter(beds, (pt) => @world.isUnoccupied(pt.x, pt.y))

    @hitbox: {x: -1, y: -1, width: 2, height: 2}

    step: () =>


  class Food extends Entity
    constructor: (@x, @y) ->
      super(@x, @y)
      @amount = 300

    consume: (amount) =>
      @amount -= amount
      if @amount <= 0
        @die()

    step: () =>

    spriteLocation: () =>
      x: 14
      y: 15


  class Human extends Entity
    @sightRange: 10

    initialize: () =>
      # @setLocation(@x, @y)

      # How hungry you are.
      @hunger = 0

      # How tired you are. Will affect your action taking capabilities if you're too tired
      @tired = 0

      # Your current task
      @currentTask = null

      # Should be the last Action you took; used by the Renderer to display info about what you're doing
      @currentAction = new Action.Rest()

      # The class of where you're facing
      @facing = Action.Down

      $(@world).on("poststep", () =>
        if @hunger > 1000 or @tired > 1000
          @die()
      )

    getVisibleTiles: () =>
      @vision.getVisibleTiles()

    getVisibleEntities: () =>
      @vision.getVisibleEntities()

    getKnownEntities: () =>
      @vision.getKnownEntities()

    closestKnown: (entityType) =>
      entities = _.filter(@getKnownEntities(), (e) -> e instanceof entityType)
      if not _.isEmpty(entities)
        _.min(entities, @distanceTo)
      else
        null

    # returns an array of () => (Task or falsy)
    possibleTasks: () =>
      tasks = [ () => @currentTask ]

      if @hunger > 300
        tasks.push( () =>
          closestFood = @closestKnown(Food)
          if closestFood
            new Task.Eat(this, closestFood)
          else
            false
        )

      if @tired > 200
        tasks.push( () =>
          (new Task.GoHome(this)).andThen(new Task.Sleep(this))
        )

      tasks

    getAction: () =>
      tasks = @possibleTasks()

      # find the first task that isn't complete and start doing it
      for taskFn in tasks
        task = taskFn()
        if task && not task.isComplete()
          doableTask = task
          break
      if doableTask
        @currentTask = doableTask
        try
          return @currentTask.nextAction()
        catch err
          if err instanceof Task.CancelledException
            alert("Error: #{err.reason}")
            @currentTask = null
            return new Action.Rest()
          else
            throw err
      else
        @currentTask = null
        return new Action.Rest()

    step: () =>
      action = @getAction()
      action.perform(this)
      @currentAction = action
      if @currentTask && @currentTask.isComplete()
        @currentTask = null

    spriteLocation: () =>
      spriteIdx = (@animationMillis() / 333) % 4 | 0
      spriteInfo =
        x: [10, 9, 10, 11][spriteIdx]
        y: {Down: 4, Left: 5, Right: 6, Up: 7}[@facing.direction]
        spritesheet: "characters"

      if not (@currentAction instanceof Action.Rest) and not (@currentAction instanceof Action.Sleep)
        spriteInfo.dx = @facing.offset.x * .2
        spriteInfo.dy = @facing.offset.y * .2

      if @currentAction instanceof Action.Sleep
        spriteInfo = _.extend(spriteInfo,
          x: 10
          y: 6
          rotation: 90
        )

      spriteInfo

    draw: (cq) =>
      super(cq)
      CELL_PIXEL_SIZE = cq.CELL_PIXEL_SIZE
      actionString = if @currentAction.toString() then @currentAction.toString() + ", " else ""
      taskString = if @currentTask then @currentTask.toString() + ", " else ""
      text = "#{taskString}#{@hunger | 0} hunger, #{@tired | 0} tired"
      cq.fillStyle("red").font('normal 20pt arial').fillText(text, @x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE)



  Entity.House = House
  Entity.Food = Food
  Entity.Human = Human



  Entity
