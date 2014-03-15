define [
  'underscore'
  'backbone'
], (_, Backbone) ->
  class Selection
    constructor: (@units, @vision, @world) ->
      @units ||= []
      $(@world).on("poststep", () =>
        @remove(unit) for unit in @units when not @canSelect(unit)
      )
      _.extend(this, Backbone.Events)

    canSelect: (unit) => _.contains(@vision.getVisibleEntities(), unit) and not unit.isDead()

    add: (unit) ->
      throw "bad" unless @canSelect(unit)
      if not @has(unit)
        @units.push(unit)
        @trigger("add", unit)

    remove: (unit) ->
      @units = _.without(@units, unit)
      @trigger("remove", unit)

    clear: () =>
      @remove(unit) for unit in @units

    has: (unit) -> unit in @units


  Selection
