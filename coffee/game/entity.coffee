define [
  'rectangle'
  'game/action'
  'game/task'
  'game/drawable'
], (Rectangle, Action, Task, Drawable) ->

  class Entity extends Drawable
    constructor: (@x, @y, @vision) ->
      super(@x, @y)
      @sightRange = @constructor.sightRange
      # array of {age: age(), thought: string}
      @thoughts = []

    pt: () =>
      x: @x
      y: @y

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

    think: (str) =>
      @thoughts.unshift({age: @age(), thought: str})

    # Get all thoughts in the past 100 steps (about 10 seconds), limited to 20
    getRecentThoughts: () =>
      _.filter(@thoughts, (thought) => @age() - thought.age < 200)[0...20]

    # Returns the number of frames this entity has been alive for
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

    step: () =>

  class Tree extends Entity
    constructor: () ->
      super(arguments...)
      @spriteLocation = ((pt) ->
        () ->
          {x: pt.x, y: pt.y, dx: -1, dy: -1, width: 2, height: 2}
      )(_.sample([{x: 14, y: 13}, {x: 12, y: 14}]))

    @hitbox: {x: -1, y: 0, width: 2, height: 1}

  class House extends Entity
    spriteLocation: () => [
      { x: 1, y: 16, dx:  0, dy:  0 }
      { x: 0, y: 15, dx: -1, dy:  0 }
      { x: 5, y: 13, dx:  0, dy: -1 }
      { x: 4, y: 13, dx: -1, dy: -1 }
    ]

    @sightRange: 3

    # Beds not currently occupied
    # A bed is actually just a location adjacent to my pt
    getFreeBeds: (human) =>
      beds = [{ x: @x + 1, y: @y},
              { x: @x, y: @y + 1}]
      _.filter(beds, (pt) => @world.map.canOccupy(human, pt.x, pt.y))

    @hitbox: {x: -1, y: -1, width: 2, height: 2}

  class Food extends Entity
    constructor: (@x, @y) ->
      super(@x, @y)
      @amount = 300

    consume: (amount) =>
      @amount -= amount
      if @amount <= 0
        @die()

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
            @think("I'm hungry. Time to eat!")
            new Task.Eat(this, closestFood)
          else
            @think("I'm hungry but there's no food!")
            false
        )

      if @tired > 300
        tasks.push( () =>
          closestHomeWithFreeBed = houses = _.filter(@getKnownEntities(), (b) => b instanceof House and not _.isEmpty(b.getFreeBeds(this)))[0]
          if closestHomeWithFreeBed
            @think("I'm tired! Time to sleep!")
            new Task.GoHomeAndSleep(this, closestHomeWithFreeBed)
          else
            @think("I'm tired but there's no place to sleep!")
        )

      tasks


    setCurrentTask: (task) =>
      throw "Bad task #{task}" unless task instanceof Task # also catches nulls

      return if task is @currentTask
      return if task.isComplete()

      @currentTask = task
      @think(task.thought?() || task.toString())

    # call this to notify the entity that its current task got cancelled
    currentTaskCancelled: (err) =>
      @think("I can't #{@currentTask.toString()} because #{err.reason}")
      @currentTask = null

    #call this to notify the entity that its current task just finished
    currentTaskCompleted: () =>
      @currentTask = null

    getAction: () =>
      tasks = @possibleTasks()

      # find the first task that isn't complete and start doing it
      for taskFn in tasks
        task = taskFn()
        if task && not task.isComplete()
          doableTask = task
          break
      if doableTask
        @setCurrentTask(doableTask)
        try
          return @currentTask.nextAction()
        catch err
          if err instanceof Task.CancelledException
            @currentTaskCancelled(err)
            return new Action.Rest()
          else
            throw err
      else
        # this happens when your currentTask was just assigned but it is already complete
        # TODO get rid of this; it should never happen
        @currentTaskCompleted()
        return new Action.Rest()

    step: () =>
      action = @getAction()
      action.perform(this)
      @currentAction = action
      if @currentTask && @currentTask.isComplete()
        # @think("Finished #{@currentTask}!")
        @currentTaskCompleted()

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

    draw: (renderer) =>
      super(renderer)
      cq = renderer.cq
      CELL_PIXEL_SIZE = renderer.CELL_PIXEL_SIZE
      # actionString = if @currentAction.toString() then @currentAction.toString() + ", " else ""
      # taskString = if @currentTask then @currentTask.toString() + ", " else ""
      # text = "#{taskString}#{@hunger | 0} hunger, #{@tired | 0} tired"
      # cq.fillStyle("red").font('normal 20pt arial').fillText(text, @x*CELL_PIXEL_SIZE, @y*CELL_PIXEL_SIZE)

      renderer.drawTextBox(_.pluck(@getRecentThoughts()[0...1], "thought"), (@x+0.5)*CELL_PIXEL_SIZE, @y * CELL_PIXEL_SIZE)

      # for thought, idx in @getRecentThoughts()
      #   xmin = @x*CELL_PIXEL_SIZE
      #   width = 140
      #   ymin = (@y - 1)*CELL_PIXEL_SIZE - (idx * 14)
      #   height = 14



  Entity.House = House
  Entity.Food = Food
  Entity.Human = Human
  Entity.Tree = Tree

  return Entity
