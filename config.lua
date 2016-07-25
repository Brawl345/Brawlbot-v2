return {

	-- Your authorization token from the botfather.
	bot_api_key = '235106290:AAGnHNheMSMkfuXt6r_hQ2hWZkCL3gHlCmw',
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
Sende /hilfe, um zu starten
	]],
	-- The symbol that starts a command. Usually noted as '/' in documentation.
	cmd_pat = '/',
	
	-- false = only whitelisted users can use inline querys
	-- NOTE that it doesn't matter, if the chat is whitelisted! The USER must be whitelisted!
	enable_inline_for_everyone = true,

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
	}

}
