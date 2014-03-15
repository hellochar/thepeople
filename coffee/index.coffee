require [
  'jquery',
  'underscore'
  'backbone'
  'stats'
  'canvasquery'
  'canvasquery.framework'
  'construct'
  'assets'
  'rectangle'
  'game/action'
  'search'
  'game/map'
  'game/click_behavior'
  'game/entity'
  'game/entityqueue'
  'game/drawable'
  'game/minimap'
  'game/selection'
  'game/renderer'
  'game/task'
  'game/tile'
  'game/vision'
  'game/world'
], ($, _, Backbone, Stats, cq, eveline, construct, Assets, Rectangle, Action, Search, Map, ClickBehavior, Entity, EntityQueue, Drawable, Minimap, Selection, Renderer, Task, Tile, Vision, World) ->

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

  setupWorld = () ->
    world = new World(100, 100)

    createOasis = (x, y) ->
      # put some nice grass around the area
      radius = 8

      for dx in [- radius .. radius]
        for dy in [ - radius .. radius] when Math.sqrt(dx * dx + dy * dy) <= radius
          dist = Math.sqrt(dx * dx + dy * dy)
          probability = Math.sqrt(1 - Math.sqrt(dist / radius))
          world.map.setTile(x + dx, y + dy, Tile.Grass) if Math.random() < probability

      # Put some food near the center
      for z in [0...Math.random() * 5 | 0 + 3]
        food = new Entity.Food(x + (Math.random() - 0.5) * radius / 3 | 0, y + (Math.random() - 0.5) * radius / 3 | 0)
        world.addEntity(food)

      # put a few trees; about one per 12 squares
      for z in [0...radius * radius * Math.PI / 12]
        # Only put trees in the middle half of the circle ( the Math.random() - .5 goes from -1/2 to 1/2 )
        tree = new Entity.Tree(x + (Math.random() - 0.5) * radius | 0, y + (Math.random() - 0.5) * radius | 0)
        world.addEntity(tree)

    createWall = (x, y) ->
      radius = Math.random() * 10 + 15 | 0
      startAngle = Math.random() * Math.PI * 2
      endAngle = startAngle + (.25 + Math.random()) * Math.PI

      # circumference is 2pi*r, each angle changes by 
      circumference = 2 * Math.PI * radius
      for angle in [startAngle..endAngle] by Math.PI / 2 / circumference
        dx = Math.cos(angle) * radius | 0
        dy = Math.sin(angle) * radius | 0
        world.map.setTile(x + dx, y + dy, Tile.Wall)
        world.map.setTile(x + dx + 1, y + dy, Tile.Wall)

    # put half-circle walls everywhere
    for i in [0...10]
      x = world.width / 3 + (1/3) * Math.random() * world.width | 0
      y = world.height / 3 + (1/3) * Math.random() * world.height | 0
      createWall(x, y)
    # Create 5 oases
    for i in [0...50]
      x = Math.random() * world.width | 0
      y = Math.random() * world.height | 0
      createOasis(x, y)

    house = world.addEntity(new Entity.House(world.width/2, world.height/2, world.playerVision))
    starter = world.addEntity(new Entity.Human(house.x, house.y + 1, world.playerVision))
    world.selection.add(starter)

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
      @renderer.lookAt(@world.selection.units[0])

      @minimap = new Minimap(@world, @world.playerVision, @renderer)
      @minimap.cq.appendTo(".minimap-container")

      @clickbehavior = new ClickBehavior.Default(@world, @keys)

      setupDebug(this)

    onstep: (delta, time) ->
      if @world.playerVision.isSurviving()
        @world.stepAll(Math.min(delta / 1000, 1)) # Step for a maximum of 1 second
        if not @world.playerVision.isSurviving()
          overlay("You died! You survived for #{@world.age | 0} seconds. Your performance is: ")

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
      tile = @world.map.getCell(pt.x, pt.y).tileInstance
      entity = @world.entityAt(pt.x, pt.y)
      if button == 2
        @clickbehavior.onrightclick(pt, tile, entity)
      else if button == 0
        @clickbehavior.onleftclick(pt, tile, entity)

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
          z: () => $(@world).one("prestep", () -> human.die())
      )(freeHuman)[key]?()

    onkeyup: (key) ->
      delete @keys[key]
  }

  Assets.whenLoaded(() ->
    $(() ->
      framework.setup()
    )
  )
