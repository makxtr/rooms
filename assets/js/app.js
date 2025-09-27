// Talkrooms application JS

// Load jQuery first
const script = document.createElement('script');
script.src = '//code.jquery.com/jquery-3.2.1.min.js';
script.onload = function() {
    // jQuery is loaded, now initialize the app
    initializeApp();
};
document.head.appendChild(script);

function initializeApp() {
    // Import vendor libraries
    import("../vendor/fastclick.min.js").then(() => {
        // Import utilities and core modules
        import("./utility.js")
        .then(() => import("./events.js"))
        .then(() => import("./rest.js"))
        // Import models
        .then(() => import("./models/main.js"))
        .then(() => import("./models/rooms.js"))
        .then(() => import("./models/roles.js"))
        .then(() => import("./models/userpics.js"))
        // Import views
        .then(() => import("./views/datepicker.js"))
        .then(() => import("./views/about.js"))
        .then(() => import("./views/room.js"))
        .then(() => import("./views/side.js"))
        .then(() => import("./views/hall.js"))
        .then(() => import("./views/talk.js"))
        .then(() => import("./views/reply.js"))
        .then(() => import("./views/settings.js"))
        .then(() => import("./views/profile.js"))
        .then(() => import("./views/moderate.js"))
        .then(() => import("./views/admin.js"))
        .then(() => import("./views/ranks.js"))
        .then(() => import("./user_socket.js"))
        .then(() => {
            // Initialize FastClick when everything is loaded
            if (typeof FastClick !== 'undefined') {
                FastClick.attach(document.body);
            }
        });
    });
}