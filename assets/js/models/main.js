// REST shortcuts
var Rest = {
    rooms: $.Rest("http://localhost:4000/api/rooms"),
    users: $.Rest("http://localhost:4000/api/users"),
    roles: $.Rest("http://localhost:4000/api/roles"),
    sockets: $.Rest("http://localhost:4000/api/sockets"),
    requests: $.Rest("http://localhost:4000/api/requests"),
    sessions: $.Rest("http://localhost:4000/api/sessions"),
    messages: $.Rest("http://localhost:4000/api/messages"),
    subscriptions: $.Rest("http://localhost:4000/api/subscriptions"),
};

// Router
(function () {
    var Router = {};
    var routes = [];

    var history = window.history;

    function checkUrl() {
        var hash = location.hash.replace(/^#/, "");
        if (hash !== Router.hash) {
            Router.hash = hash;
            processHash(hash);
        }
    }

    function processHash(hash) {
        for (var i = 0; i < routes.length; i++) {
            var match = routes[i].route.test(hash);
            if (match) {
                return routes[i].callback(hash);
            }
        }
    }

    $window.on("popstate hashchange", checkUrl);

    Router.on = function (route, callback) {
        routes.push({ route: route, callback: callback });
    };

    Router.push = function (hash, title) {
        history.pushState({}, title || "", "#" + hash);
        checkUrl();
    };

    Router.replace = function (hash, title) {
        history.replaceState({}, title || document.title, "#" + hash);
    };

    $(function () {
        var redirect = sessionStorage.getItem("redirect");
        if (redirect) {
            sessionStorage.removeItem("redirect");
            if (redirect !== location.hash.replace(/^#/, "")) {
                Router.replace(redirect);
            }
        }
        checkUrl();
    });

    window.Router = Router;
})();

Router.on(/^$/, function (hash) {
    Rooms.leave();
});

Router.on(/^\+$/, function () {
    Rooms.enter();
    Rooms.explore();
});

Router.on(/^[\w\-+]{3,}$/, function (hash) {
    Rooms.enter();
    Rooms.select(hash);
});

// Redirect after login
$(".login-links").on("click", "a", function () {
    if (Router.hash) {
        sessionStorage.setItem("redirect", Router.hash);
    }
});

// My session
var Me = new Events();

// Get my session
(function () {
    function update(data) {
        Me.session_id = data.session_id;
        Me.nickname = data.nickname;
        Me.status = data.status;
        Me.rand_nickname = Boolean(data.rand_nickname);
        Me.authorized = Boolean(data.user_id);
        Me.provider_id = data.provider_id;
        Me.ignores = data.ignores;
        Me.subscriptions = data.subscriptions;
        Me.checkVersion(data.talkrooms);
        updateRooms(data);
    }

    function updateRooms(data) {
        Me.rooms = data.rooms || [];
        Me.recent_rooms = data.recent_rooms || [];
    }

    Me.fetch = function () {
        return (this.ready = Rest.sessions.get("me").done(update));
    };
})();

// Ignores
Me.isHidden = function (data) {
    return Boolean(
        data.user_id
            ? Me.ignores[0][data.user_id]
            : Me.ignores[1][data.session_id],
    );
};

// Talkrooms vesrion
(function () {
    var notice;
    var version = 39;

    function showNotice(description) {
        notice = $('<div class="updated-notice"></div>')
            .append(
                '<div class="updated-title">Вышло обновление Talkrooms. Пожалуйста, <span class="updated-reload">обновите страницу</span>, чтобы сбросить кэш браузера.</div>',
            )
            .append('<div class="updated-text">' + description + "</div>");
        notice.find(".updated-reload").on("click", function () {
            location.reload(true);
        });
        notice
            .appendTo("body")
            .css("top", -notice.outerHeight() - 20)
            .animate({ top: 0 }, 300);
    }

    Me.checkVersion = function (data) {
        if (data && data.version > version && !notice)
            showNotice(data.whatsnew);
    };
})();

// Import Phoenix socket for real-time functionality
import PhoenixSocket from "../user_socket.js";

// Get session and prepare app
(function () {
    var errors = {
        406: "Пожалуйста, включите куки в&nbsp;вашем браузере",
        402: "Слишком много одновременных соединений",
        500: "Ведутся технические работы",
    };

    function prepare(saveSelected) {
        Me.fetch()
            .then(function () {
                Rooms.reset(Me.subscriptions, saveSelected);
            })
            .catch(showError);
    }

    function showError(xhr) {
        $('<div class="fatal-error"></div>')
            .html((xhr.status && errors[xhr.status]) || errors[500])
            .appendTo("body");
    }

    // when the page loads
    prepare(true);
})();

// Phoenix socket event handlers will be set up in user_socket.js

// Make core objects globally available for legacy code
window.Rest = Rest;
window.Router = Router;
window.Me = Me;
// window.Socket = Socket; // Removed old socket system
window.PhoenixSocket = PhoenixSocket; // New Phoenix socket
