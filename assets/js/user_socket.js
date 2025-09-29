// Bring in Phoenix channels client library:
import { Socket } from "phoenix";

let socket = new Socket("/sockets", { params: { token: "test_token" } });
socket.connect();

let channel = socket.channel("room:test", {});
channel
    .join()
    .receive("ok", (resp) => {
        console.log("Connected to room");
    })
    .receive("error", (resp) => {
        console.log("Connection failed");
    });

export default socket;
