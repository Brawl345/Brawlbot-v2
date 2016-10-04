return {

	-- Your authorization token from the botfather.
	bot_api_key = '235106290:AAF2acnyBgnE4kS70Kj4QDjU6Wbc0iU7SOM',
	-- Your Telegram ID.
	admin = 36623702,
	-- Two-letter language code.
	lang = 'de',
	-- The channel, group, or user to send error reports to.
	-- If this is not set, errors will be printed to the console.
	log_chat = nil,
	-- The port used to communicate with tg for administration.lua.
	-- If you change this, make sure you also modify launch-tg.sh.
	cli_port = 4567,
	-- The block of text returned by /start.
	about_text = [[
*Willkommen beim Brawlbot!*
Sende /hilfe, um zu starten.
	]],

	-- DO NOT CHANGE THIS
	cmd_pat = '/',
	
	-- Text for users, who are not approved
	banhammer_text = [[
	Dies ist ein privater Bot, der erst nach einer Freischaltung benutzt werden kann.
	This is a private bot, which can only be used after an approval.
	]],

	-- false = only whitelisted users can use inline querys
	-- NOTE that it doesn't matter, if the chat is whitelisted! The USER must be whitelisted!
	enable_inline_for_everyone = true,
	
	-- Path, where getFile.lua should store the files WITHOUT an ending slash!
	-- Create the following folders in this folder: photo, document, video, voice
	--getfile_path = '/home/anditest/tmp/tg',
	
	-- Redis settings. Only edit if you know what you're doing.
	redis = {
		host = '127.0.0.1',
		port = 6379,
		use_socket = true,
		socket_path = 'unix:///home/anditest/.redis/sock',
		password = nil,
		database = 1
	},

	errors = { -- Generic error messages used in various plugins.
	    generic = 'Ein unbekannter Fehler ist aufgetreten, bitte  [melde diesen Bug](https://github.com/Brawl345/Brawlbot-v2/issues).',
		connection = 'Verbindungsfehler.',
		quotaexceeded = 'API-Quota aufgebraucht.',
		results = 'Keine Ergebnisse gefunden.',
		sudo = 'Du bist kein Superuser. Dieser Vorfall wird gemeldet!',
		argument = 'Invalides Argument.',
		syntax = 'Invalide Syntax.',
		chatter_connection = 'Ich möchte gerade nicht reden',
		chatter_response = 'Ich weiß nicht, was ich darauf antworten soll.'
	},
	
    remind = {
        persist = true,
        max_length = 1000,
        max_duration = 1440,
        max_reminders_group = 5,
        max_reminders_private = 10
    },

    cleverbot = {
        cleverbot_api = 'https://brawlbot.tk/apis/chatter-bot-api/cleverbot.php?text=',
        connection = 'Ich möchte jetzt nicht reden...',
        response = 'Keine Ahnung, was ich dazu sagen soll...'
    }

}
