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
    constructor: (@units, @vision, @world) ->
      @units ||= []
      $(@world).on("poststep", () =>
        @remove(unit) for unit in @units when unit.isDead()
      )

    canSelect: (unit) => unit.vision is @vision

    add: (unit) ->
      throw "bad" unless @canSelect(unit)
      @units.push(unit) unless @has(unit)

    remove: (unit) ->
      @units = _.without(@units, unit)

    clear: () => @units = []

    has: (unit) -> unit in @units

  class World
    constructor: (@width, @height) ->
      # Age is the number of frames this World has been stepped for
      @age = 0
      @map = new Map(@)
      @playerVision = new Vision(this)
      @selection = new Selection([], @playerVision, this)

      @entities = []
      @addEntity(new Entity.House(10, 10))
      starter = @addEntity(new Entity.Human(10, 11, @playerVision))
      @selection.add(starter)

    addEntity: (entity) =>
      console.log("#{entity} cannot be put there!") unless @map.hasRoomFor(entity)
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

  setupWorld = () ->
    world = new World(16, 16)
    require(["game/tile"], (Tile) =>
      # Create 5 oases
      for x in [0...world.width]
        for y in [0...world.height]
          world.map.setTile(x, y, Tile.Grass) if Math.random() < .1
    )
    for i in [0...1]
      x = Math.random() * world.width | 0
      y = Math.random() * world.height | 0
      world.addEntity(new Entity.Tree(x, y))

    for x in [0...world.width]
      for y in [0...world.height] when Math.random() < .1 # when Math.sin((x + y) / 8) * Math.cos((x - y) / 9) > .9
        if world.map.isUnoccupied(x, y)
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
      # Top-left cell coordinates of the viewport
      @camera = {
        x: 0
        y: 0
      }
      @cq.context.imageSmoothingEnabled = false
      @cq.context.webkitImageSmoothingEnabled = false
      @cq.context.mozImageSmoothingEnabled = false

      @unitinfo = new UnitInfoHandler(@world, $("#unitinfo"), this)

    drawOccupied: (x, y) =>
      free = @world.map.isUnoccupied(x, y)
      if not free
        cq.fillRect(x * @CELL_PIXEL_SIZE, y * @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE)
        # cq.fillStyle("grey").globalAlpha(0.5).fillRect(x * @CELL_PIXEL_SIZE, y * @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE).globalAlpha(1)

    drawWorld: () =>
      cq = @cq
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

      cq.fillStyle("red").globalAlpha(0.5)
      for x in [Math.max(0, topLeftCorner.x)...Math.min(@world.map.width, bottomRightCorner.x)]
        for y in [Math.max(0, topLeftCorner.y)...Math.min(@world.map.height, bottomRightCorner.y)]
          tile = @world.map.getCell(x, y).tileInstance
          if tile.visionInfo isnt 0
            @drawOccupied(x, y)


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

      @unitinfo.render()

      cellPt = @cellPosition(mouseX, mouseY, true)

      # draw red/green overlay for whether you can walk there
      # entity = @world.entityAt(cellPt.x, cellPt.y)
      # if entity
      #   if @world.selection.canSelect(entity) then cq.fillStyle("green") else cq.fillStyle("yellow")
      cq.save().fillStyle("green").globalAlpha(0.5).fillRect(cellPt.x * @CELL_PIXEL_SIZE, cellPt.y * @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE, @CELL_PIXEL_SIZE).restore()


      # draw selection circles
      cq.save()
      for unit in @world.selection.units
        centerX = (unit.x + .5) * @CELL_PIXEL_SIZE
        centerY = (unit.y + .5) * @CELL_PIXEL_SIZE
        cq.strokeStyle("red").lineWidth(3).beginPath().arc(centerX, centerY, @CELL_PIXEL_SIZE * 1.2 / 2, 0, Math.PI * 2).stroke()
      cq.restore()

      #draw tooltip for currently moused over cell
      mousePt = @cellPosition(mouseX, mouseY, false)
      @drawTextBox(_.union(["#{cellPt.x}, #{cellPt.y}"], @framework.clickbehavior.tooltip(cellPt)), mousePt.x * @CELL_PIXEL_SIZE, mousePt.y * @CELL_PIXEL_SIZE)
      cq.restore()

      $(@world).trigger("postrender")

    cellPosition: (canvasX, canvasY, truncate = true) =>
      x = canvasX / @CELL_PIXEL_SIZE - @camera.x
      y = canvasY / @CELL_PIXEL_SIZE - @camera.y
      x: if truncate then x | 0 else x
      y: if truncate then y | 0 else y

    # Find where the given cell is located in canvas pixels
    # account for translating
    renderPosition: (cellX, cellY) =>
      pixelX = (cellX + @camera.x | 0) * @CELL_PIXEL_SIZE
      pixelY = (cellY + @camera.y | 0) * @CELL_PIXEL_SIZE
      x: pixelX
      y: pixelY

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

    # keyboard events
    onkeydown: (key) ->
      @keys[key] = true

      makeHumanBuild = (human, type, pt) ->
        human.setCurrentTask(new Task.Construct(human, construct(type, [pt.x, pt.y, human.vision])))

      mousePt = @renderer.cellPosition(@mouseX, @mouseY)

      freeHuman = @world.selection.units[0]
      ((human) =>
        if not human
          {}
        else
          b: () => makeHumanBuild(human, Entity.House, mousePt)
          q: () => makeHumanBuild(human, Entity.Human, mousePt)
          z: () => human.die()
      )(freeHuman)[key]?()

    onkeyup: (key) ->
      delete @keys[key]
  }

  $(() ->
    framework.setup()
  )
