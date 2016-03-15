hubot-standup-alarm
===================

[![npm version](https://badge.fury.io/js/hubot-standup-alarm.svg)](http://badge.fury.io/js/hubot-standup-alarm)

Use Hubot to remind your team to do your standups.

## What does it do?

In a chat room, you can ask Hubot to create a standup at a specific time. From then on, at that time every weekday, Hubot will post in the chat room reminding you to have your standup.

You can create as many standups as you like, across as many rooms as you like.

## Usage

`hubot standup help` - See a help document explaining how to use.

`hubot create standup hh:mm` - Creates a standup at hh:mm (UTC) every weekday for this room

`hubot create standup hh:mm at location/url` - Creates a standup at hh:mm (UTC) every weekday for this chat room with a reminder for a physical location or url

`hubot create standup hh:mm UTC+2` - As above, with a shift to account for UTC offset

`hubot list standups` - See all standups for this room

`hubot list standups in every room` - See all standups in every room

`hubot delete hh:mm standup` - If you have a standup at hh:mm, deletes it

`hubot delete all standups` - Deletes all standups for this room.

## Environment Variables

You can set ```HUBOT_STANDUP_PREPEND``` to define a string that will be prepended to the alert messages Hubot sends. Typically, you'd use this to trigger an alert to everybody, for example, *@here* will alert everybody active in a Hipchat room, and *@all* does the same for Flowdock.

## Local Time

Currently, the time you specify must be the same timezone as the server Hubot resides on. You can check this with `hubot time`. However, you can specify a UTC offset to compensate for any differences between Hubot's time and your local time.

## Installation via NPM

Run the following command to install this module as a Hubot dependency

```
npm install hubot-standup-alarm --save
```

Confirm that hubot-standup-alarm appears as a dependency in your Hubot package.json file.

```
"dependencies": {
  "hubot":              "2.x",
  "hubot-scripts":      "2.x",
  "hubot-standup-alarm": "*"
}
```

To enable the script, add the hubot-standup-alarm entry to the external-scripts.json file (you may need to create this file).

```
  ["hubot-standup-alarm"]
```

## Contributing

Feel free! Send a pull request :)
