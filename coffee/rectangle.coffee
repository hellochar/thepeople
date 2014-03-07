define [
], () ->
  class Rectangle
    constructor: (@x, @y, @width, @height) ->
      @right = @x + @width
      @bottom = @y + @height

    @bounded: (left, top, right, bottom) ->
      new Rectangle(left, top, right - left, bottom - top)

    within: (x, y) ->
      return (x >= @x && x < @right && y >= @y && y < @bottom)

    intersects: (rect) ->
      return !(r2.x > @x + @width ||
             r2.x + r2.width < @x ||
             r2.y > @height + @y ||
             r2.height + r2.y < @y)

    allPoints: (fn) =>
      _.flatten(
        for x in [@x...@right]
          for y in [@y...@bottom]
            {x: x, y: y}
      )

  Rectangle
