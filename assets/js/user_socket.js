import { Socket, Presence } from "phoenix";

let socket = new Socket("/sockets", { params: { token: "test_token" } });
socket.connect();

let currentChannel = null;
let presenceState = {};

function getUserId(userParams = {}) {
    return userParams.user_id || window.Me?.session_id || null;
}

const PhoenixSocket = {
    socket,

    joinRoom(roomId, userParams = {}) {
        if (currentChannel) {
            currentChannel.leave();
        }

        presenceState = {};

        currentChannel = socket.channel(`room:${roomId}`, {
            nickname: userParams.nickname || window.Me?.nickname || "Гость",
            user_id: getUserId(userParams),
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

            if (window.Rooms && window.Rooms.selected) {
                window.Rooms.trigger("presence.sync", presences);
            }
        }

        currentChannel.on("presence_state", (state) => {
            presenceState = Presence.syncState(presenceState, state);
            updatePresences();
        });

        currentChannel.on("presence_diff", (diff) => {
            presenceState = Presence.syncDiff(presenceState, diff);
            updatePresences();
        });

        currentChannel.on("new_message", (message) => {
            if (window.Room) {
                const messageData = {
                    message_id: message.message_id,
                    body: message.body,
                    user_id: message.user_id,
                    nickname: message.nickname,
                    created: message.timestamp,
                    content: message.body,
                };
                window.Room.trigger("message.created", messageData);
            }
        });

        currentChannel.on("room_updated", (payload) => {
            if (!window.Rooms?.selected) return;

            const room = window.Rooms.selected;
            const fields = ["topic", "watched", "level", "searchable"];

            fields.forEach((field) => {
                if (payload[field] !== undefined) {
                    room.data[field] = payload[field];
                    window.Rooms.triggerSelected(
                        `selected.${field}.updated`,
                        room,
                    );
                }
            });
        });

        currentChannel
            .join()
            .receive("ok", (resp) => {
                console.log("Joined room:", resp.room_hash);
            })
            .receive("error", (resp) => {
                console.error("Failed to join room:", resp);
            });

        return currentChannel;
    },

    leaveRoom() {
        if (currentChannel) {
            currentChannel.leave();
            currentChannel = null;
            presenceState = {};
        }
    },

    getCurrentChannel() {
        return currentChannel;
    },

    updatePresence(updates, userParams = {}) {
        if (currentChannel) {
            currentChannel.push("update_presence", {
                ...updates,
                user_id: getUserId(userParams),
            });
        }
    },
};

export default PhoenixSocket;
