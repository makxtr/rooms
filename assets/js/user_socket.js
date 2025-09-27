// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

let socket = new Socket("/sockets", {params: {token: "test_token"}})
socket.connect()

let channel = socket.channel("room:test", {})
channel.join()
  .receive("ok", resp => { console.log("Connected to room") })
  .receive("error", resp => { console.log("Connection failed") })

export default socket
