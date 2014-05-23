{Robot, Adapter, TextMessage} = require("hubot")

HTTP    = require "http"
QS      = require "querystring"

class Twilio extends Adapter
  constructor: (robot) ->
    @sid   = process.env.HUBOT_SMS_SID
    @token = process.env.HUBOT_SMS_TOKEN
    @from  = process.env.HUBOT_SMS_FROM
    @robot = robot
    super robot

  send: (envelope, strings...) ->
    message = strings.join "\n"

    @send_sms message, envelope.user.id, (err, body) ->
      if err or not body?
        console.log "Error sending reply SMS: #{err}"
      else
        console.log "Sending reply SMS: #{message} to #{envelope.user.id}"

  reply: (envelope, strings...) ->
    @send envelope, str for str in strings

  respond: (regex, callback) ->
    @hear regex, callback

  run: ->
    @robot.router.get "/hubot/sms", (request, response) =>
      payload = QS.parse(request.url)

      if payload.Body? and payload.From?
        console.log "Received SMS: #{payload.Body} from #{payload.From}"
        @receive_sms(payload.Body, payload.From)

      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()

    @emit "connected"

  receive_sms: (body, from) ->
    return if body.length is 0
    user = @robot.brain.userForId from, name: from, room: 'SMS'

    # TODO Assign self.robot.name here instead of Hubot
    if body.match(new RegExp("^#{@robot.name}\\b" , 'i')) is null
      console.log "I'm adding '#{@robot.name}' as a prefix."
      body = @robot.name + ' ' + body

    @receive new TextMessage user, body

  send_sms: (message, to, callback) ->
    auth = new Buffer(@sid + ':' + @token).toString("base64")
    data = QS.stringify From: @from, To: to, Body: message

    @robot.http("https://api.twilio.com/2010-04-01/Accounts/#{@sid}/SMS/Messages")
      .header("Authorization", "Basic #{auth}")
      .header("Content-Type", "application/x-www-form-urlencoded")
      .post(data) (err, res, body) ->
        if err
          callback err
        else if res.statusCode is 201
          json = JSON.parse(body)
          callback null, body
        else
          json = JSON.parse(body)
          callback body.message

exports.use = (robot) ->
  new Twilio robot

