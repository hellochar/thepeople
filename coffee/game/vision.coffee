define [
  'underscore'
], (_) ->
  class Vision
    constructor: (@world) ->
      @emitters = []

      @visibleTilesCache = null
      @visibleEntitiesCache = null

      # All entities you have seen previously, but cannot currently see
      @rememberedEntities = []

      lastVisibleTiles = []
      lastVisibleEntities = []
      $(@world).on("prestep", () =>
        lastVisibleTiles = @getVisibleTiles()
        lastVisibleEntities = @getVisibleEntities()
      )

      $(@world).on("poststep", () =>
        @visibleTilesCache = null
        @visibleEntitiesCache = null
        # update the vision of tiles
        # 1. visible tiles are just the visible tiles
        # 2. remembered tiles are visible last frame but not visible now
        tile.visionInfo = 2 for tile in @getVisibleTiles()
        tile.visionInfo = 1 for tile in _.difference(lastVisibleTiles, @getVisibleTiles())

        # to update seenEntities
        # 1. remove entities remembered last frame that *should* be visible now but aren't
        # 2. remove entities remembered last frame but visible now
        # 3. add in entities visible last frame but not visible now
        @rememberedEntities = _.reject(@rememberedEntities, (entity) =>
          # the tile in his location is visible
          shouldSee = _.findWhere(@getVisibleTiles(), _.pick(entity, "x", "y"))?
          isSeeing = _.contains(@getVisibleEntities(), entity)
          shouldSee and not isSeeing
        )

        # O( # of remembered entities ) <-- this is better but could be bad
        @rememberedEntities = _.difference(@rememberedEntities, @getVisibleEntities())
        @rememberedEntities = @rememberedEntities.concat(_.difference(lastVisibleEntities, @getVisibleEntities()))
      )


    # Emitters must have a findTilesWithin, findEntitiesWithin and sightRange
    addVisibilityEmitter: (emitter) =>
      @emitters.push(emitter)

    removeVisibilityEmitter: (emitter) =>
      @emitters = _.without(@emitters, emitter)

    getVisibleTiles: () =>
      recomputeVisibleTiles = () =>
        allTiles =
          for emitter in @emitters
            emitter.findTilesWithin(emitter.sightRange)
        _.union(allTiles...)
      if not @visibleTilesCache
        @visibleTilesCache = recomputeVisibleTiles()
      @visibleTilesCache

    getVisibleEntities: () =>
      recomputeVisibleEntities = () =>
        allEntities =
          for emitter in @emitters
            emitter.findEntitiesWithin(emitter.sightRange)
        _.union(allEntities...)
      if not @visibleEntitiesCache
        @visibleEntitiesCache = recomputeVisibleEntities()
      @visibleEntitiesCache

    isSurviving: () =>
      _.any(@world.entities, (ent) => ent.vision is this)

    getRememberedEntities: () =>
      @rememberedEntities

    getKnownEntities: () =>
      @rememberedEntities.concat(@getVisibleEntities())

  Vision
