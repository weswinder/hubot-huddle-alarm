# Description:
#   Have Hubot remind you to do standups.
#   hh:mm must be in the same timezone as the server Hubot is on. Probably UTC.
#
# Configuration:
#  HUBOT_STANDUP_PREPEND - Optional string to prepend standup messages from Hubot with.
#  HUBOT_MORE_STANDUP_MESSAGES - Optional CSV string of additional messages to use for standup alerts.
#
# Commands:
#   hubot standup help - See a help document explaining how to use.
#   hubot create standup hh:mm - Creates a standup at hh:mm every weekday for this room
#   hubot create standup hh:mm => console.log('callback function') - Creates a standup at hh:mm every weekday for this room and executes a callback function at standup time
#   hubot create standup hh:mm UTC+2 - Creates a standup at hh:mm every weekday for this room (relative to UTC)
#   hubot create standup hh:mm UTC+2 => console.log('callback function') - Creates a standup at hh:mm UTC+2 every weekday for this room and executes a callback function at standup time
#   hubot list standups - See all standups for this room
#   hubot list standups in every room - See all standups in every room
#   hubot delete hh:mm standup - If you have a standup at hh:mm, deletes it
#   hubot delete all standups - Deletes all standups for this room.
#
# Dependencies:
#   underscore
#   cron

###jslint node: true###

'use strict'

cronJob = require('cron').CronJob
_ = require('underscore')

