define [
], () ->
  class Rectangle
    constructor: (@x, @y, @width, @height) ->
      @right = @x + @width
      @bottom = @y + @height

    @bounded: (left, top, right, bottom) ->
      new Rectangle(left, top, right - left, bottom - top)

    within: (x, y) ->
      return (x >= @x && x <= @right && y >= @y && y <= @bottom)

  Rectangle
