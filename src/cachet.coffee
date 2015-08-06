# Description
#   A hubot script to manage incidents/statuses with Cachet
#
# Configuration:
#   HUBOT_CACHET_API_URL
#   HUBOT_CACHET_API_TOKEN
#
# Commands:
#   hubot cachet status
#   hubot cachet component set <name> <id>
#   hubot cachet component list
#   hubot cachet component flushall
#   hubot investigating issue on <component name>: <incident name>
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   William Durand

URL   = require "url"
url   = URL.format(URL.parse(process.env.HUBOT_CACHET_API_URL ? ""))
token = process.env.HUBOT_CACHET_API_TOKEN ? ""

_components = {}

module.exports = (robot) ->

  robot.brain.on 'loaded', ->
    if robot.brain.data.cachet_components?
      _components = robot.brain.data.cachet_components

  robot.respond /cachet status/i, (msg) ->
    results = []
    msg
      .http("#{url}/components")
      .headers('X-Cachet-Token': token)
      .get() (err, res, body) ->
        if err
          msg.send err
        else
          try
            json = JSON.parse body
            for component in json.data
              results.push [
                "#{component.name}: #{component.status_name}",
                "(last updated at: #{component.updated_at})"
              ].join ' '

            if results?.length < 1
              msg.send 'No component found'
            else
              msg.send results.join '\n'
          catch e
            msg.send "Error: #{e}"

  robot.respond /cachet component set ([a-zA-Z0-9]+) ([0-9]+)/i, (msg) ->
    name = msg.match[1]
    id   = parseInt(msg.match[2], 10)

    _components[name] = id
    robot.brain.data.cachet_components = _components
    msg.send "The component '#{name}' with id equals to #{id} has been set"

  robot.respond /cachet component list/i, (msg) ->
    # TODO: contains items?
    if _components?
      results = []
      for name of _components
        results.push "#{name} with id = #{_components[name]}"
      msg.send results.join '\n'
    else
      msg.send 'No component found'

  robot.respond /cachet component flushall/i, (msg) ->
    _components = {}
    robot.brain.data.cachet_components = _components
    msg.send "Roger! Components have been flushed"

  robot.respond /investigating issue on ([a-zA-Z0-9]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_name  = msg.match[2]

    msg.send [
      "Argh! Incident on component \#",
      _components[component_name],
      " with name = #{incident_name}"
    ].join '\n'
