define [
], () ->
  class EntityQueue
    constructor: () ->
      @queue = []

    enqueue: (entity, time) ->
      @queue.push({time: time, entity: entity})
      @queue = _.sortBy(@queue, "time")

    peek: () => @queue[0]

    dequeue: () ->
      entry = @queue.shift()
      entry

    removeEntity: (entity) ->
      @queue = _.reject(@queue, (entry) -> entry.entity is entity)

  EntityQueue
