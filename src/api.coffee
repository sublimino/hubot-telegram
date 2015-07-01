request = require 'request'
fs = require 'fs'
os = require 'os'
crypto = require 'crypto'
readChunk = require 'read-chunk'
imageType = require 'image-type'

class Api

  constructor: (api_token) ->
    @token = api_token
    @api_url = "https://api.telegram.org/bot#{@token}"

  getMe: ->
    request "#{@api_url}/getMe", (err, res, body) ->
      new Promise (resolve, reject) ->
        if res.statusCode == 200
          data = JSON.parse(body)
          resolve { id: data.result.id, name: data.result.username }
        else
          reject

  sendMessage: (room, messages, callback) ->
    data =
      url: "#{@api_url}/sendMessage"
      form:
        chat_id: room
        text: messages.join()

    request.post data, callback

  forwardMessage: ->

  sendPhoto: (room, url, messages, callback) ->

    self = @
    @sendChatAction 'upload_photo'

    # Sending the image
    filename = crypto.randomBytes(4).readUInt32LE(0)
    filepath = os.tmpdir() + "/" + filename
    request(url).pipe(fs.createWriteStream(filepath)).on 'close', ->

      file = fs.createReadStream filepath
      type = imageType readChunk.sync(filepath, 0, 12)
      return if !type

      formData =
        chat_id: room
        caption: messages.join() if messages
        photo:
          value: file
          options:
            filename: filename + "." + type.ext # without the correct image extension, sendPhoto will return 400
            contentType: type.mime

      request.post { url: "#{self.api_url}/sendPhoto", formData: formData }, (err, res, body) =>
        fs.unlink filepath
        callback(err, res)

  sendAudio: ->

  sendDocument: ->

  sendSticker: ->

  sendVideo: ->

  sendLocation: ->

  sendChatAction: (room, type, callback) ->

    data =
      url: "#{@api_url}/sendChatAction"
      form:
        chat_id: room
        action: type

    request.post data, callback

  getUserProfilePhotos: ->

  getUpdates: (update_id, callback) ->
    data =
      url: "#{@api_url}/getUpdates?offset=#{update_id}"
      json: true
    request data, callback

  setWebhook: (url, callback) ->

    data =
      url: "#{@api_url}/setWebHook"
      form:
        url: @webHook

    request.post data, callback


module.exports = Api
