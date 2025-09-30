// Rooms collection
(function () {
    var Rooms = new Events();

    var subscriptions = [];

    // Compare function for sorting
    function byAlias(a, b) {
        if (a.alias > b.alias) return 1;
        if (a.alias < b.alias) return -1;
        return 0;
    }

    Rooms.byHash = {};
    Rooms.byId = {};

    function indexRoom(room) {
        Rooms.byHash[room.data.hash] = room;
        if (room.data.room_id) {
            Rooms.byId[room.data.room_id] = room;
        }

        // Add state change handler to trigger selected.ready when room becomes ready
        room.on("state.changed", function (state) {
            if (room === Rooms.selected) {
                if (state === "ready") {
                    Rooms.trigger("selected.ready", room);
                } else if (state) {
                    Rooms.trigger("selected.denied", room);
                }
            }
        });
    }

    function createRoom(data) {
        var room = new Rooms.Room(data);
        indexRoom(room);
        return room;
    }

    function subscribed(room) {
        indexRoom(room); // reindex room_id from response
        Rooms.trigger("subscribed", room);
        if (room === Rooms.selected) {
            Rooms.trigger("selected.ready", room);
        } else {
            room.checkUnread();
        }
        Rooms.trigger("updated");
    }

    function denied(room) {
        if (room === Rooms.selected) {
            Rooms.trigger("selected.denied", room);
        }
    }

    Rooms.explore = function () {
        this.selected = null;
        this.trigger("explore");
    };

    Rooms.leave = function () {
        this.active = false;
        this.selected = null;
        this.forEach(function (room) {
            room.leave();
        });
        this.trigger("leave");
    };

    Rooms.restore = function (room) {
        return Rest.rooms
            .update(room.data.hash, { deleted: false })
            .then(function () {
                room.enter().then(subscribed, denied);
            });
    };

    Rooms.enter = function () {
        if (!this.active) {
            this.active = true;
            this.forEach(function (room) {
                room.enter().then(subscribed, denied);
            });
        }
    };

    Rooms.select = function (hash) {
        var room = this.byHash[hash];

        // Если такой комнаты ещё нет, создаём её
        if (!room) {
            room = this.add({ hash: hash, topic: "#" + hash });
            room.enter()
                .then(function (roomData) {
                    // Room enter successful
                })
                .catch(function (error) {
                    // Room enter failed
                });
        } else if (!room.state || room.state === "error") {
            room.enter()
                .then(function (roomData) {
                    // Room re-enter successful
                })
                .catch(function (error) {
                    // Room re-enter failed
                });
        }

        if (room.unread) {
            room.unread = false;
            this.trigger("updated");
        }

        this.selected = room;
        this.trigger("select", room);

        if (room.state === "ready") {
            this.trigger("selected.ready", room);
        } else if (room.state) {
            this.trigger("selected.denied", room);
        }
    };

    Rooms.reset = function (data, saveSelected) {
        var existing = this.byHash;

        this.byHash = {};
        this.byId = {};

        // If room already exists, update and use it
        subscriptions = data.map(function (room_data) {
            var same = existing[room_data.hash];
            if (same) {
                same.update(room_data);
                same.checkUnread();
                indexRoom(same);
                return same;
            } else {
                return createRoom(room_data);
            }
        });

        // If selected room was removed
        if (this.selected && !this.byHash[this.selected.data.hash]) {
            if (saveSelected) {
                subscriptions.push(this.selected);
                indexRoom(this.selected);
            } else {
                this.explore();
            }
        }

        subscriptions.sort(byAlias);

        this.trigger("updated");

        if (this.active) {
            this.forEach(function (room) {
                room.enter()
                    .then(function (roomData) {
                        // Room successfully entered, subscribed is already called inside room.enter()
                    })
                    .catch(function (error) {
                        // Room enter failed during reset
                    });
            });
        }
    };

    Rooms.forEach = function (callback) {
        subscriptions.forEach(callback, this);
    };

    Rooms.updateTopic = function (room, topic) {
        room.update({ topic: topic });
        subscriptions.sort(byAlias);
        this.trigger("updated");
    };

    Rooms.updateHash = function (room, hash) {
        delete this.byHash[room.data.hash];
        this.byHash[hash] = room;
        room.data.hash = hash;
        this.trigger("updated");
    };

    Rooms.triggerSelected = function (event, room) {
        if (this.selected === room) {
            this.trigger(event, room);
        }
    };

    Rooms.add = function (data) {
        if (this.byHash[data.hash]) {
            return;
        }

        var room = createRoom(data);

        subscriptions.push(room);
        subscriptions.sort(byAlias);

        Rooms.trigger("updated");

        return room;
    };

    Rooms.remove = function (room_id) {
        var room = this.byId[room_id];

        if (!room || room.isDeleted) {
            return false;
        }

        room.leave();
        delete this.byHash[room.data.hash];
        delete this.byId[room.data.room_id];

        subscriptions = subscriptions.filter(function (s) {
            return s !== room;
        });

        if (room === this.selected) {
            Router.push("+");
        }

        this.trigger("updated");
    };

    // Handle Phoenix presence events
    Rooms.on("presence.sync", function (presences) {
        if (Rooms.selected) {
            // Update online users list with Phoenix presence data
            const onlineUsers = presences.map((user, index) => ({
                role_id: index + 1, // Временный role_id для совместимости
                user_id: user.id,
                nickname: user.nickname,
                status: user.status, // Добавляем статус из Phoenix Presence
                online: true,
                phoenix_presence: true,
                come_in: null, // Добавляем поле come_in для совместимости
                level: 0, // Добавляем level для совместимости
            }));

            // Trigger event for UI update
            Rooms.trigger("selected.presence.updated", onlineUsers);
        }
    });

    window.Rooms = Rooms;
})();

