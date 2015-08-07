# Description
#   A hubot script to manage incidents/statuses with Cachet
#
# Configuration:
#   HUBOT_CACHET_API_URL
#   HUBOT_CACHET_API_TOKEN
#
#  Commands:
#   hubot cachet status <red|orange|blue|green> <component name> - Change the component status
#   hubot cachet component status - Print all components along with their statuses
#   hubot cachet component set <component name> <id> - Register a component into my brain
#   hubot cachet component list - List all registered components into my brain (i.e. Cachet could own more components)
#   hubot cachet component flushall - Remove all registered components from my brain
#   hubot incident investigating on <component name>: <incident message> - Declare an incident on a component (or anything else if it cannot be linked to an existing compoenent) when it experiences an issue
#   hubot incident identified on <component name>: <incident message> - Declare an incident when you find the (root) cause of the current issue
#   hubot incident watching on <component name>: <incident message> - Declare an incident when you monitor changes due to an outage for instance
#   hubot incident fixed on <component name>: <incident message> - Declare an incident when things are fixed
#
# Notes:
#   Components MUST be registered with `cachet component set` before being able
#   to use them (e.g. `<component name>`).
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

  # Constants & Functions

  IncidentStatus =
    Scheduled: 0,
    Investigating: 1,
    Identified: 2,
    Watching: 3,
    Fixed: 4

  ComponentStatus =
    Operational: 1,
    PerformanceIssue: 2,
    PartialOutage: 3,
    MajorOutage: 4

  declareIncident = (component_name, incident_name, incident_msg, status, msg) ->
    component_id  = _components[component_name] ? 0
    incident_name = component_name if component_id == 0

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
          msg.reply "[ERROR] #{err}"
        else
          try
            json     = JSON.parse body
            incident = json.data

            msg.send [
              "Incident `\##{incident.id}` declared.",
              'You might want to change the component status now.'
            ].join ' '
          catch e
            msg.reply "[ERROR] #{e}"

  changeComponentStatus = (component_name, status, msg) ->
    component_id = _components[component_name] ? 0

    if component_id == 0
      names = []
      for name of _components
        names.push name

      msg.reply [
        "Component '#{component_name}' is not registered. ",
        'Available components are: ',
        names.join(', '),
        '.'
      ].join ''
      return

    data = JSON.stringify { status: status }

    msg
      .http("#{url}/components/#{component_id}")
      .header('X-Cachet-Token', token)
      .header('Content-Type', 'application/json')
      .put(data) (err, res, body) ->
        if err
          msg.reply "[ERROR] #{err}"
        else
          try
            json     = JSON.parse body
            component = json.data

            msg.send "#{component.name} status changed to: *#{component.status_name}*"
          catch e
            msg.reply "[ERROR] #{e}"

  # Listeners

  robot.respond /cachet status (red|orange|blue|green) ([a-zA-Z0-9 ]+)/i, (msg) ->
    component_name = msg.match[2]
    status          = switch
      when msg.match[1] == 'red'    then ComponentStatus.MajorOutage
      when msg.match[1] == 'orange' then ComponentStatus.PartialOutage
      when msg.match[1] == 'blue'   then ComponentStatus.PerformanceIssue
      when msg.match[1] == 'green'  then ComponentStatus.Operational

    changeComponentStatus component_name, status, msg

  robot.respond /cachet component status/i, (msg) ->
    results = []
    msg
      .http("#{url}/components")
      .headers('X-Cachet-Token': token)
      .get() (err, res, body) ->
        if err
          msg.reply "[ERROR] #{err}"
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
            msg.reply "[ERROR] #{e}"

  robot.respond /cachet component set ([a-zA-Z0-9 ]+) ([0-9]+)/i, (msg) ->
    name = msg.match[1]
    id   = parseInt(msg.match[2], 10)

    _components[name] = id
    robot.brain.data.cachet_components = _components
    msg.send "The component '#{name}' (id = #{id}) has been set"

  robot.respond /cachet component list/i, (msg) ->
    results = []
    for name of _components
      results.push "#{name} with id = #{_components[name]}"

    if results?.length < 1
      msg.send 'No component found'
      return

    msg.send results.join '\n'

  robot.respond /cachet component flushall/i, (msg) ->
    _components = {}
    robot.brain.data.cachet_components = _components
    msg.reply "Roger! Components have been flushed"

  robot.respond /incident investigating on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "Investigating issue on #{component_name}"

    declareIncident component_name, incident_name, incident_msg, \
                     IncidentStatus.Investigating, msg

  robot.respond /incident identified on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "Issue on #{component_name} has been identified"

    declareIncident component_name, incident_name, incident_msg, \
                     IncidentStatus.Identified, msg

  robot.respond /incident watching on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "Watching #{component_name}"

    declareIncident component_name, incident_name, incident_msg, \
                     IncidentStatus.Watching, msg

  robot.respond /incident fixed on ([a-zA-Z0-9 ]+): (.+)/i, (msg) ->
    component_name = msg.match[1]
    incident_msg   = msg.match[2]
    incident_name  = "#{component_name} is back!"

    declareIncident component_name, incident_name, incident_msg, \
                     IncidentStatus.Fixed, msg
