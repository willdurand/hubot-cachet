# Description
#   A hubot script to manage incidents/statuses with Cachet
#
# Configuration:
#   HUBOT_CACHET_API_URL
#   HUBOT_CACHET_API_TOKEN
#
# Commands:
#   hubot cachet status
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   William Durand

URL   = require "url"
url   = URL.format(URL.parse(process.env.HUBOT_CACHET_API_URL))
token = process.env.HUBOT_CACHET_API_TOKEN

module.exports = (robot) ->
  robot.respond /debug/i, (msg) ->
    msg.send "URL = #{url}\nToken = #{token}"

  robot.respond /cachet status/i, (msg) ->
    results = []
    msg
      .http("#{url}/components")
      .get() (err, res, body) ->
        if err
          msg.send err
        else
          try
            json = JSON.parse body
            for component in json.data
              results.push "#{component.name}: #{component.status_name} (last updated at: #{component.updated_at})"

            if results?.length < 1
              msg.send 'no component found'
            else
              msg.send results.join '\n'
          catch e
            msg.send "Error: #{e}"
