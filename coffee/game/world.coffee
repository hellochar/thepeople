define [
  'game/entityqueue'
  'game/vision'
  'game/selection'
  'game/entity'
  'game/map'
], (EntityQueue, Vision, Selection, Entity, Map) ->

  class World
    constructor: (@width, @height) ->
      # Age is the number of seconds this World has been stepped for
      @age = 0
      @map = new Map(@)

      # A list of entities, in no particular order
      @entities = []

      # Holds array of {time: Number, entity: Entity to step}
      @entityQueue = new EntityQueue()

      @playerVision = new Vision(this)
      @selection = new Selection([], @playerVision, this)

    addEntity: (entity) =>
      newLoc = @map.closestAvailableSpot(entity)
      throw "oh god no" if not newLoc
      entity.x = newLoc.x
      entity.y = newLoc.y
      console.log("#{entity} still cannot be put there!") unless @map.hasRoomFor(entity)
      entity.world = this
      entity.birth = @age
      @entities.push(entity)
      entity.vision.addVisibilityEmitter(entity) if entity.emitsVision()
      @map.notifyEntering(entity)
      @entityQueue.enqueue(entity, @age) if entity.step
      properties = entity.properties
      delete entity.properties
      entity.initialize(properties)
      entity

    removeEntity: (entity) =>
      idx = @entities.indexOf(entity)
      @entities.splice(idx, 1)
      entity.vision.removeVisibilityEmitter(entity) if entity.emitsVision()
      @entityQueue.removeEntity(entity)
      @map.notifyLeaving(entity)
      entity

    withinMap: (x, y) => @map.withinMap(x, y)

    # TODO make this O(1) by caching entityAt's and only updating them
    # when an Entity moves
    entityAt: (x, y) =>
      return null if not @withinMap(x, y)

      for e in @entities
        rect = e.getHitbox()
        if rect.within(x, y)
          return e

      return null

    # Step the entire world by duration seconds
    stepAll: (duration) =>
      $(this).trigger("prestep")

      now = @age
      endTime = now + duration

      # set now = 2.3, taken = step human 1, add now + taken to entityQueue
      # if closest time > 3.0 (start + timeStep)
      #   set now = 3.0, poststep

      nextEntry = @entityQueue.peek()
      while nextEntry and nextEntry.time < endTime
        @entityQueue.dequeue()
        now = nextEntry.time
        timeTaken = nextEntry.entity.step()
        @entityQueue.enqueue(nextEntry.entity, now + timeTaken)
        nextEntry = @entityQueue.peek()

      @age += duration
      $(this).trigger("poststep")

