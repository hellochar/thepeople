define [
  'jquery'
  'underscore'
], ($, _) ->

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
          <h2> <%= constructor.name %> <span style="font-size: 0.5em"> <%= age() %> </span> </h2>
          <div>
            <p> Hunger: <%= hunger | 0 %> </p>
            <p> Tired: <%= tired | 0 %> </p>

            <h3> Current Action: <span class="text-muted"> <%= (currentTask && currentTask.toString()) || "Nothing" %> </span> </h3>

            <h3> Thoughts </h3>
            <% _.each(thoughts, function(thought) { %>
              <li> <%= thought.thought %> </li>
            <% }); %>
          </div>
        </div>
        """
      , unit
      )


    render: () =>
      @$el.empty()
      if not _.isEmpty(@world.selection.units)
        @$el.append(@renderUnit(unit)) for unit in @world.selection.units
      else
        @$el.text("Left-click a unit to select it!")


  UnitInfoHandler
