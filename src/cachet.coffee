# Description
#   A hubot script to manage incidents/statuses with Cachet
#
# Configuration:
#   HUBOT_CACHET_API_URL
#   HUBOT_CACHET_API_TOKEN
#
# Commands:
#   hubot cachet status
#   hubot cachet component set <component name> <id>
#   hubot cachet component list
#   hubot cachet component flushall
#   hubot incident investigating on <component name>: <incident message>
#   hubot incident identified on <component name>: <incident message>
#   hubot incident watching on <component name>: <incident message>
#   hubot incident fixed on <component name>: <incident message>
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

IncidentStatus =
  Scheduled: 0,
  Investigating: 1,
  Identified: 2,
  Watching: 3,
  Fixed: 4

declare_incident = (component_name, incident_name, incident_msg, status, msg) ->
  component_id = _components[component_name] ? 0

  data = JSON.stringify {
    name: incident_name,
    message: incident_msg,
    status: status,
    component_id: component_id,
    notify: true
  }

  msg
    .http("#{url}/incidents")
    .header('X-Cachet-Token', token)
    .header('Content-Type', 'application/json')
    .post(data) (err, res, body) ->
      if err
        msg.send err
      else
        json     = JSON.parse body
        incident = json.data

        msg.send "Incident \##{incident.id} declared"

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

  robot.respond /cachet component set ([a-zA-Z0-9 ]+) ([0-9]+)/i, (msg) ->
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
    msg.reply "Roger! Components have been flushed"

  robot.respond /incident investigating on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "Investigating issue on #{component_name}"

    declare_incident component_name, incident_name, incident_msg, \
                     IncidentStatus.Investigating,msg

  robot.respond /incident identified on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "Issue on #{component_name} has been identified"

    declare_incident component_name, incident_name, incident_msg, \
                     IncidentStatus.Identified, msg

  robot.respond /incident watching on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "Watching #{component_name}"

    declare_incident component_name, incident_name, incident_msg, \
                     IncidentStatus.Watching, msg

  robot.respond /incident fixed on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "#{component_name} is back!"

    declare_incident component_name, incident_name, incident_msg, \
                     IncidentStatus.Fixed, msg
