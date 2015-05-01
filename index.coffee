# Description:
#   Have Hubot remind you to do standups.
#   hh:mm must be in the same timezone as the server Hubot is on. Probably UTC.
#
#   This is configured to work for Hipchat. You may need to change the 'create standup' command
#   to match the adapter you're using.
#
# Dependencies:
#   underscore
#   cron
#
# Configuration:
#   HUBOT_STANDUP_PREPEND
#
# Commands:
#   hubot standup help

Fs = require 'fs'
Path = require 'path'

module.exports = (robot) ->
  scriptsPath = Path.resolve __dirname, 'scripts'
  Fs.exists scriptsPath, (exists) ->
    if exists
      robot.loadFile scriptsPath, file for file in Fs.readdirSync(scriptsPath)
