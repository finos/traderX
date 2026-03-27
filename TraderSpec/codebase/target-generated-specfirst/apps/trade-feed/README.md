# FINOS | TraderX Sample Trading App | Trade Feed

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

## About

This is a simple pub-sub server, meant to be swapped out by your preferred message bus. This simple example allows for simple subscription/unsubscription activities and events to be dispatched into recipient groups, known in [socket.IO](https://socket.io) as 'rooms'. This particular solution was chosen for this demo because it can be expressed simply in a single line of code and natively supports the UI via websockets as well as the 'server side' components of this demo application.

This is not intended to be secure or extremely-high-performance in this simple implementation, but it does the job.

Publish command sends in a JSON object with {topic:'string', payload: object // or message:string} Subscribe/Unsubscribe comes with a string topic.

NOTE: This also broadcasts to the '*' topic to allow a global inspector ui to see all traffic. (subscribers of that and the messages' topic will only get one copy)

## Developing Locally

Spin up a local environment to see your changes live (optional, but encouraged)

```shell
cd trade-feed (this directory)
# Default port is 18086 (Controlled with the `TRADE_FEED_PORT` environment variable)
npm ci
npm run start
```

Now you can edit the site, commit and merge as normal. If you performed the optional live environment step, you'll see a live-reloading copy of the site open in your browser at <http://localhost:18086/> (or whaterver port you are using)
