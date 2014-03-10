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
  'game/click_behavior'
  'game/entity'
  'game/drawable'
  'game/task'
  'game/vision'
  'game/unitinfo'
], ($, _, Backbone, Stats, cq, eveline, construct, Rectangle, Action, Search, Map, ClickBehavior, Entity, Drawable, Task, Vision, UnitInfoHandler) ->

  Math.signum = (x) -> if x == 0 then 0 else x / Math.abs(x)

  Math.distance = (a, b) ->
    Math.abs(a.x - b.x) + Math.abs(a.y - b.y)


  # TODO move the Overlay from twoguns over
  # or better yet use a modal?
  overlay = (string) ->
    getOverlay = () ->
      if $("#overlay").length is 0
        $("<div>").css(
          position: "absolute"
          width: "100%"
          height: "100%"
          left: "0px"
          top: "0px"
          "z-index": 1
          "background-color": "rgba(0, 0, 0, .5)"
          "font-size": "50pt"
          color: "white"
          "text-align": "center"
        ).attr("id", "overlay").appendTo("body")
      else $("#overlay")

    getOverlay().text(string)

  class Selection
    constructor: (@units, @world) ->
      @units ||= []
      $(@world).on("poststep", () =>
        remove(unit) for unit in @units when unit.isDead()
      )

    add: (unit) ->
      throw "bad" unless unit instanceof Entity.Human
      @units.push(unit) unless @has(unit)

    remove: (unit) ->
      @units = _.without(@units, unit)

    clear: () => @units = []

    has: (unit) -> unit in @units

  class World
    constructor: (@width, @height, tileTypeFor) ->
      # Age is the number of frames this World has been stepped for
      @age = 0
      @map = new Map(@, tileTypeFor)
      @playerVision = new Vision(this)
      @selection = new Selection()

      @entities = []
      @addEntity(new Entity.House(10, 10))
      starter = @addEntity(new Entity.Human(10, 11, @playerVision))
      @selection.add(starter)

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
    constructor: (@world, @cq, @framework, @CELL_PIXEL_SIZE = 32) ->
      @camera = {
        x: 0
        y: 0
      }
      @cq.context.imageSmoothingEnabled = false
      @cq.context.webkitImageSmoothingEnabled = false
      @cq.context.mozImageSmoothingEnabled = false

    drawWorld: () =>
      topLeftCorner = @cellPosition(0, 0)
      bottomRightCorner = @cellPosition(cq.canvas.width, cq.canvas.height)

      # include the edges
      bottomRightCorner.x += 1
      bottomRightCorner.y += 1

      for x in [Math.max(0, topLeftCorner.x)...Math.min(@world.map.width, bottomRightCorner.x)]
        for y in [Math.max(0, topLeftCorner.y)...Math.min(@world.map.height, bottomRightCorner.y)]
          tile = @world.map.getCell(x, y).tileInstance
          if tile.visionInfo isnt 0
            if tile.visionInfo is 1
              cq.context.globalAlpha = 0.5
              tile.draw(this)
            else if tile.visionInfo is 2
              cq.context.globalAlpha = 1.0
              tile.draw(this)
            else
              throw "bad tile visionInfo #{tile.visionInfo}"

      entitySorter = (e) -> e.y * e.world.width + e.x
      cq.context.globalAlpha = 0.5
      e.draw(this) for e in _.sortBy(@world.playerVision.getRememberedEntities(), entitySorter)
      cq.context.globalAlpha = 1.0
      e.draw(this) for e in _.sortBy(@world.playerVision.getVisibleEntities(), entitySorter)

    drawTextBox: (lines, left, bottom) =>
      return if _.isEmpty(lines)
      FONT_SIZE = 12
      LINE_MARGIN = 5
      lineWidth = Math.min(140, _.max(_.pluck(_.map(lines, (line) => @cq.measureText(line)), "width")))

      width = lineWidth + LINE_MARGIN * 2

      #center horizontally
      left -= width / 2

      height = lines.length * (FONT_SIZE + LINE_MARGIN)
      @cq.fillStyle("rgba(255, 255, 255, .5)").strokeStyle("black").roundRect(left, bottom - height, width, height, 5).fill().stroke()
      @cq.font("normal #{FONT_SIZE}pt arial").fillStyle("black")
      @cq.fillText(line, left + LINE_MARGIN, bottom - idx * (FONT_SIZE + LINE_MARGIN) - LINE_MARGIN / 2, lineWidth) for line, idx in lines


    render: (delta, keys, mouseX, mouseY) =>
      cq = @cq
      # oh god this is so bad
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
      cq.translate(@camera.x * @CELL_PIXEL_SIZE, @camera.y * @CELL_PIXEL_SIZE)
      @drawWorld()


      cellPt = @cellPosition(mouseX, mouseY, true)
      if @world.map.isUnoccupied(cellPt.x, cellPt.y) then cq.fillStyle("green") else cq.fillStyle("red")
      cq.save()
      cq.globalAlpha(0.5).fillRect(cellPt.x * @CELL_PIXEL_SIZE, cellPt.y * @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE)
      for unit in @world.selection.units
        centerX = (unit.x + .5) * @CELL_PIXEL_SIZE
        centerY = (unit.y + .5) * @CELL_PIXEL_SIZE
        cq.strokeStyle("red").lineWidth(3).beginPath().arc(centerX, centerY, @CELL_PIXEL_SIZE * 1.2 / 2, 0, Math.PI * 2).stroke()
      cq.restore()
      mousePt = @cellPosition(mouseX, mouseY, false)
      @drawTextBox(@framework.clickbehavior.tooltip(cellPt), mousePt.x * @CELL_PIXEL_SIZE, mousePt.y * @CELL_PIXEL_SIZE)
      cq.restore()

      $(@world).trigger("postrender")

    cellPosition: (canvasX, canvasY, truncate = true) =>
      x = canvasX / @CELL_PIXEL_SIZE - @camera.x
      y = canvasY / @CELL_PIXEL_SIZE - @camera.y
      x: if truncate then x | 0 else x
      y: if truncate then y | 0 else y

  framework = {
    setup: () ->
      @world = setupWorld()

      @keys = {}
      @mouseX = 0
      @mouseY = 0

      @cq = cq().framework(this, this)
      @cq.canvas.width = (@cq.canvas.width * 0.7) | 0
      @cq.canvas.oncontextmenu = () -> false
      @cq.appendTo("#viewport")

      @renderer = new Renderer(@world, @cq, this)

      @unitinfo = new UnitInfoHandler(@world, $("#unitinfo"))

      @clickbehavior = new ClickBehavior.Default(@world, @keys)

      setupDebug(this)

    onstep: (delta, time) ->
      @world.stepAll()
      if not _.any(@world.entities, (ent) => ent.vision is @world.playerVision)
        overlay("You died!")

    stepRate: 20

    onrender: (delta, time) ->
      @renderer.render( delta, @keys, @mouseX, @mouseY )

    # window resize
    onresize: (width, height) ->
      # resize canvas with window
      # change camera transform
      if @cq
        @cq.canvas.height = height
        @cq.canvas.width = (width * 0.7) | 0

    onmousedown: (x, y, button) ->
      pt = @renderer.cellPosition(x, y)
      if button == 2
        @clickbehavior.onrightclick(pt)
      else if button == 0
        @clickbehavior.onleftclick(pt)

    onmousemove: (x, y) ->
      @mouseX = x
      @mouseY = y

    onmousewheel: (delta) ->
      # CELL_PIXEL_SIZE *= Math.pow(1.05, delta)

    # keyboard events
    onkeydown: (key) ->
      @keys[key] = true

      makeHumanBuild = (human, type, pt) ->
        human.setCurrentTask(new Task.Construct(human, construct(type, [pt.x, pt.y, human.vision])))

      mousePt = @renderer.cellPosition(@mouseX, @mouseY)

      freeHuman = _.find(@world.selection.units, (unit) -> unit.currentTask == null)
      ((human) =>
        if not human
          {}
        else
          b: () => makeHumanBuild(human, Entity.House, mousePt)
          q: () => makeHumanBuild(human, Entity.Human, mousePt)
          h: () => human.setCurrentTask( new Task.GoHome(human) )
          z: () => human.die()
      )(freeHuman)[key]?()

    onkeyup: (key) ->
      delete @keys[key]
  }

  $(() ->
    framework.setup()
  )
