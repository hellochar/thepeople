define [
  'rectangle'
  'search'
  'game/action'
  'game/task'
  'game/drawable'
], (Rectangle, Search, Action, Task, Drawable) ->

  FEMALE_NAMES = [
    "Genoveva"
    "Kristin"
    "Neas"
    "Sabia"
    "Gaia"
    "Svanhildr"
    "Carme"
    "Amordad"
    "Daphine"
    "Abbie"
    "Raina"
    "Erlinda"
    "Malia"
    "Bernardina"
    "Marina"
    "Twyla"
    "Davina"
    "Vena"
    "Quiana"
    "Linnea"
    "Tawana"
    "Corrinne"
    "Earnestine"
    "Yen"
    "Maxine"
    "Lahoma"
    "Tatyana"
    "Diedre"
    "Xuan"
    "Mozella"
    "Evonne"
    "Lang"
    "Rossana"
    "Usha"
    "Chasity"
    "Loise"
    "Versie"
    "Raylene"
    "Wei"
    "Elly"
    "Melony"
    "Shauna"
    "Jerrica"
    "Pamela"
    "Mariel"
    "Argelia"
    "Wan"
    "Heather"
    "Mariam"
    "Sallie"
    "Jessenia"
    "Perla"
    "Joannie"
    "Vickey"
    "Andree"
    "Annice"
    "Hiedi"
    "Lucila"
  ]

  MALE_NAMES = [
    "Jed"
    "Cedric"
    "Doug"
    "Stewart"
    "Nathan"
    "Terrell"
    "Hyman"
    "Delmer"
    "Rudolph"
    "Dusty"
    "Zane"
    "King"
    "Elwood"
    "Duncan"
    "Dillon"
    "Rodrick"
    "Harland"
    "Donnie"
    "Theo"
    "Winfred"
    "Zackary"
    "Rogelio"
    "Ramon"
    "Herbert"
    "Vaughn"
    "Henry"
    "Clint"
    "Lon"
    "Sang"
    "Jeffry"
    "Mohamed"
    "Irvin"
    "Jesse"
    "Yong"
    "Casey"
    "Nelson"
    "Kermit"
    "Cliff"
    "Carmen"
    "Everette"
    "Orville"
    "Steve"
    "Fabian"
    "Dannie"
    "Derrick"
    "Gale"
    "Royal"
    "Burton"
    "Arnoldo"
    "Lacy"
  ]

  # Subclasses should implement:
  #   initialize()
  #   hitbox()
  #   step()
  #   spriteLocation()
  class Entity extends Drawable
    constructor: (@x, @y, @vision, properties = {}) ->
      super(@x, @y)
      @sightRange = @constructor.sightRange
      # array of {age: age(), thought: string}
      @thoughts = []

      # A number ranging from ~ -5000 to ~5000 denoting this unit's happiness, or mood
      # Things like eating and sleeping help affect
      # Not finding food, walking while tired, etc. hurt affect
      #
      # Sleeping from 300 tired gives +300 affect
      # Eating 300 food gives 150 affect
      @affect = 0
      @initialize(properties)

    # Put constructor/initialization code here
    # initialize: (properties) =>

    # onbirth gets called when this entity actually gets put into the world
    # world == @world
    onbirth: (world) ->

    ondeath: (world) ->

    # Only move Entities through this method
    move: (offset) =>
      @setLocation(@x + offset.x, @y + offset.y)
      @facing = Action.directionalFor(offset)

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

    think: (str, affect = 0) =>
      @thoughts.unshift({age: @age(), thought: str, affect: affect})
      @affect += affect

    # Get all thoughts in the past 100 steps (about 10 seconds), limited to 20
    getRecentThoughts: () =>
      _.filter(@thoughts, (thought) => @age() - thought.age < 10)[0...20]

    # Returns the number of frames this entity has been alive for
    age: () =>
      if @world
        @world.age - @birth
      else
        0

    emitsVision: () => @vision and @sightRange?

    distanceTo: (cell) =>
      Math.abs(@x - cell.x) + Math.abs(@y - cell.y)

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
    hitbox: () => {x: 0, y: 0, width: 1, height: 1}

    # returns a (x, y, width, height) associated with a specified pt (by default this Entity's location)
    getHitbox: (x = @x, y = @y) =>
      hitbox = @hitbox()
      new Rectangle(x + hitbox.x, y + hitbox.y, hitbox.width || 1, hitbox.height || 1)

    canOccupy: (x, y) =>
      @world.map.canOccupy(this, x, y)

    toString: () =>
      if @world
        "[#{@constructor.name}, age #{@age()} (#{@x}, #{@y})]"
      else
        "[#{@constructor.name}, not in world, (#{@x}, #{@y})]"

    # The step function gets called when it is this entity's turn to
    # move forward. Return the time (in real seconds) it takes to "step"
    # step: () => 1

  class Tree extends Entity
    constructor: () ->
      super(arguments...)
      @health = 25

    spriteLocation: () ->
      x: 13
      y: 20
      spritesheet: "tiles3"

    chop: () ->
      @health -= 10
      if @health <= 0
        @die()
        true
      else
        false

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

    hitbox: () => {x: -1, y: -1, width: 2, height: 2}

  class Food extends Entity
    constructor: (@x, @y) ->
      super(@x, @y)
      @amount = 250

    consume: (amount) =>
      @amount -= amount
      if @amount <= 0
        @die()

    spriteLocation: () =>
      x: 14
      y: 15


  # entity property
  #   shouldn't exist in the world
  #   not null
  #   entity.vision is this vision
  class BluePrint extends Entity
    initialize: (properties) =>
      @entity = properties.entity
      # set the entity's location to where I am
      @entity.x = @x
      @entity.y = @y
      @turnsLeft = @entity.constructor.buildCost || 25

    build: () =>
        @turnsLeft -= 1
        if not @turnsLeft
          @die()
          $(@world).one("poststep", () =>
            if not @world.map.hasRoomFor(@entity)
              throw "BluePrint adding entity but entity can't fit!"
            @world.addEntity(@entity)
          )

    spriteLocation: () => @entity.spriteLocation()

    hitbox: () => @entity.hitbox()


  class Human extends Entity
    @sightRange: 8

    initialize: (properties) =>
      @gender = properties.gender || if Math.random() < .5 then "male" else "female"

      @name = properties.name || _.sample({male: MALE_NAMES, female: FEMALE_NAMES}[@gender])

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

    onbirth: (world) ->
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

    getSafetyLevel: () =>
      # How safe this person feels; 1+ is safe, 0 is some danger, -1 is unsafe
      # Safety is correlated to being close to home (TODO: and by being near other people)
      house = @closestKnown(Entity.House)
      if house
        houseDistance = @distanceTo(house)
        1.2 - houseDistance / 20
      else
        -10

    # Returns the distance of the shortest path to go from you to the entity
    walkDistanceTo: (entity) =>
      return @distanceTo(entity) if @distanceTo(entity) < 2
      try
        path = Search.findPathTo(@, entity.pt(), true)
        return path.length || Infinity
      catch err
        if err is Search.NoSolution
          Infinity
        else
          throw err

    # Find the entity with minimum euclidean distance
    closestKnown: (entityType) =>
      entities = _.filter(@getKnownEntities(), (e) -> e instanceof entityType)
      if not _.isEmpty(entities)
        _.min(entities, @distanceTo)
      else
        null

    # Find the entity with minimum walking distance
    closestWalkable: (entityType) =>
      entities = _.filter(@getKnownEntities(), (e) -> e instanceof entityType)
      if not _.isEmpty(entities)
        closestEntity = _.min(entities, @walkDistanceTo)
        if closestEntity is Infinity then null else closestEntity
      else
        null

    # returns an array of () => (Task or falsy)
    possibleTasks: () =>
      tasks = [ () => @currentTask ]

      if @hunger > 300
        tasks.push( () =>
          closestFood = @closestWalkable(Food)
          if closestFood
            @think("I'm hungry. Time to eat!")
            new Task.Eat(this, closestFood)
          else
            @think("I'm hungry but there's no food!", -3)
            false
        )

      if @tired > 300
        tasks.push( () =>
          houses = _.filter(@getKnownEntities(), (b) => b instanceof House and not _.isEmpty(b.getFreeBeds(this)))
          closestHomeWithFreeBed = if not _.isEmpty(houses) then _.min(houses, @distanceTo) else null
          if closestHomeWithFreeBed
            @think("I'm tired! Time to sleep!")
            new Task.GoHomeAndSleep(this, closestHomeWithFreeBed)
          else
            @think("I'm tired but there's no place to sleep!", -1)
            new Task.Sleep(this)
        )

      tasks


    setCurrentTask: (task) =>
      throw "Bad task #{task}" unless task instanceof Task # also catches nulls

      return if task is @currentTask
      return if task.isComplete()

      @currentTask = task
      @think(task.thought()) if task.thought

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
        if task instanceof Task && not task.isComplete()
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
      tiredBefore = @tired
      hungerBefore = @hunger

      action = @getAction()
      action.perform(this)
      @currentAction = action
      if @currentTask && @currentTask.isComplete()
        # @think("Finished #{@currentTask}!")
        @currentTaskCompleted()
      # The average action takes .08 seconds
      timeTaken = .08 * (if @tired > 500 then 2 + (@tired - 500) / 125 else 1)

      @hunger += timeTaken * .4
      @tired += timeTaken * .2
      if @hunger > 500
        @tired += 3

      if @tired > 500
        @affect -= 1

      if tiredBefore < 500 and @tired > 500
        @think("I'm getting really exhausted!", -800)

      if tiredBefore < 800 and @tired > 800
        @think("I'm going to die of exhaustion!!!", -5000)

      if hungerBefore < 500 and @hunger > 500
        @think("I'm getting really hungry!", -800)

      if hungerBefore < 800 and @hunger > 800
        @think("I'm going to die of hunger!!!", -5000)


      return timeTaken

    relativeSpriteLocation: () =>
      spriteIdx = (@age() * 5) % 4 | 0
      spriteInfo =
        x: [1, 0, 1, 2][spriteIdx]
        y: {Down: 0, Left: 1, Right: 2, Up: 3}[@facing?.direction || "Down"]
        spritesheet: "characters"

      # If we're being built, we don't exist in the world but need to return
      # a valid sprite
      if @world
        if not (@currentAction instanceof Action.Rest) and not (@currentAction instanceof Action.Sleep)
          spriteInfo.dx = @facing.offset.x * .2
          spriteInfo.dy = @facing.offset.y * .2

        if @currentAction instanceof Action.Sleep
          spriteInfo = _.extend(spriteInfo,
            x: 1
            y: 2
            rotation: 90
          )

      spriteInfo

    spriteLocation: () =>
      baseX = {male: 0, female: 9}[@gender]
      baseY = {male: 0, female: 4}[@gender]

      relativeSprite = @relativeSpriteLocation()
      relativeSprite.x += baseX
      relativeSprite.y += baseY

      relativeSprite


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
  Entity.BluePrint = BluePrint

  return Entity