module.exports = (robot) ->

  # Compares current time to the time of the standup
  # to see if it should be fired.
  standupShouldFire = (standup) ->
    standupTime = standup.time
    utc = standup.utc
    now = new Date
    currentHours = undefined
    currentMinutes = undefined
    if utc
      currentHours = now.getUTCHours() + parseInt(utc, 10)
      currentMinutes = now.getUTCMinutes()
      if currentHours > 23
        currentHours -= 23
    else
      currentHours = now.getHours()
      currentMinutes = now.getMinutes()
    standupHours = standupTime.split(':')[0]
    standupMinutes = standupTime.split(':')[1]
    try
      standupHours = parseInt(standupHours, 10)
      standupMinutes = parseInt(standupMinutes, 10)
    catch _error
      return false
    if standupHours == currentHours and standupMinutes == currentMinutes
      return true
    false

  # Returns all standups.
  getStandups = ->
    robot.brain.get('standups') or []

  # Returns just standups for a given room.
  getStandupsForRoom = (room) ->
    _.where getStandups(), room: room

  # Gets all standups, fires ones that should be fired.
  checkStandups = ->
    for standup in getStandups()
      if standupShouldFire(standup)
        doStandup(standup.room, standup.callback)

    return

  # Sends the standup message.
  doStandup = (room, callback) ->
    message = PREPEND_MESSAGE + _.sample(STANDUP_MESSAGES)
    robot.messageRoom room, message

    # Execute callback if there is one.
    if callback
      try
        eval(callback) #todo is there a way to make this less awful?
      catch _error
        return false

    return

  # Finds the room for most adaptors
  findRoom = (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  # Stores a standup in the brain.
  saveStandup = (room, time, utc, callback) ->
    standups = getStandups()
    newStandup = 
      time: time
      room: room
      utc: utc
      callback: callback
    standups.push newStandup
    updateBrain standups
    return

  # Updates the brain's standup knowledge.
  updateBrain = (standups) ->
    robot.brain.set 'standups', standups
    return

  # Given a room ID, clears all standups for that room.
  clearAllStandupsForRoom = (room) ->
    standups = getStandups()
    standupsToKeep = _.reject(standups, room: room)
    updateBrain standupsToKeep
    standups.length - (standupsToKeep.length)

  # Given a room ID and a time, clears that standup.
  clearSpecificStandupForRoom = (room, time) ->
    standups = getStandups()
    standupsToKeep = _.reject(standups,
      room: room
      time: time)
    updateBrain standupsToKeep
    standups.length - (standupsToKeep.length)

  # Constants.
  STANDUP_MESSAGES = [
    'Standup time!'
    'Time for standup, y\'all.'
    'It\'s standup time once again!'
    'Get up, stand up (it\'s time for your standup).'
    'Standup time. Get up, humans.'
    'Standup time! Now! Go go go!'
  ]

  # Allow an environment variable to be set to add more
  # standup messages in addition to the standard ones.
  STANDUP_MESSAGES = STANDUP_MESSAGES.concat process.env.HUBOT_MORE_STANDUP_MESSAGES.split ',' if process.env.HUBOT_MORE_STANDUP_MESSAGES

  # Prepend message. Can be set with an environment variable
  # to alert room participants. For example, on Slack @here
  # will alert all online users of a channel.
  PREPEND_MESSAGE = process.env.HUBOT_STANDUP_PREPEND or ''
  if PREPEND_MESSAGE.length > 0 and PREPEND_MESSAGE.slice(-1) != ' '
    PREPEND_MESSAGE += ' '

  # Check for standups that need to be fired, once a minute
  # Monday to Friday.
  new cronJob('1 * * * * 1-5', checkStandups, null, true)

  # Expressions for Hubot to respond to.

  # hubot delete all standups for room
  robot.respond /delete all standups for (.+)$/i, (msg) ->
    room = msg.match[1]
    standupsCleared = clearAllStandupsForRoom(room)
    msg.send 'Deleted ' + standupsCleared + ' standups for ' + room
    return

  # hubot delete all standups
  robot.respond /delete all standups/i, (msg) ->
    standupsCleared = clearAllStandupsForRoom(findRoom(msg))
    msg.send 'Deleted ' + standupsCleared + ' standup' + (if standupsCleared == 1 then '' else 's') + '. No more standups for you.'
    return

  # hubot delete hh:mm standup
  robot.respond /delete ([0-5]?[0-9]:[0-5]?[0-9]) standup/i, (msg) ->
    time = msg.match[1]
    standupsCleared = clearSpecificStandupForRoom(findRoom(msg), time)
    if standupsCleared == 0
      msg.send 'Nice try. You don\'t even have a standup at ' + time + '.'
    else
      msg.send 'Deleted your ' + time + ' standup.'
    return

  # hubot create standup hh:mm
  robot.respond /create standup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])$/i, (msg) ->
    time = msg.match[1]
    room = findRoom(msg)
    saveStandup room, time
    msg.send 'Ok, from now on I\'ll remind this room to do a standup every weekday at ' + time
    return

  # hubot create standup hh:mm UTC+X
  robot.respond /create standup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9]) UTC([+-]([0-9]|1[0-3]))$/i, (msg) ->
    time = msg.match[1]
    utc = msg.match[2]
    room = findRoom(msg)
    saveStandup room, time, utc
    msg.send 'Ok, from now on I\'ll remind this room to do a standup every weekday at ' + time + ' UTC' + utc
    return

  # hubot create standup hh:mm => <callback function>
  robot.respond /create standup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9]) =>(.*)$/i, (msg) ->
    time = msg.match[1]
    callback = msg.match[2]
    room = findRoom(msg)
    saveStandup room, time, 0, callback
    message = []
    message.push 'Ok, from now on I\'ll remind this room to do a standup every weekday at ' + time + '.'
    message.push 'When I do, I\'ll fire this callback function: '
    message.push ''
    message.push 'function() {'
    message.push '  ' + callback
    message.push '}'
    message.push ''
    message.push 'Note: Callback functions are an advanced feature and should be treated with care.'
    msg.send message.join('\n')
    return

  # hubot create standup hh:mm UTC+X => <callback function>
  robot.respond /create standup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9]) UTC([+-]([0-9]|1[0-3])) =>(.*)$/i, (msg) ->
    console.log(msg.match.toString());
    time = msg.match[1]
    utc = msg.match[2]
    callback = msg.match[4]
    room = findRoom(msg)
    saveStandup room, time, utc, callback
    message = []
    message.push 'Ok, from now on I\'ll remind this room to do a standup every weekday at ' + time + '.'
    message.push 'When I do, I\'ll fire this callback function: '
    message.push ''
    message.push 'function() {'
    message.push '  ' + callback
    message.push '}'
    message.push ''
    message.push 'Note: Callback functions are an advanced feature and should be treated with care.'
    msg.send message.join('\n')
    return

  # hubot list standups
  robot.respond /list standups$/i, (msg) ->
    standups = getStandupsForRoom(findRoom(msg))
    if standups.length == 0
      msg.send 'Well this is awkward. You haven\'t got any standups set :-/'
    else
      message = ['Here\'s the standups for this room:']
      for standup in standups
        message.push standup.time + (if standup.utc then (' (UTC' + standup.utc) + ')' else '') + (if standup.callback then (' with callback: ' + standup.callback) else '')
      msg.send message.join('\n')
    return

  # hubot list standups in every room
  robot.respond /list standups in every room/i, (msg) ->
    standups = getStandups()
    if standups.length == 0
      msg.send 'No, because there aren\'t any.'
    else
      message = ['Here\'s the standups for every room:']
      for standup in standups
        message.push standup.time + (if standup.utc then (' (UTC' + standup.utc) + ')' else '') + ' in ' + standup.room + (if standup.callback then (' with callback: ' + standup.callback) else '')
      msg.send message.join('\n')
    return

  # hubot standup help
  robot.respond /standup help/i, (msg) ->
    message = []
    message.push 'I can remind you to do your daily standup!'
    message.push 'Use me to create a standup, and then I\'ll post in this room every weekday at the time you specify. Here\'s how:'
    message.push ''
    message.push robot.name + ' create standup hh:mm - I\'ll remind you to standup in this room at hh:mm every weekday.'
    message.push robot.name + ' create standup hh:mm => console.log(\'callback function\') - I\'ll remind you to standup in this room at hh:mm every weekday and execute the specified callback function.'
    message.push robot.name + ' create standup hh:mm UTC+2 - I\'ll remind you to standup in this room at hh:mm UTC+2 every weekday.'
    message.push robot.name + ' create standup hh:mm UTC+2 => console.log(\'callback function\') - I\'ll remind you to standup in this room at hh:mm UTC+2 every weekday and execute the specified callback function.'
    message.push robot.name + ' list standups - See all standups for this room.'
    message.push robot.name + ' list standups in every room - Be nosey and see when other rooms have their standup.'
    message.push robot.name + ' delete hh:mm standup - If you have a standup at hh:mm, I\'ll delete it.'
    message.push robot.name + ' delete all standups - Deletes all standups for this room.'
    msg.send message.join('\n')
    return
  return