// Room model
(function () {
    var extend = Object.assign || $.extend;

    var emoji = /[\uD800-\uDBFF\uDC00-\uDFFF\u200D]+\s*/g;

    // Normalize topic for sorting
    function setAlias(room) {
        room.alias = room.data.topic.toLowerCase().replace(emoji, "");
    }

    function Room(data) {
        Events.mixin(this);
        this.data = data;
        this.rolesOnline = new Rooms.Roles();
        this.rolesWaiting = new Rooms.Roles();
        setAlias(this);
    }

    function subscribe(hash) {
        return Rest.rooms.create(hash, "enter", {});
    }

    function subscribed(data) {
        this.update(data.room);
        this.myRole = data.role;
        // Дополняем myRole данными из сессии
        if (window.Me) {
            this.myRole.nickname = window.Me.nickname || this.myRole.nickname;
            this.myRole.status = window.Me.status || this.myRole.status;
            this.myRole.session_id = window.Me.session_id;
        }
        this.subscription = data.subscription;
        this.soundOn = Boolean(
            localStorage.getItem("sound_in_" + this.data.room_id),
        );
        this.rolesOnline.reset(data.roles_online);
        // Добавляем myRole в список онлайн пользователей с обновленными данными из сессии
        this.rolesOnline.add(this.myRole);
        this.rolesWaiting.reset(data.roles_waiting || []);
        this.rolesWaiting.enabled = Boolean(data.roles_waiting);
        this.setState("ready");
        if (this.eventsBuffer && this.eventsBuffer.length) {
            for (var i = 0; i < this.eventsBuffer.length; i++) {
                var event = this.eventsBuffer[i];
                event[0].call(Rooms, this, event[1]);
            }
        }
        this.eventsBuffer = null;

        // Join Phoenix channel for real-time updates
        if (window.PhoenixSocket && this.data.hash) {
            window.PhoenixSocket.joinRoom(this.data.hash, {
                nickname: this.myRole?.nickname,
                user_id: this.myRole?.user_id || this.myRole?.session_id,
            });
        }

        return this;
    }

    function denied(xhr) {
        this.eventsBuffer = null;
        if (xhr.status === 404) {
            this.setState(this.isDeleted ? "deleted" : "lost");
        } else if (xhr.status === 403) {
            var data = xhr.responseJSON;
            this.myRole = data.role;
            if (data.room) {
                extend(this.data, data.room);
            }
            if (this.data.level === 80) {
                this.setState("closed");
            } else {
                this.setState("locked");
            }
        } else {
            this.setState("error");
        }
        throw this;
    }

    Room.prototype = {
        enter: function () {
            this.eventsBuffer = [];
            return subscribe(this.data.hash)
                .then(subscribed.bind(this))
                .catch(denied.bind(this));
        },

        leave: function () {
            if (this.subscription) {
                Rest.subscriptions.destroy(this.subscription.subscription_id);
                this.subscription = null;
            }

            // Leave Phoenix channel
            if (window.PhoenixSocket) {
                window.PhoenixSocket.leaveRoom();
            }

            this.setState(null);
        },

        setState: function (state) {
            this.state = state;
            this.trigger("state.changed", state);
        },

        update: function (data) {
            extend(this.data, data);
            if (data.topic) {
                setAlias(this);
            }
            this.trigger("updated", data);
        },

        checkUnread: function () {
            var seen = this.data.seen_message_id;
            var last = this.filterUnread
                ? this.data.role_last_message_id
                : this.data.room_last_message_id;
            if (seen && seen < last) {
                this.unread = true;
            }
        },

        isMy: function (data) {
            return data.role_id === this.myRole.role_id;
        },

        mentionsMe: function (mentions) {
            var me = this.myRole.role_id;
            for (var i = mentions.length; i--; ) {
                if (mentions[i] === me) return true;
            }
        },

        isForMe: function (message) {
            if (this.myRole.role_id === message.recipient_role_id) {
                return true;
            } else if (message.mentions) {
                return this.mentionsMe(message.mentions);
            }
        },

        isVisible: function (message) {
            var me = this.myRole;
            if (message.role_id === me.role_id) {
                return true;
            }
            if (!me.isModerator && Me.isHidden(message)) {
                return false;
            }
            if (message.ignore && !me.ignored) {
                return false;
            }
            if (this.forMeOnly) {
                return (
                    message.recipient_nickname ||
                    (message.mentions && this.mentionsMe(message.mentions))
                );
            }
            return true;
        },

        toggleSound: function () {
            this.soundOn = !this.soundOn;
            if (this.soundOn) {
                localStorage.setItem("sound_in_" + this.data.room_id, 1);
            } else {
                localStorage.removeItem("sound_in_" + this.data.room_id);
            }
        },
    };

    Rooms.Room = Room;
})();

