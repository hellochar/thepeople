define [
], () ->
  class Minimap
    constructor: (@world, @vision = @world.playerVision) ->
      @cq = cq(@world.width, @world.height)

      @tileCq = cq(@cq.canvas.width, @cq.canvas.height)
      @tileCq.clear("black")
      @tileCq.appendTo("body")

      @vision.on("visionupdate", (newlyVisibleTiles, newlyRememberedTiles) =>
        console.log("drawing #{newlyVisibleTiles.length} tiles!") if newlyVisibleTiles.length
        @drawTile(tile, @tileCq) for tile in newlyVisibleTiles
        @drawTile(tile, @tileCq) for tile in newlyRememberedTiles
      )

      $(@world).on("poststep", @render)

    # darkenTile: (tile) =>


    drawTile: (tile, cq) =>
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

    render: () =>
      @cq.clear("black")
      @cq.drawImage(@tileCq.canvas, 0, 0)
