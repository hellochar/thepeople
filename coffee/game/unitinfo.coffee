define [
  'jquery'
  'underscore'
], ($, _) ->

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
    seconds = temp % 60
    return seconds + " second" + numberEnding(seconds)  if seconds
    "less then a second" #'just now' //or other string you like;

  class SingleUnitInfo
    constructor: (@unit) ->

    render: () =>


  class UnitInfoHandler
    constructor: (@world, @$el) ->
      $(@world).on("poststep", () =>
        @render()
      )


    renderUnit: (unit) =>
      _.template(
        """
        <div class="individual unitinfo">
          <h2> <%= name %> <span style="font-size: 0.5em"> alive for <%= ageString %> </span> </h2>
          <div>
            <p style="background-color: <%= hungerColor %>"> Hunger: <%= hunger | 0 %> </p>
            <p style="background-color: <%= tiredColor %>"> Tired: <%= tired | 0 %> </p>

            <h3> Current Task: <span class="text-muted"> <%= currentTaskString %> </span> </h3>

            <h3> Thoughts </h3>
            <% _.each(thoughts, function(thought) { %>
              <li> <%= thought.thought %> </li>
            <% }); %>
          </div>
        </div>
        """
      , {
          # 20 frames per second -> 1000 / 20 milliseconds per frame
          ageString: millisecondsToStr(unit.age() * (1000 / 20))
          name: unit.constructor.name
          hunger: unit.hunger
          hungerColor: switch
            when unit.hunger < 300 then "green"
            when unit.hunger < 600 then "yellow"
            when unit.hunger < 800 then "orange"
            else "red"
          tired: unit.tired
          tiredColor: switch
            when unit.tired < 300 then "green"
            when unit.tired < 600 then "yellow"
            when unit.tired < 800 then "orange"
            else "red"
          currentTaskString: unit.currentTask?.toString() || "Nothing"
          thoughts: unit.getRecentThoughts()
        }
      )


    render: () =>
      @$el.empty()
      if not _.isEmpty(@world.selection.units)
        @$el.append(@renderUnit(unit)) for unit in @world.selection.units
      else
        @$el.text("Left-click a unit to select it!")


  UnitInfoHandler
