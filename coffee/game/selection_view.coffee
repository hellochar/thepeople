define [
  'jquery'
  'underscore'
  'canvasquery'
], ($, _, cq) ->

  secondsToStr = (secondsInput) ->
    milliseconds = secondsInput * 1000
    
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

  renderThought = (entity, thought) =>
    color = switch
      when thought.affect < -50 then "red"
      when thought.affect < 0 then "orange"
      when thought.affect is 0 then "black"
      when thought.affect > 0 then "green"
      else "black"

    ageString = secondsToStr((entity.age() - thought.age))

    el = $("<li>")
      .addClass("thought")
      .css( color: color )
      .text("#{ageString} ago - #{ thought.thought } (#{thought.affect})")

    el

  # Views are dynamically constructed; first argument of the constructor
  # must be the Entity which you're looking at
  class EntityView
    constructor: (@entity) ->
      @$el = @constructHTML()

    constructHTML: () =>
      $("""
        <div class="#{@entity.constructor.name} view">
          <h2 class="name"> #{@entity.constructor.name} </h2>
        </div>
        """
      )

    # Call this to update @$el to accurately reflect the current Entity's state
    render: () =>

  class BasicPropertiesView extends EntityView
    constructor: (@entity) -> super(@entity)

    # Subclasses should override properties with an array of strings
    properties: []

    constructHTML: () =>
      $html = super()
      $html.append("""
      <div class="properties">
      </div>
      """
      )
      $html

    render: () =>
      $props = $(_.template(""" <% _.each(properties, function(name) { %>
          <li> <%= name %> - <%= entity[name] | 0%> </li>
        <% }) %>""",
        entity: @entity
        properties: @properties
      ).trim())
      @$el.find(".properties").empty().append($props)

  class TreeView extends BasicPropertiesView
    properties: ["health"]

  class FoodView extends BasicPropertiesView
    properties: ["amount"]

  class BluePrintView extends BasicPropertiesView
    properties: ["turnsLeft"]

    render: () =>
      $html = super()
      $html.find(".name").append("<span> of #{@entity.entity.constructor.name}</span>")
      $html

  class HumanView extends EntityView
    constructor: (@human) ->
      super(@human)
      @$el = @constructHTML()

    constructHTML: () =>
      $("""
        <div class="human view">
          <h2 class="name"> <span>#{@human.name}</span>  <span class="alive-for"></span> </h2>
          <div class="actions">
            <p>q - Build human</p>
            <p>b - Build house</p>
            <p>z - Remove from game</p>
          </div>
          <div>
            <p> Hunger: <span class="hunger indicator-bar"><span></span></span> </p>
            <p> Tired: <span class="tired indicator-bar"><span></span></span> </p>
            <p> Happiness: <span class="affect indicator-bar"><span></span></span> </p>
            <p> Safety: <span class="safety"></span> </p>

            <h3> Current Task: <span class="text-muted current-task"> </span> </h3>

            <h3> Thoughts </h3>
            <div class="thoughts"></div>
          </div>
        </div>
        """
      )

    render: () =>
      @$el.find(".alive-for").text("alive for " + secondsToStr(@human.age()))
      @$el.find(".safety").text(@human.getSafetyLevel())
      @$el.find(".current-task").text(@human.currentTask?.toString() || "Nothing")
      # TODO only update the part of the DOM you need to change
      hungerColor = switch
        when @human.hunger < 300 then "lightgreen"
        when @human.hunger < 600 then "yellow"
        when @human.hunger < 800 then "orange"
        else "red"
      @$el.find(".hunger.indicator-bar span").css(
        width: @human.hunger / 1000 * 100 + "%"
        "background-color": hungerColor
      )

      tiredColor = switch
        when @human.tired < 300 then "lightgreen"
        when @human.tired < 600 then "yellow"
        when @human.tired < 800 then "orange"
        else "red"
      @$el.find(".tired.indicator-bar span").css(
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
      @$el.find(".affect.indicator-bar span").css(
        width: (@human.affect + 5000) / 10000 * 100 + "%"
        "background-color": happinessColor
      )

      @$el.find(".thoughts").empty()
      for thought in @human.getRecentThoughts()
        @$el.find(".thoughts").append(renderThought(@human, thought))


  class HouseView extends EntityView
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
        ageString: secondsToStr(@house.age())
      ))
      $html

  class SelectionView
    constructor: (@world, @renderer) ->
      @views = []
      @$el = $("<div>")
      @addView(entity) for entity in @world.selection.units

      @world.selection.on("add", @addView)
      @world.selection.on("remove", @removeView)

    viewConstructorFor: (entity) =>
      {
        Human: HumanView
        House: HouseView
        Tree: TreeView
        Food: FoodView
        BluePrint: BluePrintView
      }[entity.constructor.name] || EntityView


    addView: (entity) =>
      if @viewConstructorFor(entity)
        view = new (@viewConstructorFor(entity))(entity)
        @views.push(view)
        @$el.append(view.$el)

    removeView: (entity) =>
      view = _.findWhere(@views, {entity: entity})
      @views = _.without(@views, view)
      view.$el.remove()

    render: () =>
      if not _.isEmpty(@views)
        view.render() for view in @views
      else
        @$el.text("Left-click an entity to select it!")


  SelectionView
