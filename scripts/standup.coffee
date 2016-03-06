# Description:
#   Have Hubot remind you to do standups.
#   hh:mm must be in the same timezone as the server Hubot is on. Probably UTC.
#
#   This is configured to work for Hipchat. You may need to change the 'create standup' command
#   to match the adapter you're using.
#
# Configuration:
#  HUBOT_STANDUP_PREPEND
#
# Commands:
#   hubot standup help - See a help document explaining how to use.
#   hubot create standup hh:mm - Creates a standup at hh:mm every weekday for this room
#   hubot create standup Monday@hh:mm - Creates a standup at hh:mm every Monday for this room
#   hubot create standup hh:mm UTC+2 - Creates a standup at hh:mm every weekday for this room (relative to UTC)
#   hubot list standups - See all standups for this room
#   hubot list standups in every room - See all standups in every room
#   hubot delete Monday@hh:mm standup - If you have a standup on Monday at hh:mm, deletes it
#   hubot delete all standups - Deletes all standups for this room.
#
# Dependencies:
#   underscore
#   cron

###jslint node: true###

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
    currentWeekday = undefined
    if utc
      currentHours = now.getUTCHours() + parseInt(utc, 10)
      currentMinutes = now.getUTCMinutes()
      currentMinutes = now.getUTCDay()
      if currentHours > 23
        currentHours -= 23
    else
      currentHours = now.getHours()
      currentMinutes = now.getMinutes()
      currentWeekday = now.getDay()
    standupHours = standupTime.split(':')[0]
    standupMinutes = standupTime.split(':')[1]
    standupDay = standupTime.split("@")[0]
    try
      standupHours = parseInt(standupHours, 10)
      standupMinutes = parseInt(standupMinutes, 10)
      standupDay = getDayOfWeek(standupDay)
    catch _error
      return false
    if standupHours == currentHours and standupMinutes == currentMinutes and standupDay and standupDay == currentWeekday
      return true
    false

  # Returns the number of a day of the week from a supplied string. Will only attempt to match the first 3 characters

  getDayOfWeek = (day) ->
    days = ['sun', 'mon', 'tue', 'Wed', 'thu', 'fri', 'sat']
    return days.indexOf(day.toLowercase().substring(0,3))

  # Returns all standups.

  getStandups = ->
    robot.brain.get('standups') or []

  # Returns just standups for a given room.

  getStandupsForRoom = (room) ->
    _.where getStandups(), room: room

  # Gets all standups, fires ones that should be.

  checkStandups = ->
    standups = getStandups()
    _.chain(standups).filter(standupShouldFire).pluck('room').each doStandup
    return

  # Fires the standup message.

  doStandup = (room) ->
    standups = getStandupsForRoom(room)
    if standups.length > 0
      #do some magic here to loop through the standups and find the one for right now
      theStandup = standups.filter(standupShouldFire)
      message = "#{PREPEND_MESSAGE} #{_.sample(STANDUP_MESSAGES)} #{theStandup[0].location}"
    else
      message = "#{PREPEND_MESSAGE} #{_.sample(STANDUP_MESSAGES)} #{standups[0].location}"
    robot.messageRoom room, message
    return

  # Finds the room for most adaptors
  findRoom = (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  # Stores a standup in the brain.

  saveStandup = (room, time, location, utc) ->
    standups = getStandups()
    newStandup =
      time: time
      room: room
      utc: utc
      location: location
      day: day
    standups.push newStandup
    updateBrain standups
    return

  # Updates the brain's standup knowledge.

  updateBrain = (standups) ->
    robot.brain.set 'standups', standups
    return

  clearAllStandupsForRoom = (room) ->
    standups = getStandups()
    standupsToKeep = _.reject(standups, room: room)
    updateBrain standupsToKeep
    standups.length - (standupsToKeep.length)

  clearSpecificStandupForRoom = (room, time) ->
    standups = getStandups()
    standupsToKeep = _.reject(standups,
      room: room
      time: time)
    updateBrain standupsToKeep
    standups.length - (standupsToKeep.length)

  'use strict'
  # Constants.
  STANDUP_MESSAGES = [
    'Standup time!'
    'Time for standup, y\'all.'
    'It\'s standup time once again!'
    'Get up, stand up (it\'s time for our standup)'
    'Standup time. Get up, humans'
    'Standup time! Now! Go go go!'
  ]
  PREPEND_MESSAGE = process.env.HUBOT_STANDUP_PREPEND or ''
  if PREPEND_MESSAGE.length > 0 and PREPEND_MESSAGE.slice(-1) != ' '
    PREPEND_MESSAGE += ' '

  # Check for standups that need to be fired, once a minute
  # Monday to Friday.
  new cronJob('1 * * * * 1-5', checkStandups, null, true)

  robot.respond /delete all standups for (.+)$/i, (msg) ->
    room = msg.match[1]
    standupsCleared = clearAllStandupsForRoom(room)
    msg.send 'Deleted ' + standupsCleared + ' standups for ' + room

  robot.respond /delete all standups$/i, (msg) ->
    standupsCleared = clearAllStandupsForRoom(findRoom(msg))
    msg.send 'Deleted ' + standupsCleared + ' standup' + (if standupsCleared == 1 then '' else 's') + '. No more standups for you.'
    return
  robot.respond /delete ([0-5]?[0-9]:[0-5]?[0-9]) standup/i, (msg) ->
    time = msg.match[1]
    standupsCleared = clearSpecificStandupForRoom(findRoom(msg), time)
    if standupsCleared == 0
      msg.send 'Nice try. You don\'t even have a standup at ' + time
    else
      msg.send 'Deleted your ' + time + ' standup.'
    return

  robot.respond /create standup (?:([A-z]*)\s?\@\s?)?((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])(?: UTC\+(\d\d?))?(?: in)?(.*$)/i, (msg) ->
    day = msg.match[1]
    time = msg.match[2]
    utcOffset = msg.match[3]
    location = msg.match[4]
    room = findRoom(msg)
    saveStandup room, day, time, utcOffset, location
    /** TODO Continue from here. **/
    msg.send 'Ok, from now on I\'ll remind this room to do a standup every weekday at ' + time
    return

  robot.respond /(?:list|show) standups$/i, (msg) ->
    standups = getStandupsForRoom(findRoom(msg))
    if standups.length == 0
      msg.send 'Well this is awkward. You haven\'t got any standups set :-/'
    else
      standupsText = [ 'Here\'s your standups:' ].concat(_.map(standups, (standup) ->
        if standup.utc
          standup.time + ' UTC' + standup.utc
        else
          standup.time
      ))
      msg.send standupsText.join('\n')
    return
  robot.respond /(?:list|show) standups (?:for|in) every room/i, (msg) ->
    standups = getStandups()
    if standups.length == 0
      msg.send 'No, because there aren\'t any.'
    else
      standupsText = [ 'Here\'s the standups for every room:' ].concat(_.map(standups, (standup) ->
        'Room: ' + standup.room + ', Time: ' + standup.time
      ))
      msg.send standupsText.join('\n')
    return
  robot.respond /standup help/i, (msg) ->
    message = []
    message.push 'I can remind you to do your daily standup!'
    message.push 'Use me to create a standup, and then I\'ll post in this room every weekday at the time you specify. Here\'s how:'
    message.push ''
    message.push robot.name + ' create standup hh:mm - I\'ll remind you to standup in this room at hh:mm every weekday.'
    message.push robot.name + ' create standup hh:mm UTC+2 - I\'ll remind you to standup in this room at hh:mm every weekday.'
    message.push robot.name + ' list standups - See all standups for this room.'
    message.push robot.name + ' list standups in every room - Be nosey and see when other rooms have their standup.'
    message.push robot.name + ' delete hh:mm standup - If you have a standup at hh:mm, I\'ll delete it.'
    message.push robot.name + ' delete all standups - Deletes all standups for this room.'
    msg.send message.join('\n')
    return
  return
