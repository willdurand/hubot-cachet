# Description
#   A hubot script to manage incidents/statuses with Cachet
#
# Configuration:
#   HUBOT_CACHET_API_URL
#   HUBOT_CACHET_API_TOKEN
#
#  Commands:
#   hubot cachet status <red|orange|blue|green> <component name> - Change the component status
#   hubot cachet maintenance at <scheduled_at> <name>: <message> - Schedule a maintenance (e.g. `cachet maintenance at 2015-08-15 10:00:00 Database upgrade: Message`)
#   hubot cachet component status - Print all components along with their statuses
#   hubot cachet component set <component name> <id> - Register a component into my brain
#   hubot cachet component list - List all registered components into my brain (i.e. Cachet could own more components)
#   hubot cachet component flushall - Remove all registered components from my brain
#   hubot incident investigating on <component name>: <incident message> - Declare an incident on a component (or anything else if it cannot be linked to an existing compoenent) when it experiences an issue
#   hubot incident identified on <component name>: <incident message> - Declare an incident when you find the (root) cause of the current issue
#   hubot incident watching on <component name>: <incident message> - Declare an incident when you monitor changes due to an outage for instance
#   hubot incident fixed on <component name>: <incident message> - Declare an incident when things are fixed
#   hubot incident <id> update name: <new name> - Update the name of an existing incident
#   hubot incident <id> update message: <new name> - Update the message (content) of an existing incident
#   hubot incident <id> enable - Make an existing incident visible in Cachet
#   hubot incident <id> disable - Hide an existing incident in Cachet
#
# Notes:
#   Components MUST be registered with `cachet component set` before you are
#   able to use them (e.g. `<component name>`).
#
# Author:
#   William Durand

URL    = require 'url'
moment = require 'moment'

url   = URL.format(URL.parse(process.env.HUBOT_CACHET_API_URL ? ''))
token = process.env.HUBOT_CACHET_API_TOKEN ? ''

_components = {}

module.exports = (robot) ->

  robot.brain.on 'loaded', ->
    if robot.brain.data.cachet_components?
      _components = robot.brain.data.cachet_components

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

  ###
  Perform an API request with default headers and error handling
  ###
  apiRequest = (msg, method, endpoint, data, success, notFound) ->
    failed = (res, msg) ->
      msg.reply [
        'The request to the API has failed',
        "(status code = #{res.statusCode})"
      ].join ' '

    msg
      .http([ url, endpoint ].join '')
      .header('X-Cachet-Token', token)
      .header('Content-Type', 'application/json')
      .request(method, data) (err, res, body) ->
        if err
          msg.reply "[ERROR] #{err}"
        else
          switch res.statusCode
            when 200, 201
              try
                success body
              catch e
                msg.reply "[ERROR] #{e}"
            when 404
              if notFound?
                notFound body
              else
                failed res, msg
            else
              failed res, msg

  ###
  Call the API to declare a new incident
  ###
  declareIncident = (component_name, incident_name, incident_msg, status, msg, scheduled_at) ->
    component_id  = _components[component_name] ? 0
    incident_name = component_name if component_id == 0 unless not component_name?

    data = {
      name: incident_name,
      message: incident_msg,
      status: status,
      component_id: component_id,
      notify: true
    }

    if scheduled_at?
      data.scheduled_at = scheduled_at

    data = JSON.stringify data

    apiRequest msg, 'POST', '/incidents', data, (body) ->
      json     = JSON.parse body
      incident = json.data

      msg.send [
        "Incident `\##{incident.id}` declared.",
        'You might want to change the component status now.'
      ].join ' '

  ###
  Call the API to update an existing incident
  ###
  updateIncident = (incident_id, data, msg) ->
    data = JSON.stringify data

    apiRequest msg, 'PUT', "/incidents/#{incident_id}", data, (body) ->
      json     = JSON.parse body
      incident = json.data

      msg.send "Incident `\##{incident.id}` updated.",
    , (body) ->
      msg.reply "Incident `\##{incident_id}` does not exist."

  ###
  Call the API to change a component's status
  ###
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

    apiRequest msg, 'PUT', "/components/#{component_id}", data, (body) ->
      json     = JSON.parse body
      component = json.data

      msg.send "#{component.name} status changed to: *#{component.status_name}*"

  ###
  Listeners
  ###

  robot.respond /cachet status (red|orange|blue|green) ([a-zA-Z0-9 ]+)/i, (msg) ->
    component_name = msg.match[2]
    status          = switch
      when msg.match[1] == 'red'    then ComponentStatus.MajorOutage
      when msg.match[1] == 'orange' then ComponentStatus.PartialOutage
      when msg.match[1] == 'blue'   then ComponentStatus.PerformanceIssue
      when msg.match[1] == 'green'  then ComponentStatus.Operational

    changeComponentStatus component_name, status, msg

  robot.respond /cachet component status/i, (msg) ->
    apiRequest msg, 'GET', '/components', {}, (body) ->
      json = JSON.parse body

      results = []
      for component in json.data
        updated_at = moment(new Date(component.updated_at))

        if updated_at.isValid()
          updated_at = updated_at.fromNow()
        else
          updated_at = component.updated_at

        results.push [
          "#{component.name}: #{component.status_name}",
          "(last updated: #{updated_at})"
        ].join ' '

      if results?.length < 1
        msg.send 'No component found'
      else
        msg.send results.join '\n'

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

  robot.respond /cachet maintenance at (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (.+): (.+)/i, (msg) ->
    scheduled_at  = msg.match[1]
    incident_name = msg.match[2]
    incident_msg  = msg.match[3]

    declareIncident null, incident_name, incident_msg, \
                     IncidentStatus.Scheduled, msg, scheduled_at

  robot.respond /incident #?([0-9]+) update name: (.+)/i, (msg) ->
    incident_id   = msg.match[1]
    incident_name = msg.match[2]

    updateIncident incident_id, { name: incident_name }, msg

  robot.respond /incident #?([0-9]+) update message: (.+)/i, (msg) ->
    incident_id  = msg.match[1]
    incident_msg = msg.match[2]

    updateIncident incident_id, { message: incident_msg }, msg

  robot.respond /incident #?([0-9]+) enable/i, (msg) ->
    incident_id = msg.match[1]

    updateIncident incident_id, { visible: 1 }, msg

  robot.respond /incident #?([0-9]+) disable/i, (msg) ->
    incident_id = msg.match[1]

    updateIncident incident_id, { visible: 0 }, msg
