define [
  'jquery'
  'underscore'
  'canvasquery'
], ($, _, cq) ->

  millisecondsToStr = (milliseconds) ->
    
    # TIP: to find current time in milliseconds, use:
    # var  current_time_milliseconds = new Date().getTime();
    
    # This function does not deal with leap years, however,
    # it should not be an issue because the output is aproximated.
    numberEnding = (number) -> #todo: replace with a wiser code
      (if (number > 1) then "s" else "")
    temp = milliseconds / 1000
    years = Math.floor(temp / 31536000)
    return years + " year" + numberEnding(years)  if years
    days = Math.floor((temp %= 31536000) / 86400)
    return days + " day" + numberEnding(days)  if days
    hours = Math.floor((temp %= 86400) / 3600)
    return hours + " hour" + numberEnding(hours)  if hours
    minutes = Math.floor((temp %= 3600) / 60)
    return minutes + " minute" + numberEnding(minutes)  if minutes
    seconds = temp % 60 | 0
    return seconds + " second" + numberEnding(seconds)  if seconds
    "less then a second" #'just now' //or other string you like;

  renderThought = (unit, thought) =>
    color = switch
      when thought.affect < -50 then "red"
      when thought.affect < 0 then "orange"
      when thought.affect is 0 then "black"
      when thought.affect > 0 then "green"
      else "black"

    ageString = millisecondsToStr((unit.age() - thought.age) * 1000 / 20)

    el = $("<li>")
      .addClass("thought")
      .css( color: color )
      .text("#{ageString} ago - #{ thought.thought } (#{thought.affect})")

    el

  class EntityInfo
    constructor: (@unit) ->


  class HumanInfo extends EntityInfo
    constructor: (@human) ->
      super(@human)

    template: _.template(
        """
        <div class="human info">
          <h2> <%= name %> <span class="alive-for"> alive for <%= ageString %> </span> </h2>
          <div>
            <p> Hunger: <span class="hunger indicator-bar"><span></span></span> </p>
            <p> Tired: <span class="tired indicator-bar"><span></span></span> </p>
            <p> Happiness: <span class="affect indicator-bar"><span></span></span> </p>
            <p> Safety: <%= safety %> </p>

            <h3> Current Task: <span class="text-muted"> <%= currentTaskString %> </span> </h3>

            <h3> Thoughts </h3>
            <div class="thoughts"></div>
          </div>
        </div>
        """
    )

    render: () =>
      # TODO only update the part of the DOM you need to change
      $html = $(@template(
          # 20 frames per second -> 1000 / 20 milliseconds per frame
          ageString: millisecondsToStr(@human.age() * (1000 / 20))
          name: @human.name
          affect: @human.affect
          safety: @human.getSafetyLevel()
          currentTaskString: @human.currentTask?.toString() || "Nothing"
          thoughts: _.map(@human.getRecentThoughts(), (thought) =>
            thought: thought.thought
            ageString: millisecondsToStr((@human.age() - thought.age) * 1000 / 20)
            color: switch
              when thought.affect < -50 then "red"
              when thought.affect < 0 then "orange"
              when thought.affect is 0 then "black"
              when thought.affect > 0 then "green"
              else "black"
          )
      ))
      hungerColor = switch
        when @human.hunger < 300 then "lightgreen"
        when @human.hunger < 600 then "yellow"
        when @human.hunger < 800 then "orange"
        else "red"
      $html.find(".hunger.indicator-bar span").css(
        width: @human.hunger / 1000 * 100 + "%"
        "background-color": hungerColor
      )

      tiredColor = switch
        when @human.tired < 300 then "lightgreen"
        when @human.tired < 600 then "yellow"
        when @human.tired < 800 then "orange"
        else "red"
      $html.find(".tired.indicator-bar span").css(
        width: @human.tired / 1000 * 100 + "%"
        "background-color": tiredColor
      )

      happinessColor = switch
        when @human.affect < -4000 then "red"
        when @human.affect < -2000 then "orange"
        when @human.affect < 0 then "yellow"
        when @human.affect < 2000 then "lightgreen"
        when @human.affect < 4000 then "green"
        else "darkgreen"
      $html.find(".affect.indicator-bar span").css(
        width: (@human.affect + 5000) / 10000 * 100 + "%"
        "background-color": happinessColor
      )

      for thought in @human.getRecentThoughts()
        $html.find(".thoughts").append(renderThought(@human, thought))

      $html


  class HouseInfo extends EntityInfo
    constructor: (@house) ->
      super(@house)

    template: _.template(
      """
      <div>
        <h2> House <span style="font-size: 0.5em"> alive for <%= ageString %> </span> </h2>
        <p class="flavor"> A home, a place to sleep, a place to gather.</p>
        <p class="bed-status"></p>
      </div>
      """
    )

    render: () =>
      $html = $(@template(
        ageString: millisecondsToStr(@house.age() * (1000 / 20))
      ))
      $html

  class UnitInfoHandler
    constructor: (@world, @renderer) ->
      @views = []
      @$el = $("<div>")
      @world.selection.on("add", @addView)

      @addView(unit) for unit in @world.selection.units

      @world.selection.on("remove", (unit) =>
        @views = _.reject(@views, (view) -> view.unit is unit)
      )

    viewConstructorFor: (unit) =>
      {
        Human: HumanInfo
        House: HouseInfo
      }[unit.constructor.name]


    addView: (unit) =>
      if @viewConstructorFor(unit)
        view = new (@viewConstructorFor(unit))(unit)
        @views.push(view)

    render: () =>
      @$el.empty()
      if not _.isEmpty(@views)
        @$el.append(view.render()) for view in @views
      else
        @$el.text("Left-click a unit to select it!")


  UnitInfoHandler
