# Brawlbot v2
[![Build Status](https://travis-ci.org/Brawl345/Brawlbot-v2.svg?branch=master)](https://travis-ci.org/Brawl345/Brawlbot-v2)

Der multifunktionale Telegram-Bot.

[Offizielle Webseite](https://brawlbot.tk) | [Entwickler auf Telegram](http://telegram.me/Brawl) | [Offizieller Kanal](https://telegram.me/brawlbot_updates)

Brawlbot ist ein auf Plugins basierender Bot, der die [offizielle Telegram Bot API](http://core.telegram.org/bots/api) benutzt. Ursprünglich wurde er im Dezember 2014 auf Basis von Yagops [Telegram Bot](https://github.com/yagop/telegram-bot/) entwickelt, da aber die Entwicklung von tg-cli [zum Stillstand](https://brawlbot.tk/posts/ein-neuanfang) gekommen ist, wurden alle Plugins des bisher proprietären Brawlbots im Juni 2016 auf die Bot-API portiert und open-sourced.  
**Brawlbot v2 basiert auf [otouto](https://github.com/topkecleon/otouto) von Topkecleon.**

Brawlbot v2 ist freie Software; du darfst ihn modifizieren und weiterverbreiten, allerdings musst du dich an die GNU Affero General Public License v3 halten, siehe **LICENSE** für Details.

##Anleitung

| Für User                                     | Für Entwickler|
|:----------------------------------------------|:------------------------------|
| [Setup](#setup)                               | [Plugins](#plugins)           |
| [Bot steuern](#bot-steuern)           | [Bindings](#bindings)         |
|												| [Datenbank](#datenbank)

* * *
# Für User
## Setup
### Ubuntu und Debian
Ubuntu und Debian liefern Luarocks nur für Lua 5.1 aus. Um Luarocks für Lua 5.2 zu verwenden, folge bitte der [Anleitung auf StackOverflow](http://stackoverflow.com/a/20359102).

### Setup
Du benötigst **Lua 5.2+**, eine aktive **Redis-Instanz** und die folgenden **LuaRocks-Module**:
* luasocket
* luasec
* multipart-post
* lua-cjson
* lpeg
* redis-lua
* fakeredis
* oauth
* xml
* feedparser
* serpent

Klone danach diese Repo. kopiere die `config.lua.example` nach `config.lua` und trage folgendes ein:

 - `bot_api_key`: API-Token vom BotFather
 - `admin`: Deine Telegram-ID

Starte danach den Bot mit `./launch.sh`. Um den Bot anzuhalten, führe erst `/halt` über Telegram aus.

Beim Start werden einige Werte in die Redis-Datenbank unter `telegram:credentials` und `telegram:enabled_plugins` eingetragen. Mit `/plugins enable` kannst du Plugins aktivieren, es sind nicht alle von Haus aus aktiviert.

Einige Plugins benötigen API-Keys, bitte gehe die einzelnen Plugins durch, bevor du sie aktivierst!

* * *

## Bot steuern
Ein Administrator kann den Bot über folgende Plugins steuern:

| Plugin          | Kommando   | Funktion                                           |
|:----------------|:-----------|:---------------------------------------------------|
| `banhammer.lua` | Siehe /hilfe banhammer| Blockt User vom Bot und kann Whitelist aktivieren
| `control.lua`   | /restart    | Startet den Bot neu             |
|                 | /halt      | Speichert die Datenbank und stoppt den Bot      |
|                 | /script    | Führt mehrere Kommandos aus, getrennt mit Zeilenumbrüchen |
| `luarun.lua`    | /lua       | Führt LUA-Kommandos aus    |
| `plugins.lua`    | /plugins enable/disable       | Aktiviert/deaktiviert Plugins   |
| `shell.lua`     | /sh       | Führt Shell-Kommandos aus        |

* * *

## Gruppenadministration über tg-cli
Dieses Feature wird in Brawlbot nicht unterstützt.

* * *

## Liste aller Plugins

Brawlbot erhält laufend neue Plugins und wird kontinuierlich weiterentwickelt! Siehe [hier](https://github.com/Brawl345/Brawlbot-v2/tree/master/otouto/plugins) für eine Liste aller Plugins.

* * *
#Für Entwickler
## Plugins
Brawlbot benutzt ein Plugin-System, ähnlich Yagops [Telegram-Bot](http://github.com/yagop/telegram-bot).

Ein Plugin kann zehn Komponenten haben, aber nur zwei werden benötigt:

| Komponente        | Beschreibung                                  | Benötigt? |
|:------------------|:---------------------------------------------|:----------|
| `plugin:action`   | Hauptfunktion. Benötigt `msg` als Argument, empfohlen wird auch `matches` als drittes Argument nach `config`   | J |
| `plugin.triggers` | Tabelle von Triggern (Lua-Patterns), auf die der Bot reagiert | J |
| `plugin.inline_triggers` | Tabelle von Triggern (Lua-Patterns), auf die der Bot bei Inline-Querys reagiert | N |
| `plugin:init`     | Optionale Funkion, die beim Start geladen wird     | N |
| `plugin:cron`     | Wird jede Minute ausgeführt         | N |
| `plugin.command`  | Einfaches Kommando mit Syntax. Wird bei `/hilfe` gelistet   | N |
| `plugin.doc`      | Plugin-Hilfe. Wird mit `/help $kommando` gelistet  | N |
| `plugin.error`    | Plugin-spezifische Fehlermeldung | N |
| `plugin:callback` | Aktion, die ausgeführt wird, nachdem auf einen Callback-Button gedrückt wird. Siehe `gImages.lua` für ein Beispiel. Argumente: `callback` (enthält Callback-Daten), `msg`, `self`, `config`, `input` (enthält Parameter ohne `callback` | N |
| `plugin:inline_callback` | Aktion, die ausgeführt wird, wenn der Bot per Inline-Query ausgelöst wird. Argumente sind `inline_query` für die Daten, `config` und `matches` | N |


Die`bot:on_msg_receive` Funktion fügt einige nützte Variablen zur ` msg` Tabelle hinzu. Diese sind:`msg.from.id_str`, `msg.to.id_str`, `msg.chat.id_str`, `msg.text_lower`, `msg.from.name`.

Rückgabewerte für `plugin:action` sind optional, aber wenn eine Tabelle zurückgegeben wird, wird diese die neue `msg`,-Tabelle und `on_msg_receive` wird damit fortfahren.

Interaktionen mit der Bot-API sind sehr einfach. Siehe [Bindings](#bindings) für Details.

Einige Funktionen, die oft benötigt werden, sind in `utilites.lua` verfügbar.

* * *

## Bindings
**Diese Sektion wurde noch nicht lokalisiert.**
Calls to the Telegram bot API are performed with the `bindings.lua` file through the multipart-post library. otouto's bindings file supports all standard API methods and all arguments. Its main function, `bindings.request`, accepts four arguments: `self`, `method`, `parameters`, `file`. (At the very least, `self` should be a table containing `BASE_URL`, which is bot's API endpoint, ending with a slash, eg `https://api.telegram.org/bot123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ987654321/`.)

`method` is the name of the API method. `parameters` (optional) is a table of key/value pairs of the method's parameters to be sent with the method. `file` (super-optional) is a table of a single key/value pair, where the key is the name of the parameter and the value is the filename (if these are included in `parameters` instead, otouto will attempt to send the filename as a file ID).

Additionally, any method can be called as a key in the `bindings` table (for example, `bindings.getMe`). The `bindings.gen` function (which is also the __index function in its metatable) will forward its arguments to `bindings.request` in their proper form. In this way, the following two function calls are equivalent:

```
bindings.request(
	self,
	'sendMessage',
	{
		chat_id = 987654321,
		text = 'Quick brown fox.',
		reply_to_message_id = 54321,
		disable_web_page_preview = false,
		parse_method = 'Markdown'
	}
)

bindings.sendMessage(
	self,
	{
		chat_id = 987654321,
		text = 'Quick brown fox.',
		reply_to_message_id = 54321,
		disable_web_page_preview = false,
		parse_method = 'Markdown'
	}
)
```

Furthermore, `utilities.lua` provides two "shortcut" functions to mimic the behavior of otouto's old bindings: `send_message` and `send_reply`. `send_message` accepts these arguments: `self`, `chat_id`, `text`, `disable_web_page_preview`, `reply_to_message_id`, `use_markdown`. The following function call is equivalent to the two above:

```
utilities.send_message(self, 987654321, 'Quick brown fox.', false, 54321, true)
```

Uploading a file for the `sendPhoto` method would look like this:

```
bindings.sendPhoto(self, { chat_id = 987654321 }, { photo = 'rarepepe.jpg' } )
```

and using `sendPhoto` with a file ID would look like this:

```
bindings.sendPhoto(self, { chat_id = 987654321, photo = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789' } )
```

Upon success, bindings will return the deserialized result from the API. Upon failure, it will return false and the result. In the case of a connection error, it will return two false values. If an invalid method name is given, bindings will throw an exception. This is to mimic the behavior of more conventional bindings as well as to prevent "silent errors".

* * *

## Datenbank
Brawlbot benutzt eine interne Datenbank, wie Otouto sie benutzt und Redis. Die "Datenbank" ist eine Tabelle, auf die über die Variable `database` zugegriffen werden kann (normalerweise `self.database`) und die als JSON-encodierte Plaintext-Datei jede Stunde gespeichert wird oder wenn der Bot gestoppt wird (über `/halt`).

Das ist die Datenbank-Struktur:

```
{
	users = {
		["55994550"] = {
			id = 55994550,
			first_name = "Drew",
			username = "topkecleon"
		}
	},
	userdata = {
		["55994550"] = {
			nickname = "Best coder ever",
			lastfm = "topkecleon"
		}
	},
	version = "2.1"
}
```

`database.users` speichert User-Informationen, wie Usernamen, IDs, etc., wenn der Bot den User sieht. Jeder Tabellen-Key ist die User-ID als String.

`database.userdata` speichert Daten von verschiedenen Plugins, hierzu wird aber für Brawlbot-Plugins Redis verwendet.

`database.version` speichert die Bot-Version.

* * *