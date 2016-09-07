# Brawlbot v2
[![Build Status](https://travis-ci.org/Brawl345/Brawlbot-v2.svg?branch=master)](https://travis-ci.org/Brawl345/Brawlbot-v2)

Der multifunktionale Telegram-Bot.

[Offizielle Webseite](https://brawlbot.tk) | [Entwickler auf Telegram](http://telegram.me/Brawl) **KEIN SUPPORT!** | [Offizieller Kanal](https://telegram.me/brawlbot_updates)

Brawlbot ist ein auf Plugins basierender Bot, der die [offizielle Telegram Bot API](http://core.telegram.org/bots/api) benutzt. Ursprünglich wurde er im Dezember 2014 auf Basis von Yagops [Telegram Bot](https://github.com/yagop/telegram-bot/) entwickelt, da aber die Entwicklung von tg-cli [zum Stillstand](https://brawlbot.tk/posts/ein-neuanfang) gekommen ist, wurden alle Plugins des bisher proprietären Brawlbots im Juni 2016 auf die Bot-API portiert und open-sourced.  
**Brawlbot v2 basiert auf [otouto](https://github.com/topkecleon/otouto) von Topkecleon.**

**HINWEIS::** Ich gebe KEINEN Support für das Aufsetzen des Bots!

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
Falls du Ubuntu oder Debian verwendest, kannst du einfach `./install-dependencies.sh` ausführen, damit alles installiert wird. Ergänze dann noch den `bot_api_key` und die `admin`-ID (Bekommst du in Telegram mit `@Brawlbot id`) und kopiere die config.lua.example nach config.lua.

Für eine manuelle Installation musst du LuaRocks für 5.2 [selbst kompilieren](http://stackoverflow.com/a/20359102).

### Setup
Du benötigst **Lua 5.2** (Lua 5.3 funktioniert NICHT!), eine aktive **Redis-Instanz** und die folgenden **LuaRocks-Module**:
* luautf8
* luasocket
* luasec
* multipart-post
* dkjson
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
| `plugin:callback` | Aktion, die ausgeführt wird, nachdem auf einen Callback-Button gedrückt wird. Siehe `gImages.lua` für ein Beispiel. Argumente: `callback` (enthält Callback-Daten), `msg`, `self`, `config`, `input` (enthält Parameter ohne `callback`) | N |
| `plugin:inline_callback` | Aktion, die ausgeführt wird, wenn der Bot per Inline-Query ausgelöst wird. Argumente sind `inline_query` für die Daten, `config` und `matches` | N |


Die`bot:on_msg_receive` Funktion fügt einige nützte Variablen zur ` msg` Tabelle hinzu. Diese sind:`msg.from.id_str`, `msg.to.id_str`, `msg.chat.id_str`, `msg.text_lower`, `msg.from.name`.

Interaktionen mit der Bot-API sind sehr einfach. Siehe [Bindings](#bindings) für Details.

Einige Funktionen, die oft benötigt werden, sind in `utilites.lua` verfügbar.

* * *

## Bindings
Die Telegram-API wird mithilfe der `binding.lua` über die multipart-post Library kontaktiert. Brawlbots Bindings-Datei unterstützt alle Standard API-Methoden und Argumente. Die Hauptufnktion `bindings.request` akzeptiert drei Parameter: `method`, `parameters` und `file`. Bevor du die Bindings-Datei nutzt, initialisiere das Modul mit der `init`-Funktion, wobei der Bot-Token als Argument übergeben werden sollte.

`method` ist der Name der API-Methode (bspw. `sendMessage`), `parameters` (optional) ist eine Tabelle mit Schlüssel/Werte-Paaren der Parameter dieser Methode. `file` (optional) ist eine Tabelle mit einem einzigen Schlüssel/Werte-Paar, wobei der Schlüssel der Name de Parameters und der Wert der Dateiname oder die File-ID ist (wenn dies in den `parameters` übergeben wird, wird Brawlbot den Dateinamen als File-ID senden).

Zusätzlich kann jede Methode als Schlüssel in der `bindings` Tabelle (zum Beispiel `bindings.getMe`) aufgerufen werden. Die `bindings.gen` Funktion (welche auch die `__index` Funktion in der Metatabelle ist) wird ihre Argumente an `bindings.request` in der richtigen Form übergeben. Mit diesem Weg sind die folgenden zwei Funktionsaufrufe gleich:

```
bindings.request(
    'sendMessage',
    {
        chat_id = 987654321,
        text = 'Brawlbot is best bot.',
        reply_to_message_id = 54321,
        disable_web_page_preview = false,
        parse_method = 'Markdown'
    }
)

bindings.sendMessage{
    chat_id = 987654321,
    text = 'Brawlbot is best bot.',
    reply_to_message_id = 54321,
    disable_web_page_preview = false,
    parse_method = 'Markdown'
}
```

`utilities.lua` hat mehrere "Abkürzungen", die dir das leben einfacher machen. Z.b.:

```
utilities.send_message(987654321, 'Brawlbot is best bot.', false, 54321, true)
```

Eine Datei mit `sendPhoto` hochzuladen würde so aussehen:

```
utilites.sendPhoto(987654321, 'photo.jpg', 'Beschreibungstext')
```

oder mit einer File-ID:

```
utilites.sendPhoto(987654321, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789', 'Beschreibungstext')
```

Falls erfolgreich, wird bindings das deserialisierte Ergebniss der API zurückgeben. Falls nicht erfolgreich, wird `false` und das Ergebnis zurückgegeben. Falls es einen Verbindungsfehler gab, werden zwei `false` Werte zurückgegeben. Wenn ein invalider Methodenname übergeben wurde, wird bindings eine Exception ausgeben. Damit sollen "stille Fehler" vermieden werden.

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
