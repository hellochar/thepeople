define [
], () ->
  class Minimap
    constructor: (@world, @vision = @world.playerVision, @renderer) ->
      @cq = cq(@world.width, @world.height)

      @tileCq = cq(@cq.canvas.width, @cq.canvas.height)
      @tileCq.clear("black")

      @vision.on("visionupdate", (newlyVisibleTiles, newlyRememberedTiles) =>
        @drawTile(tile, @tileCq) for tile in newlyVisibleTiles
        @drawTile(tile, @tileCq, true) for tile in newlyRememberedTiles
      )

      $(@world).on("poststep", @render)

    drawTile: (tile, cq, darkened = false) =>
      for sprite in tile.getSpriteTemplates()
        cq.drawImage(sprite.spritesheet,
          sprite.sx * sprite.tileSize,
          sprite.sy * sprite.tileSize,
          sprite.width * sprite.tileSize,
          sprite.height * sprite.tileSize,
          (tile.x + sprite.dx),
          (tile.y + sprite.dy),
          sprite.width,
          sprite.height
        )
        if darkened
          cq.fillStyle("rgba(0, 0, 0, 0.5)").fillRect(
            (tile.x + sprite.dx),
            (tile.y + sprite.dy),
            sprite.width,
            sprite.height
          )

    drawEntity: (entity, color, scale = 1, cq, darkened = false) =>
      for sprite in entity.getSpriteTemplates()
        cq.fillStyle(color).fillRect(
          (entity.x + sprite.dx),
          (entity.y + sprite.dy),
          sprite.width * scale,
          sprite.height * scale
        )
        if darkened
          cq.fillStyle("rgba(0, 0, 0, 0.5)").fillRect(
            (entity.x + sprite.dx),
            (entity.y + sprite.dy),
            sprite.width * scale,
            sprite.height * scale
          )

    render: () =>
      @cq.clear("black")
      @cq.drawImage(@tileCq.canvas, 0, 0)
      for entity in @vision.getVisibleEntities()
        switch entity.vision
          when @vision then @drawEntity(entity, "lightgreen", 2, @cq)
          else @drawEntity(entity, "grey", 1, @cq)
      @cq.strokeStyle("white").strokeRect(@renderer.camera.x, @renderer.camera.y, @renderer.cq.canvas.width / @renderer.CELL_PIXEL_SIZE, @renderer.cq.canvas.height / @renderer.CELL_PIXEL_SIZE)
