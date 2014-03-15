define [
  'game/unitinfo'
], (UnitInfoHandler) ->
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

      @unitinfo = new UnitInfoHandler(@world, this)
      $("#sidebar").append(@unitinfo.$el)

    lookAt: (cellPt) =>
      currentCellPosition = @cellPosition(@cq.canvas.width/2, @cq.canvas.height/2, false)
      cellOffset =
        x: cellPt.x - currentCellPosition.x
        y: cellPt.y - currentCellPosition.y
      @camera.x += cellOffset.x
      @camera.y += cellOffset.y
      @constrainCameraPosition()


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

      # cq.fillStyle("red").globalAlpha(0.5)
      # for x in [Math.max(0, topLeftCorner.x)...Math.min(@world.map.width, bottomRightCorner.x)]
      #   for y in [Math.max(0, topLeftCorner.y)...Math.min(@world.map.height, bottomRightCorner.y)]
      #     tile = @world.map.getCell(x, y).tileInstance
      #     if tile.visionInfo isnt 0
      #       @drawOccupied(x, y)


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
      @cq.fillStyle("black").fillText(line, left + LINE_MARGIN, bottom - idx * (FONT_SIZE + LINE_MARGIN) - LINE_MARGIN / 2, lineWidth) for line, idx in lines

    constrainCameraPosition: () =>
      # calculate the top-left corner if the camera was at the very bottom-right
      xmax = @world.width - @cq.canvas.width / @CELL_PIXEL_SIZE
      ymax = @world.height - @cq.canvas.height / @CELL_PIXEL_SIZE

      constrain = (val, min, max) -> Math.min(Math.max(val, min), max)
      @camera.x = constrain(@camera.x, 0, xmax)
      @camera.y = constrain(@camera.y, 0, ymax)

    render: (delta, keys, mouseX, mouseY) =>
      cq = @cq
      $(@world).trigger("prerender")

      mapping = {
        a: () => @camera.x -= 1 * delta / 32
        left: () => @camera.x -= 1 * delta / 32

        d: () => @camera.x += 1 * delta / 32
        right: () => @camera.x += 1 * delta / 32

        w: () => @camera.y -= 1 * delta / 32
        up: () => @camera.y -= 1 * delta / 32

        s: () => @camera.y += 1 * delta / 32
        down: () => @camera.y += 1 * delta / 32
      }

      for key, fn of mapping
        fn() if keys[key]

      @constrainCameraPosition()

      cq.clear("black")
      cq.save()
      cq.translate(-@camera.x * @CELL_PIXEL_SIZE, -@camera.y * @CELL_PIXEL_SIZE)
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
        rect = unit.getHitbox()
        cellCenter = rect.center()
        cellRadius = Math.max(rect.width, rect.height) / 2

        cq.strokeStyle("red").lineWidth(3).beginPath().arc(cellCenter.x * @CELL_PIXEL_SIZE, cellCenter.y * @CELL_PIXEL_SIZE, cellRadius * @CELL_PIXEL_SIZE * 1.2, 0, Math.PI * 2).stroke()
      cq.restore()

      #draw tooltip for currently moused over cell
      mousePt = @cellPosition(mouseX, mouseY, false)
      @drawTextBox(_.union(["#{cellPt.x}, #{cellPt.y}"], @framework.clickbehavior.tooltip(cellPt, @world.map.getCell(cellPt.x, cellPt.y).tileInstance, @world.entityAt(cellPt.x, cellPt.y))), mousePt.x * @CELL_PIXEL_SIZE, mousePt.y * @CELL_PIXEL_SIZE)
      cq.restore()

      $(@world).trigger("postrender")

    # Convert a point on the canvas to its corresponding cell coordinate
    cellPosition: (canvasX, canvasY, truncate = true) =>
      x = canvasX / @CELL_PIXEL_SIZE + @camera.x
      y = canvasY / @CELL_PIXEL_SIZE + @camera.y
      x: if truncate then x | 0 else x
      y: if truncate then y | 0 else y

    # Find where the given cell is located in canvas pixels
    # account for translating
    renderPosition: (cellX, cellY) =>
      pixelX = (cellX - @camera.x | 0) * @CELL_PIXEL_SIZE
      pixelY = (cellY - @camera.y | 0) * @CELL_PIXEL_SIZE
      x: pixelX
      y: pixelY


  Renderer
