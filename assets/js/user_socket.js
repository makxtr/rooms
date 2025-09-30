// Bring in Phoenix channels client library:
import { Socket, Presence } from "phoenix";

let socket = new Socket("/sockets", { params: { token: "test_token" } });
socket.connect();

// Store current room channel and presence
let currentChannel = null;
let presenceState = {};

// Phoenix socket interface for the app
const PhoenixSocket = {
    socket,

    // Join a room channel
    joinRoom(roomId, userParams = {}) {
        // Leave current room if exists
        if (currentChannel) {
            currentChannel.leave();
        }

        // Reset presence state
        presenceState = {};

        // Join new room
        currentChannel = socket.channel(`room:${roomId}`, {
            nickname: userParams.nickname || window.Me?.nickname || "Гость",
            user_id: userParams.user_id || window.Me?.session_id || null,
            status: userParams.status || window.Me?.status || null,
        });

        function updatePresences() {
            const presences = Presence.list(presenceState, (id, { metas }) => {
                const user = {
                    id: id,
                    nickname: metas[0].nickname,
                    status: metas[0].status,
                    online_at: metas[0].online_at,
                };
                return user;
            });

            // Trigger custom event for the app
            if (window.Rooms && window.Rooms.selected) {
                window.Rooms.trigger("presence.sync", presences);
            }
        }

        // Handle initial presence state from server
        currentChannel.on("presence_state", (state) => {
            presenceState = Presence.syncState(presenceState, state);
            updatePresences();
        });

        // Handle presence diffs
        currentChannel.on("presence_diff", (diff) => {
            presenceState = Presence.syncDiff(presenceState, diff);
            updatePresences();
        });

        currentChannel
            .join()
            .receive("ok", (resp) => {
                // Room joined successfully
            })
            .receive("error", (resp) => {
                console.error("Failed to join room:", resp);
            });

        return currentChannel;
    },

    // Leave current room
    leaveRoom() {
        if (currentChannel) {
            currentChannel.leave();
            currentChannel = null;
            presenceState = {};
        }
    },

    // Get current channel
    getCurrentChannel() {
        return currentChannel;
    },

    updatePresence(updates) {
        if (currentChannel) {
            currentChannel.push("update_presence", updates);
        }
    },
};

export default PhoenixSocket;
