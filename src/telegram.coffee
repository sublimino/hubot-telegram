{Robot, Adapter, TextMessage, User} = require 'hubot'
Bot = require './api'

class Telegram extends Adapter

  constructor: ->
    super
    @robot.logger.info "Telegram Adapter loaded"

    unless process.env['TELEGRAM_TOKEN']
      @emit 'error', new Error `'The environment variable \`\033[31mTELEGRAM_TOKEN\033[39m\` is required.'`

    @api = new Bot(process.env['TELEGRAM_TOKEN'])
    @webHook = process.env['TELEGRAM_WEBHOOK']
    @offset = 0

  send: (envelope, strings...) ->
    @api.sendMessage envelope.room, strings, (err, res, body) =>
      @robot.logger.debug res.statusCode

  sendImage: (envelope, url, strings...) ->
    @api.sendPhoto envelope.room, url, strings, (err, res) =>
      self.robot.logger.debug "upload failed: #{err}" if err

  reply: (envelope, strings...) ->
    @api.sendMessage envelope.room, strings, (err, res, body) =>
      self.robot.logger.debug res.statusCode

  receiveMsg: (msg) ->

    user = @robot.brain.userForId msg.message.from.id, name: msg.message.from.username, room: msg.message.chat.id
    text = msg.message.text
    # If is a direct message to the bot, prepend the name
    text = @robot.name + ' ' + msg.message.text if msg.message.chat.id > 0
    message = new TextMessage user, text, msg.message_id
    # Only if it's a text message, not join or leaving events
    @receive message if text
    @offset = msg.update_id

  getLastOffset: ->
    # Increment the last offset
    parseInt(@offset) + 1

  run: ->
    self = @
    @robot.logger.info "Run"

    if @webHook
      @api.setWebhook @WebHook, (err, res, body) =>
        @robot.router.post "/telegram/receive", (req, res) =>
          for msg in req.body.result
            @robot.logger.info "WebHook"
            @receiveMsg msg
    else
      # Polling
      setInterval =>
        @api.getUpdates @getLastOffset(), (err, res, body) ->
          self.emit 'error', new Error err if err
          for msg in body.result
            self.receiveMsg msg
      , 2000

    @emit "connected"

exports.use = (robot) ->
  new Telegram robot
