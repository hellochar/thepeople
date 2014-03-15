###
#
# A global class to handle assets
#
# Usage: in framework:
#
# require([..., "assets", ...], (..., Assets, ...) ->
#   Assets.whenLoaded(() ->
#     framework.setup()
#   )
# )
#
# In Drawable:
#
# (Assets) ->
#   Assets.get("/images/spritesheets/tiles1.png")
#
###
define [
  'underscore'
], (_) ->
  urls = [
    "/images/spritesheets/tiles1.png"
    "/images/spritesheets/tiles3.png"
    "/images/spritesheets/characters.png"
  ]

  callbacks = []

  cache = {}

  isLoaded = () ->
    _.size(cache) is urls.length

  _.each(urls, (url) ->
    img = new Image()
    img.src = url
    img.addEventListener("load", () ->
      cache[url] = img
      if isLoaded()
        callback() for callback in callbacks
        callbacks = undefined
    )
  )

  Assets = {
    whenLoaded: (fn) ->
      if callbacks
        callbacks.push(fn)
      else
        fn()

    get: (url) ->
      cache[url] || throw "#{url} isn't in Assets!"
  }

  Assets
