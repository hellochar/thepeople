"use strict";

require [
  'jquery',
  'underscore'
  'backbone'
  'stats'
  'canvasquery'
  'canvasquery.framework'
  'construct'
  'rectangle'
  'game/action'
  'search'
  'game/map'
  'game/entity'
  'game/drawable'
  'game/task'
  'game/vision'
], ($, _, Backbone, Stats, cq, eveline, construct, Rectangle, Action, Search, Map, Entity, Drawable, Task, Vision) ->

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  Math.distance = (a, b) ->
    Math.abs(a.x - b.x) + Math.abs(a.y - b.y)

  class World
    constructor: (@width, @height, tileTypeFor) ->
      @age = 0
      @map = new Map(@, tileTypeFor)
      @playerVision = new Vision(this)

      @entities = []
      @addEntity(new Entity.House(10, 10))
      @human = @addEntity(new Entity.Human(10, 11, @playerVision))

    addEntity: (entity) =>
      entity.world = this
      entity.birth = @age
      @entities.push(entity)
      entity.vision.addVisibilityEmitter(entity) if entity.emitsVision()
      @map.notifyEntering(entity)
      entity.initialize()
      entity

    removeEntity: (entity) =>
      idx = @entities.indexOf(entity)
      @entities.splice(idx, 1)
      entity.vision.removeVisibilityEmitter(entity) if entity.emitsVision()
      @map.notifyLeaving(entity)
      entity

    withinMap: (x, y) => @map.withinMap(x, y)

    # Returns true iff the spot is free space
    isUnoccupied: (x, y) =>
      return @map.isUnoccupied(x, y)

    # TODO make this O(1) by caching entityAt's and only updating them
    # when an Entity moves
    entityAt: (x, y) =>
      return null if not @withinMap(x, y)

      for e in @entities
        rect = e.getHitbox()
        if rect.within(x, y)
          return e

      return null

    stepAll: () =>
      $(this).trigger("prestep")
      for entity in @entities
        entity.step()
      $(this).trigger("poststep")
      @age += 1

    drawAll: (cq) =>
      # ((cell.draw(cq) for cell in row) for row in @map)
      # for entity in @entities
      #   entity.draw(cq)
      cell.draw(cq) for cell in @playerVision.getVisibleTiles()
      for entity in @playerVision.getVisibleEntities()
        entity.draw(cq)

      cq.context.globalAlpha = 0.5
      # now draw only the remembered ones
      cell.draw(cq) for cell in @playerVision.getRememberedTiles()
      e.draw(cq) for e in @playerVision.getRememberedEntities()

      cq.context.globalAlpha = 1.0



  class Grass extends Map.Tile
    dependencies: () -> []
    getSpriteLocation: (deps) -> { x: 21, y: 4 }

  class DryGrass extends Map.Tile
    dependencies: () => @neighbors()

    maybeGrassSprite: (namedDeps) =>
      left = (namedDeps.left is Grass)
      right = (namedDeps.right is Grass)
      up = (namedDeps.up is Grass)
      down = (namedDeps.down is Grass)
      if left
        if up
          {x: 24, y: 5}
        else if down
          {x: 24, y: 4}
        else
          {x: 22, y: 4}
      else if right
        if up
          {x: 23, y: 5}
        else if down
          {x: 23, y: 4}
        else
          {x: 20, y: 4}
      else if down #we've accounted for down-left and down-right already
        {x: 21, y: 3}
      else if up # same w/ up-left and up-right
        {x: 21, y: 5}
      else
        null

    maybeWallSprite: (namedDeps) =>
      down = (namedDeps.down == Wall)
      if down
        {x: 23, y: 10}
      else
        null

    getSpriteLocation: (deps) =>
      namedDeps = {left: deps[0], right: deps[1], up: deps[2], down: deps[3]}
      @maybeGrassSprite(namedDeps) || @maybeWallSprite(namedDeps) || {x: 21, y: 0}

  class Wall extends Map.Tile
    @colliding: true

    dependencies: () => @neighbors()

    maybeDryGrassSprite: (namedDeps) =>
      down = namedDeps.down is DryGrass
      if down
        {x: 23, y: 13}
      else
        null

    getSpriteLocation: (deps) =>
      namedDeps = {left: deps[0], right: deps[1], up: deps[2], down: deps[3]}
      # [ {x: 22, y: 6}, {x: 23, y: 6}, {x: 22, y: 7}, {x: 23, y: 7} ]
      @maybeDryGrassSprite(namedDeps) || {x: 22, y: 6}



  setupWorld = () ->
    world = new World(60, 60, (x, y) ->
      if y % 12 <= 1 && (x + y) % 30 > 5
        Wall
      else if Math.sin(x*y / 100) > .90
        Grass
      else
        DryGrass
    )
    for x in [0...world.width]
      for y in [0...world.height] when Math.sin((x + y) / 8) * Math.cos((x - y) / 9) > .9
        if world.isUnoccupied(x, y)
          food = new Entity.Food(x, y)
          world.addEntity(food)

    world

  setupDebug = (framework) ->
    {world: world, renderer: renderer} = framework
    statsStep = new Stats()
    statsStep.setMode(0)
    statsStep.domElement.style.position = 'absolute'
    statsStep.domElement.style.left = '0px'
    statsStep.domElement.style.top = '0px'

    statsRender = new Stats()
    statsRender.setMode(0)
    statsRender.domElement.style.position = 'absolute'
    statsRender.domElement.style.left = '0px'
    statsRender.domElement.style.top = '50px'

    $(world).on('prestep', () -> statsStep.begin())
    $(world).on('poststep', () -> statsStep.end())
    $(world).on('prerender', () -> statsRender.begin())
    $(world).on('postrender', () -> statsRender.end())

    $("body").append( statsStep.domElement )
    $("body").append( statsRender.domElement )


  class Renderer
    CELL_PIXEL_SIZE = 32
    constructor: (@world) ->
      @camera = {
        x: 0
        y: 0
      }

    render: (cq, delta, keys, mouseX, mouseY) =>
      # oh god this is so bad
      cq.CELL_PIXEL_SIZE = CELL_PIXEL_SIZE
      $(@world).trigger("prerender")

      mapping = {
        w: () => @camera.y += 1 * delta / 32
        s: () => @camera.y -= 1 * delta / 32
        a: () => @camera.x += 1 * delta / 32
        d: () => @camera.x -= 1 * delta / 32
      }

      for key, fn of mapping
        fn() if keys[key]
      cq.clear("black")
      cq.save()
      cq.translate(@camera.x * CELL_PIXEL_SIZE, @camera.y * CELL_PIXEL_SIZE)
      @world.drawAll(cq)


      pt = @cellPosition(mouseX, mouseY)
      if @world.human.canOccupy(pt.x, pt.y) then cq.fillStyle("green") else cq.fillStyle("red")
      cq.globalAlpha(0.5).fillRect(pt.x * CELL_PIXEL_SIZE, pt.y * CELL_PIXEL_SIZE, CELL_PIXEL_SIZE, CELL_PIXEL_SIZE)
      cq.restore()

      $(@world).trigger("postrender")

    cellPosition: (canvasX, canvasY) =>
      x: canvasX / CELL_PIXEL_SIZE - @camera.x | 0
      y: canvasY / CELL_PIXEL_SIZE - @camera.y | 0




  framework = {
    setup: () ->
      @world = setupWorld()
      @renderer = new Renderer(@world)

      @keys = {}
      @mouseX = 0
      @mouseY = 0

      @cq = cq().framework(this, this)
      @cq.canvas.width = (@cq.canvas.width * 0.7) | 0
      @cq.canvas.oncontextmenu = () -> false
      @cq.appendTo("#viewport")

      setupDebug(this)

    onstep: (delta, time) ->
      @world.stepAll()
      if @world.human.isDead()
        console.log("You died!")

    stepRate: 20

    onrender: (delta, time) ->
      @renderer.render(@cq, delta, @keys, @mouseX, @mouseY)

    # window resize
    onresize: (width, height) ->
      # resize canvas with window
      # change camera transform
      if @cq
        @cq.canvas.height = height
        @cq.canvas.width = (width * 0.7) | 0

    onmousedown: (x, y, button) ->
      pt = @renderer.cellPosition(x, y)
      @world.human.currentTask = new Task.WalkNear(@world.human, pt)

    onmousemove: (x, y) ->
      @mouseX = x
      @mouseY = y

    onmousewheel: (delta) ->
      # CELL_PIXEL_SIZE *= Math.pow(1.05, delta)

    # keyboard events
    onkeydown: (key) ->
      @keys[key] = true

      # returns an Entity or null if you can't build there
      tryConstruct = (human, entityType, args) ->
        entity = construct(entityType, args)
        if human.world.map.hasRoomFor(entity)
          entity
        else
          null

      if key is 'b'
        pt = @renderer.cellPosition(@mouseX, @mouseY)
        house = tryConstruct(@world.human, Entity.House, [pt.x, pt.y, @world.playerVision])
        if house
          # TODO this is only a preventative measure
          # need to add the actual logic inside the Task itself to ensure that it doesn't happen
          @world.human.currentTask = new Task.Construct(@world.human, house)
      else if key is 'h'
        @world.human.currentTask = new Task.GoHome(@world.human)
      else if key is 'q'
        pt = @renderer.cellPosition(@mouseX, @mouseY)
        human = tryConstruct(@world.human, Entity.Human, [pt.x, pt.y, @world.playerVision])
        if human
          @world.human.currentTask = new Task.Construct(@world.human, human)

    onkeyup: (key) ->
      delete @keys[key]
  }

  $(() ->
    framework.setup()
  )
