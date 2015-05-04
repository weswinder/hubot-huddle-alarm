// Description:
//   Have Hubot remind you to do standups.
//   hh:mm must be in the same timezone as the server Hubot is on. Probably UTC.
//
//   This is configured to work for Hipchat. You may need to change the 'create standup' command
//   to match the adapter you're using.

//
// Configuration:
//  HUBOT_STANDUP_PREPEND
//
// Commands:
//   hubot standup help - See a help document explaining how to use.
//   hubot create standup hh:mm - Creates a standup at hh:mm every weekday for this room
//   hubot create standup hh:mm UTC+2 - Creates a standup at hh:mm every weekday for this room (relative to UTC)
//   hubot list standups - See all standups for this room
//   hubot list standups in every room - See all standups in every room
//   hubot delete hh:mm standup - If you have a standup at hh:mm, deletes it
//   hubot delete all standups - Deletes all standups for this room.
//
// Dependencies:
//   underscore
//   cron

/*jslint node: true*/
var cronJob = require("cron").CronJob;
var _ = require("underscore");

module.exports = function(robot) {
    "use strict";

    // Constants.
    var STANDUP_MESSAGES = [
        "Standup time!",
        "Time for standup, y'all.",
        "It's standup time once again!",
        "Get up, stand up (it's time for our standup)",
        "Standup time. Get up, humans",
        "Standup time! Now! Go go go!"
    ];

    var PREPEND_MESSAGE = process.env.HUBOT_STANDUP_PREPEND || "";
    if (PREPEND_MESSAGE.length > 0 && PREPEND_MESSAGE.slice(-1) !== " ") {
        PREPEND_MESSAGE += " ";
    }

    // Check for standups that need to be fired, once a minute
    // Monday to Friday.
    (new cronJob("1 * * * * 1-5", checkStandups, null, true));

    // Compares current time to the time of the standup
    // to see if it should be fired.
    function standupShouldFire(standup) {
        var standupTime = standup.time,
            utc = standup.utc;

        var now = new Date();

        var currentHours, currentMinutes;

        if (utc) {
            currentHours = now.getUTCHours() + parseInt(utc, 10);
            currentMinutes = now.getUTCMinutes();
        }
        else {
            currentHours = now.getHours();
            currentMinutes = now.getMinutes();
        }

        var standupHours = standupTime.split(':')[0];
        var standupMinutes = standupTime.split(":")[1];

        try {
            standupHours = parseInt(standupHours, 10);
            standupMinutes = parseInt(standupMinutes, 10);
        }
        catch (_error) {
            return false;
        }

        if (standupHours === currentHours && standupMinutes === currentMinutes) {
            return true;
        }
        return false;
    }

    // Returns all standups.
    function getStandups() {
        return robot.brain.get("standups") || [];
    }

    // Returns just standups for a given room.
    function getStandupsForRoom(room) {
        return _.where(getStandups(), {room: room});
    }

    // Gets all standups, fires ones that should be.
    function checkStandups() {
        var standups = getStandups();

        _.chain(standups).filter(standupShouldFire).pluck("room").each(doStandup);
    }

    // Fires the standup message.
    function doStandup(room) {
        var message = PREPEND_MESSAGE + _.sample(STANDUP_MESSAGES);
        robot.messageRoom(room, message);
    }

    // Finds the room for most adaptors
    function findRoom(msg) {
        var room = msg.envelope.room;

        if(_.isUndefined(room)) {
            room = msg.envelope.user.reply_to;
        }

        return room;
    }

    // Stores a standup in the brain.
    function saveStandup(room, time, utc) {
        var standups = getStandups();

        var newStandup = {
            time: time,
            room: room,
            utc: utc
        };

        standups.push(newStandup);
        updateBrain(standups);
    }

    // Updates the brain's standup knowledge.
    function updateBrain(standups) {
        robot.brain.set("standups", standups);
    }

    function clearAllStandupsForRoom(room) {
        var standups = getStandups();

        var standupsToKeep = _.reject(standups, {room: room});

        updateBrain(standupsToKeep);
        return standups.length - standupsToKeep.length;
    }

    function clearSpecificStandupForRoom(room, time) {
        var standups = getStandups();
        var standupsToKeep = _.reject(standups, {room: room, time: time});

        updateBrain(standupsToKeep);

        return standups.length - standupsToKeep.length;
    }

    robot.respond(/delete all standups/i, function(msg) {
        var standupsCleared = clearAllStandupsForRoom(findRoom(msg));
        msg.send("Deleted " + standupsCleared + " standup" + (standupsCleared === 1 ? "" : "s") + ". No more standups for you.");
    });

    robot.respond(/delete ([0-5]?[0-9]:[0-5]?[0-9]) standup/i, function(msg) {
        var time = msg.match[1];
        var standupsCleared = clearSpecificStandupForRoom(findRoom(msg), time);
        if (standupsCleared === 0) {
            msg.send("Nice try. You don't even have a standup at " + time);
        }
        else {
            msg.send("Deleted your " + time + " standup.");
        }
    });

    robot.respond(/create standup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])$/i, function(msg) {
        var time = msg.match[1];

        var room = findRoom(msg);

        saveStandup(room, time);
        msg.send("Ok, from now on I'll remind this room to do a standup every weekday at " + time);
    });

    robot.respond(/create standup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9]) UTC([+-][0-9])$/i, function(msg) {
        var time = msg.match[1];
        var utc = msg.match[2];

        var room = findRoom(msg);

        saveStandup(room, time, utc);
        msg.send("Ok, from now on I'll remind this room to do a standup every weekday at " + time + " UTC" + utc);
    });

    robot.respond(/list standups$/i, function(msg) {
        var standups = getStandupsForRoom(findRoom(msg));

        if (standups.length === 0) {
            msg.send("Well this is awkward. You haven't got any standups set :-/");
        }
        else {
            var standupsText = ["Here's your standups:"].concat(_.map(standups, function (standup) {
                if (standup.utc) {
                    return standup.time + " UTC" + standup.utc;
                } else {
                    return standup.time;
                }
            }));

            msg.send(standupsText.join("\n"));
        }
    });

    robot.respond(/list standups in every room/i, function(msg) {
        var standups = getStandups();
        if (standups.length === 0) {
            msg.send("No, because there aren't any.");
        }
        else {
            var standupsText = ["Here's the standups for every room:"].concat(_.map(standups, function (standup) {
                return "Room: " + standup.room + ", Time: " + standup.time;
            }));

            msg.send(standupsText.join("\n"));
        }
    });

    robot.respond(/standup help/i, function(msg) {
        var message = [];
        message.push("I can remind you to do your daily standup!");
        message.push("Use me to create a standup, and then I'll post in this room every weekday at the time you specify. Here's how:");
        message.push("");
        message.push(robot.name + " create standup hh:mm - I'll remind you to standup in this room at hh:mm every weekday.");
        message.push(robot.name + " create standup hh:mm UTC+2 - I'll remind you to standup in this room at hh:mm every weekday.");
        message.push(robot.name + " list standups - See all standups for this room.");
        message.push(robot.name + " list standups in every room - Be nosey and see when other rooms have their standup.");
        message.push(robot.name + " delete hh:mm standup - If you have a standup at hh:mm, I'll delete it.");
        message.push(robot.name + " delete all standups - Deletes all standups for this room.");
        msg.send(message.join("\n"));
    });
};