// New room and shuffle
(function () {
    function selectRoom(data) {
        Router.push(data.hash);
    }

    function shuffleFailed(xhr) {
        Rooms.trigger("shuffle.failed");
        throw xhr;
    }

    Rooms.create = function () {
        return Rest.rooms.create().then(selectRoom);
    };

    Rooms.shuffle = function () {
        return Rest.rooms.create("search").then(selectRoom, shuffleFailed);
    };
})();

// Update room data
(function () {
    function updateRoom(room, data) {
        room.update(data);
    }
})();

// Update roles
(function () {
    function updated(room) {
        Rooms.triggerSelected("selected.roles.updated", room);
    }

    function updateRole(room, data) {
        room.rolesOnline.update(data);
        if (room.myRole.role_id === data.role_id) {
            $.extend(room.myRole, data);
        }
        updated(room);
    }
})();

// User events has no room_id,
// so we must match and update roles in all rooms
(function () {
    function updateUser(data) {
        data.userpicUrl = null;

        Rooms.forEach(function (room) {
            room.rolesOnline.updateUser(data);
            if (room.myRole && room.myRole.user_id === data.user_id) {
                $.extend(room.myRole, data);
            }
        });

        if (Rooms.selected && Rooms.selected.subscription) {
            Rooms.triggerSelected("selected.roles.updated", Rooms.selected);
        }
    }

    var me = Rooms.selected && Rooms.selected.myRole;
    if (me && me.user_id === data.user_id) {
        Rooms.trigger("my.userpic.updated");
    }
})();

// Check my rank and load necessary scripts
(function () {
    function checkRank(role) {
        var level = role.level || 0;
        role.isModerator = level >= 50;
        role.isAdmin = level >= 70;
    }

    function checkMyRank(room) {
        var me = room.myRole;
        checkRank(me);
        if (me.isModerator) {
            // moderate.js is now loaded during app initialization
        }
        if (me.isAdmin) {
            // admin.js and ranks.js are now loaded during app initialization
        }
    }

    Rooms.on("selected.ready", checkMyRank);
})();

// Inactive window detection
(function () {
    $window.on("blur", function () {
        Rooms.idle = true;
    });

    $window.on("focus", function () {
        Rooms.idle = false;
    });
})();

// Deprecated namespace
var Room = new Events();

// Emulate old enter event
Rooms.on("selected.ready", function (selected) {
    Room.data = selected.data;
    Room.myRole = selected.myRole;
    Room.moderator = selected.myRole.isModerator;
    Room.trigger("enter", selected);
});

// Make Rooms globally available for legacy code
window.Rooms = Rooms;
window.Room = Room;
