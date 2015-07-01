{Robot, Adapter, TextMessage, User} = require 'hubot'
request = require 'request'
http = require 'http'
fs = require 'fs'
os = require 'os'
crypto = require 'crypto'
readChunk = require 'read-chunk'
imageType = require 'image-type'

class Telegram extends Adapter

  constructor: ->
    super
    @robot.logger.info "Telegram Adapter loaded"

    @token = process.env['TELEGRAM_TOKEN']
    @webHook = process.env['TELEGRAM_WEBHOOK']
    @api_url = "https://api.telegram.org/bot#{@token}"
    @offset = 0

    # Get the Bot Id and name...not used by now
    request "#{@api_url}/getMe", (err, res, body) =>
      if res.statusCode == 200
        botData = JSON.parse(body)
        @id = botData.result.id
        @name = botData.result.username

  send: (envelope, strings...) ->

    data =
      url: "#{@api_url}/sendMessage"
      form:
        chat_id: envelope.room
        text: strings.join()

    request.post data, (err, res, body) =>
      @robot.logger.debug res.statusCode

  sendImage: (envelope, url, strings...) ->

    self = @

    # Setting chat Action with sending image
    data =
      url: "#{@api_url}/sendChatAction"
      form:
        chat_id: envelope.room
        action: 'upload_photo'

    request.post data, (err, res, body) =>
      @robot.logger.info res.statusCode

    # Sending the image
    filename = crypto.randomBytes(4).readUInt32LE(0)
    filepath = os.tmpdir() + "/" + filename
    request(url).pipe(fs.createWriteStream(filepath)).on 'close', ->

      file = fs.createReadStream filepath
      type = imageType readChunk.sync(filepath, 0, 12)

      if !type
        self.robot.logger.debug "Cannot find image type"
        return

      formData =
        chat_id: envelope.room
        caption: strings.join() if strings
        photo:
          value: file
          options:
            filename: filename + "." + type.ext # without the correct image extension, sendPhoto will return 400
            contentType: type.mime

      request.post { url: "#{self.api_url}/sendPhoto", formData: formData }, (err, res, body) ->
        self.robot.logger.debug "upload failed: #{err}" if err
        fs.unlink filepath
        self.robot.logger.debug res.statusCode

  reply: (envelope, strings...) ->

    data =
      url: "#{@api_url}/sendMessage"
      form:
        chat_id: envelope.room
        text: strings.join()

    request.post data, (err, res, body) =>
      @robot.logger.debug res.statusCode

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

    unless @token
      @emit 'error', new Error `'The environment variable \`\033[31mTELEGRAM_TOKEN\033[39m\` is required.'`

    if @webHook
      # Call `setWebHook` to dynamically set the URL
      data =
        url: "#{@api_url}/setWebHook"
        form:
          url: @webHook

      request.post data, (err, res, body) =>
        @robot.logger.info res.statusCode

      @robot.router.post "/telegram/receive", (req, res) =>
        console.log req.body
        for msg in req.body.result
          @robot.logger.info "WebHook"
          @receiveMsg msg
    else
      # Polling
      setInterval =>
        url = "#{self.api_url}/getUpdates?offset=#{@getLastOffset()}"
        self.robot.http(url).get() (err, res, body) =>
          self.emit 'error', new Error err if err
          updates = JSON.parse body
          for msg in updates.result
            @receiveMsg msg
      , 2000

    @emit "connected"

exports.use = (robot) ->
  new Telegram robot
