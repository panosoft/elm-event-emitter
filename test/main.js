// load Elm module
const elm = require('./elm.js');

// Start
elm.Main.worker();

// keep our app alive until we get an exitCode from Elm or SIGINT or SIGTERM (see below)
setInterval(id => id, 86400);

process.on('uncaughtException', err => {
	console.log(`Uncaught exception:\n`, err);
	process.exit(1);
});

process.on('SIGINT', _ => {
	console.log(`SIGINT received.`);
	process.exit(0);
});

process.on('SIGTERM', _ => {
	console.log(`SIGTERM received.`);
	process.exit(0);
});
