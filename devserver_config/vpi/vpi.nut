// VScript-Python Interface
// Client

// Made by Mince (STEAM_0:0:41588292)

local VERSION = "1.0.0";
////////////////////////////////////////// SCRIPT VARS //////////////////////////////////////////
// Server owners modify this section

/*
// Uncomment and use this on a listen server to generate a secret before you do anything
// ent_fire !self callscriptfunction GenerateSecret
::GenerateSecret <- function(n=128) {
	local s = "";
	for (local i = 0; i < n; ++i)
	{
		// 35 instead of 32 so user doesn't have to deal with quotations
		s += randomint(35, 126).tochar();
	}
	printl(s);
	return s;
};
*/

// Token used to verify the identity of the functions we expose to the public to prevent tampering
// If they do not return this secret when prompted the program will abort
// Also used to prove our identity to server
// Avoid putting this token into a variable as error locals traces can give away its value
local function GetSecret() {
	return @"9320fkslkdajkf#(FP#0";
}

// Note: This only works to ensure security if vpi.nut is executed within mapspawn.nut
// Do not set this to false unless you handle wrapping the file functions elsewhere
local PROTECTED_FILE_FUNCTIONS = true;

// Stores which source files are allowed to use what interface functions, if the table is empty whitelist is disabled
// You may match against interface function names with regexp, to do so, start and end the string with forward slash /
// and create any pattern defined by squirrel: http://squirrel-lang.org/squirreldoc/stdlib/stdstringlib.html#the-regexp-class
// { "source.nut" : [ "VPI_InterfaceFunctionName", @"/VPI_DB_User.*/" ] }
local SOURCE_WHITELIST = {
	"vpi.nut": null, // Null or empty list denotes uninhibited access
	"functions.nut": ["VPI_MGE_ReadWritePlayerStats", "VPI_MGE_PopulateLeaderboard"],
	"mge.nut": ["VPI_MGE_DBInit", "VPI_MGE_AutoUpdate", "VPI_MGE_UpdateServerData"],
};

local SCRIPTDATA_DIR = "mge_playerdata";

// How often we normally write to file (in ticks)
local WRITE_INTERVAL = 198; // 3 s

// How often we check our input file for a response from the server
local WATCH_INTERVAL = 66; // 1 s

// We just wrote to file, check for quick responses from server
// (only check up to MAX_EXPECTING_ITERS, then go back to regular WATCH_INTERVAL)
local EXPECTING_INTERVAL  = 11; // ~167 ms
local MAX_EXPECTING_ITERS = 6;
local expecting_iters     = null;

// Urgent calls are written immediately if allowed to, otherwise wait until next write interval
local URGENT_WRITE_MAX_COUNT = 3; // How many urgent calls per WRITE_INTERVAL are allowed
local urgent_write_count     = 0;

// How many seconds to wait for response before call times out
local CALLBACK_TIMEOUT = 10.0;
// How often we check on timeouts (in ticks)
local CALLBACK_TIMEOUT_CHECK_INTERVAL = 33; // 0.5s


// Bit flags for what messages to output to users
// 0  - Silent
// 1  - Debug
// 2  - Errors
// 4  - Warnings
// 8  - Misc
// --------------
// 14 - (ALL - DEBUG)
// 15 - (ALL)
local LOG_MSG_LEVEL = 14;

///////////////////////////////////////////////////////////////////////////////////////////////////

local MSG_DEBUG   = 1;
local MSG_ERROR   = 2;
local MSG_WARNING = 4;
local MSG_MISC    = 8;

local NOTIFY_CONSOLE = 1;
local NOTIFY_CHAT    = 2;
local NOTIFY_CENTER  = 4;

local function PrintMessage(player, msg, level=MSG_MISC, notify=NOTIFY_CONSOLE)
{
	if (LOG_MSG_LEVEL <= 0) return;
	if (!(LOG_MSG_LEVEL & level)) return;

	if (level == MSG_ERROR)        msg = "[VPI] -- ERROR -- " + msg;
	else if (level == MSG_WARNING) msg = "[VPI] -- WARNING -- " + msg;
	else if (level == MSG_DEBUG)   msg = "[VPI] -- DEBUG -- " + msg;
	else                           msg = "[VPI] -- " + msg;

	if (notify & NOTIFY_CONSOLE) ClientPrint(player, 2, msg);
	if (notify & NOTIFY_CENTER)  ClientPrint(player, 4, msg);
	if (notify & NOTIFY_CHAT)
	{
		local chatmsg = msg;
		if (level == MSG_ERROR)
			chatmsg = "\x07ff5757" + msg;
		else if (level == MSG_WARNING)
			chatmsg = "\x07ffeb52" + msg;
		else
			chatmsg = "\x07D9F4FC" + msg;

		ClientPrint(player, 3, chatmsg);
	}

	if (level == MSG_ERROR)
		throw msg;
}

local is_potato_server = GetStr("sv_tags").find("potato");

if (!GetSecret().len() && !is_potato_server)
	PrintMessage(null, "Please set your secret token", MSG_ERROR, NOTIFY_CHAT);

local lateload = (Entities.FindByName(null, "bignet") != null);
if (lateload && !is_potato_server)
	PrintMessage(null, "Late loading is not permitted as it is a security risk, please load in mapspawn.nut", MSG_ERROR, NOTIFY_CHAT);

local ROOT = getroottable();

local stringtofile = ::StringToFile;
local filetostring = ::FileToString;
local randomint    = ::RandomInt;

local challenge_response;
local should_write_before_destroy = true;
local function ValidateIntegrity()
{
	local function Validate(challenge)
	{
		local response = challenge_response;
		challenge_response = null;

		return ( response == GetSecret() );
	}

	try
	{
		if (PROTECTED_FILE_FUNCTIONS)
		{
			if ( !Validate(::StringToFile(null, null, true)) ) throw null;
			if ( !Validate(::FileToString(null, true)) )       throw null;
		}

		if ("VPI" in ROOT)
		{
			if ( !Validate(VPI.Call(null, null, null, null, null, true)) ) throw null;
			if ( !Validate(VPI.AsyncCall(null, true)) )                    throw null;
		}

		if (::RandomInt.tostring().find("native function") == null) throw null;
	}
	catch (e)
	{
		challenge_response = null;
		should_write_before_destroy = false;
		PrintMessage(null, "*** PROTECTED FUNCTION TAMPERING DETECTED; ABORTING ***", MSG_ERROR, NOTIFY_CHAT);
	}
}

if (PROTECTED_FILE_FUNCTIONS)
{
	local function GetFileExtension(file)
	{
		local index = null;
		for (local i = file.len() - 1; i >= 0; --i)
		{
			if (file[i] == '.')
			{
				index = i;
				break;
			}
		}

		if (index == null) return;
		return file.slice(index);
	}

	// Filter the source that called us in the VM stack
	local function ValidateFileCaller(src, file)
	{
		local extension = GetFileExtension(file);
		if (!extension || extension == "" || extension != ".interface")
			return true;
		else
			return (src == "vpi.nut");
	}

	::StringToFile <- function(file, str, __challenge=false) {
		local callinfo = getstackinfos(2);
		if (__challenge)
		{
			if (callinfo.src == "vpi.nut")
				challenge_response = GetSecret();
			return;
		}

		if (typeof(file) != "string") return;
		if (typeof(str)  != "string") return;
		if (!ValidateFileCaller(callinfo.src, file)) return;

		stringtofile(format("%s/%s", SCRIPTDATA_DIR, file), str);
	};

	::FileToString <- function(file, __challenge=false) {
		local callinfo = getstackinfos(2);
		if (__challenge)
		{
			if (callinfo.src == "vpi.nut")
				challenge_response = GetSecret();
			return;
		}

		if (typeof(file) != "string") return;
		if (!ValidateFileCaller(callinfo.src, file)) return;

		return filetostring(format("%s/%s", SCRIPTDATA_DIR, file));
	};
}


// Storage for interface calls so we can write on an interval
local call_list = {
	normal = {
		async=[],
	},
	urgent = {
		async=[],
	},
};

local callbacks   = {};
local used_tokens = {};

// We delay sending calls until this is true so hostname can have the proper value
local server_cfg_execd = false;
local HOSTNAME;

local function GetSanitizedHostname()
{
	// Strip hostname of characters other than [a-z0-9_]
	try
	{
		local hostname = GetStr("hostname").tolower();
		local str = "";
		foreach (code in hostname)
		{
			if (code < 33 && !endswith(hostname, "_"))
			{
				str += "_";
				continue;
			}
			if (code < 48 || (code > 57 && code < 97) || code > 122) continue;

			str += code.tochar();
		}
		return str;
	}
	catch (e)
		return "team_fortress"
}

local INPUT_FILE;

local MAX_FILE_SIZE = 16000;
local INT_MAX       = 2147483647;

local EPOCH = {
	year   = 1970,
	month  = 1,
	day    = 1,
	hour   = 0,
	minute = 0,
	second = 0,
};


////////////////////////////////////////////// JSON /////////////////////////////////////////////
// Based on implementation: https://github.com/electricimp/JSONEncoder/blob/v2.0.0/JSONEncoder.class.nut

// Max depth for encoding objects
local MAXDEPTH = 32;

// Char classifications used for tokenization
local ALPHANUMERIC = {};
local WHITESPACE   = {['\t']=null, ['\n']=null, ['\r']=null, ['\f']=null, [' ']=null, [255]=null, [127]=null};
local PUNCTUATION  = {};

for (local i = 48; i <= 57; ++i)  ALPHANUMERIC[i] <- null;
for (local i = 65; i <= 90; ++i)  ALPHANUMERIC[i] <- null;
for (local i = 97; i <= 122; ++i) ALPHANUMERIC[i] <- null;
for (local i = 33; i < 255; ++i)
	if (!(i in ALPHANUMERIC) && !(i in WHITESPACE))
		PUNCTUATION[i] <- null;

local function Escape(str)
{
	local res = "";

	for (local i = 0; i < str.len(); i++)
	{
		local ch1 = (str[i] & 0xFF);

		// 7-bit Ascii
		if ((ch1 & 0x80) == 0x00)
		{
			ch1 = format("%c", ch1);

			if (ch1 == "\"")
				res += "\\\"";
			else if (ch1 == "\\")
				res += "\\\\";
			else if (ch1 == "/")
				res += "\\/";
			else if (ch1 == "\b")
				res += "\\b";
			else if (ch1 == "\f")
				res += "\\f";
			else if (ch1 == "\n")
				res += "\\n";
			else if (ch1 == "\r")
				res += "\\r";
			else if (ch1 == "\t")
				res += "\\t";
			else if (ch1 == "\0")
				res += "\\u0000";
			else
				res += ch1;
		}
		else
		{
			if ((ch1 & 0xE0) == 0xC0)
			{
				// 110xxxxx = 2-byte unicode
				local ch2 = (str[++i] & 0xFF);
				res += format("%c%c", ch1, ch2);
			}
			else if ((ch1 & 0xF0) == 0xE0)
			{
				// 1110xxxx = 3-byte unicode
				local ch2 = (str[++i] & 0xFF);
				local ch3 = (str[++i] & 0xFF);
				res += format("%c%c%c", ch1, ch2, ch3);
			}
			else if ((ch1 & 0xF8) == 0xF0)
			{
				// 11110xxx = 4 byte unicode
				local ch2 = (str[++i] & 0xFF);
				local ch3 = (str[++i] & 0xFF);
				local ch4 = (str[++i] & 0xFF);
				res += format("%c%c%c%c", ch1, ch2, ch3, ch4);
			}
		}
	}

	return res;
}

local function UnEscape(str)
{
    local res = "";
    local i = 0;

    while (i < str.len())
	{
        local ch1 = str[i].tochar();

        if (ch1 == "\\" && i + 1 < str.len())
		{
            ++i; // Skip the backslash

            ch1 = str[i].tochar();

            // Handle escape sequences
            if (ch1 == "\"")
                res += "\"";
            else if (ch1 == "\\")
                res += "\\";
            else if (ch1 == "/")
                res += "/";
            else if (ch1 == "b")
                res += "\b";
            else if (ch1 == "f")
                res += "\f";
            else if (ch1 == "n")
                res += "\n";
            else if (ch1 == "r")
                res += "\r";
            else if (ch1 == "t")
                res += "\t";
            else if (ch1 == "u")
			{
                // Handle Unicode escape sequences \uXXXX
                if (i + 5 < str.len())
				{
                    local hex = str.slice(i + 1, i + 5);
                    local uni = hex.tointeger(16);
                    res += format("%c", uni);
                    i += 4; // Skip past the 4 hex digits
                }
            }
			else
			{
                res += "\\" + ch1;
            }
        }
		else
		{
            // Add non-escaped character to result
            res += ch1;
        }

        ++i;
    }

    return res;
}

local function Tokenize(str)
{
	local tokens = [];

	local start_index = null;
	local in_string   = false;
	local in_escape   = false;

	foreach (i, char in str)
	{
		if (in_escape)
		{
			in_escape = false;
			if (char == '"') continue;
		}

		if (char in ALPHANUMERIC)
		{
			if (start_index != null) continue;
			start_index = i;
		}
		else if (char in WHITESPACE)
		{
			if (in_string || start_index == null) continue;

			tokens.append(str.slice(start_index, i));
			start_index = null;
		}
		else if (char in PUNCTUATION)
		{
			switch (char)
			{
			case '-':
			case '.':
				break;
			case '\\':
				assert(in_string);
				in_escape = !in_escape;
				break;
			case '"':
				if (!in_string)
				{
					if (start_index)
						tokens.append(str.slice(start_index, i));

					in_string   = true;
					start_index = i;
				}
				else
				{
					tokens.append(str.slice(start_index, i+1));
					in_string   = false;
					start_index = null;
				}
				break;
			default:
				if (in_string) continue;
				if (start_index)
					tokens.append(str.slice(start_index, i));

				tokens.append(char.tochar());

				start_index = null;
			}
		}
	}

	assert(!in_string);

	if (start_index != null)
		tokens.append(str.slice(start_index));

	return tokens;
}

local ParseTokens;
ParseTokens = function(tokens, start_index=0)
{
	local next_index = start_index + 1;

	local token = tokens[start_index];
	local obj   = null;

	// Bool
	if (token == "true")
		obj = true;
	else if (token == "false")
		obj = false;
	// String
	else if (token[0] == '"' && token[token.len()-1] == '"')
		obj = UnEscape(token.slice(1, -1));
	// Float
	else if (token.find(".") != null || token.find("e") != null)
	{
		try { obj = token.tofloat() }
		catch (e) {}
	}
	// Integer
	else
	{
		try { obj = token.tointeger() }
		catch (e) {}
	}

	// Array / Object
	if (token != "null" && obj == null)
	{
		assert(start_index < tokens.len() - 1);
		local closed = false;
		local state  = 0;

		switch (token)
		{
		case "[":
			// State
			// 0 - Expecting element or ]
			// 1 - Expecting , or ]
			// 2 - Expecting element

			obj = [];
			while (next_index < tokens.len())
			{
				local peek = tokens[next_index];
				if (peek == "]")
				{
					assert(state != 2);
					closed = true;
					++next_index;
					break;
				}
				else if (peek == ",")
				{
					assert(state == 1);
					state = 2;
					++next_index;
				}
				else
				{
					assert(state == 0 || state == 2);
					state = 1;

					local o = ParseTokens(tokens, next_index);
					assert(o != null);

					obj.append(o.obj);
					next_index = o.next_index;
				}
			}

			assert(closed);
			break;

		case "{":
			// State
			// 0 - Expecting key or }
			// 1 - Expecting :
			// 2 - Expecting value
			// 3 - Expecting , or }
			// 4 - Expecting key

			obj = {};
			local key = null;
			while (next_index < tokens.len())
			{
				local peek = tokens[next_index];

				if (peek == "}")
				{
					assert(state == 0 || state == 3);
					closed = true;
					++next_index;
					break;
				}
				else if (peek == ":")
				{
					assert(state == 1);
					state = 2;
					++next_index;
				}
				else if (peek == ",")
				{
					assert(state == 3);
					state = 4;
					key = null;
					++next_index;
				}
				else
				{
					assert(state != 1 && state != 3);

					local o = ParseTokens(tokens, next_index);

					// Key
					if (state != 2)
					{
						assert(typeof(o.obj) == "string");
						assert(!(o.obj in obj));
						key = o.obj;
					}
					// Value
					else
					{
						assert(key);
						obj[key] <- o.obj;
					}

					next_index = o.next_index;
					state = (state == 2) ? 3 : 1;
				}
			}

			assert(closed);
			break;
		default:
			throw format("Unexpected token %s", token);
		}
	}

	if (token != "null")
		assert(obj != null);

	if (!start_index)
		return obj;
	else
		return { obj=obj, next_index=next_index };
}

local JSON = {
	function Encode(val, _depth=0)
	{
		if (_depth > MAXDEPTH) throw "Possible cyclic reference";

		local s = "";
		switch (typeof val)
		{
		case "table":
		case "class":
			foreach (k, v in val)
				if (typeof v != "function")
					s += ",\"" + k + "\":" + Encode(v, _depth+1);

			return "{" + ( s.len() ? s.slice(1) : s ) + "}";

		case "array":
			local len = val.len();
			if (!len) return "[]";

			foreach (i, e in val)
				s += Encode(val[i], _depth+1) + (i != len - 1 ? "," : "");

			return "[" + s + "]";

		case "integer":
		case "float":
		case "bool":
			return val.tostring();

		case "null":
			return "null";

		case "instance":
			if ("_encode" in val && typeof val._encode == "function")
				return Encode(val._encode(), _depth+1);
			else
			{
				try
				{
					// _nexti
					foreach (k, v in val)
						s += ",\"" + k + "\":" + Encode(v, _depth+1);
				}
				catch (e)
				{
					foreach (k, v in val.getclass())
						if (typeof v != "function")
							s += ",\"" + k + "\":" + Encode(val[k], _depth+1);
				}

				return "{" + (s.len() ? s.slice(1) : s) + "}";
			}

		default:
			return "\"" + Escape(val.tostring()) + "\"";
		}
	},

	function Decode(str)
	{
		local tokens = Tokenize(str);
		return ParseTokens(tokens);
	},
};

//marked unsafe since map scripts can override this variable name
::JSON_UNSAFE <- {
	function Encode(val, _depth=0)
	{
		if (_depth > MAXDEPTH) throw "Possible cyclic reference";

		local s = "";
		switch (typeof val)
		{
		case "table":
		case "class":
			foreach (k, v in val)
				if (typeof v != "function")
					s += ",\"" + k + "\":" + Encode(v, _depth+1);

			return "{" + ( s.len() ? s.slice(1) : s ) + "}";

		case "array":
			local len = val.len();
			if (!len) return "[]";

			foreach (i, e in val)
				s += Encode(val[i], _depth+1) + (i != len - 1 ? "," : "");

			return "[" + s + "]";

		case "integer":
		case "float":
		case "bool":
			return val.tostring();

		case "null":
			return "null";

		case "instance":
			if ("_encode" in val && typeof val._encode == "function")
				return Encode(val._encode(), _depth+1);
			else
			{
				try
				{
					// _nexti
					foreach (k, v in val)
						s += ",\"" + k + "\":" + Encode(v, _depth+1);
				}
				catch (e)
				{
					foreach (k, v in val.getclass())
						if (typeof v != "function")
							s += ",\"" + k + "\":" + Encode(val[k], _depth+1);
				}

				return "{" + (s.len() ? s.slice(1) : s) + "}";
			}

		default:
			return "\"" + Escape(val.tostring()) + "\"";
		}
	},

	function Decode(str)
	{
		local tokens = Tokenize(str);
		return ParseTokens(tokens);
	},
};


///////////////////////////////////////////////////////////////////////////////////////////////////


local function Timestamp(time=null, epoch=null, timezone={dir=1,hour=5,minute=0})
{
	if (!time)
	{
		time = {};
		LocalTime(time);
	}
	if (!epoch) epoch = EPOCH;

	function isLeapYear(year) {
		return (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
	}

	local days = 0;

	for (local year = epoch.year; year < time.year; ++year)
		days += (isLeapYear(year)) ? 366 : 365;

	days += time.dayofyear;

	local seconds = days * 86400;

	seconds += time.hour * 3600;
	seconds += time.minute * 60;
	seconds += time.second;

	if (timezone)
	{
		local mod = timezone.hour * 3600;
		mod += timezone.minute * 60;

		if (timezone.dir) seconds += mod;
		else seconds -= mod;
	}

	return seconds;
}

// Simple encryption algorithm based on timestamp, time, and a key
local function Encrypt(str)
{
	local timestamp = Timestamp();
	local time      = (Time() / 0.015).tointeger();

	// Add a bit of randomness
	local t = (timestamp + time) % 1024; // Sin doesn't give good output for large values, keep things small
	local f = fabs(sin(16 * t));         // Give our time a bit of variance
	local h = floor(f * 127 + 0.5);      // Get a hash value from 0 - 127 (really this could be any number though)

	// Initialization vector to provide true randomness since we always use the same key
	// Without this the output tends to repeat quite often
	local iv = "";
	foreach (ch in str)
		iv += randomint(35, 126).tochar();

	local enc = "";
	foreach (i, ch in str)
	{
		local key_index = i % GetSecret().len();  // Corresponding index in our key, loop if necessary
		local key_char  = GetSecret()[key_index];

		// Encode the character; shifted using hash and key_char; limited to 32 - 127 ASCII
		enc += (32 + (ch + h + iv[i] + key_char) % 95).tochar();
	}

	return {
		enc       = enc,
		iv        = iv,
		timestamp = timestamp,
		ticks     = time,
	};
}
// Decryption
local function Decrypt(enc, iv, timestamp, ticks)
{
	local t = (timestamp + ticks) % 1024;
	local f = fabs(sin(16 * t));
	local h = floor(f * 127 + 0.5);

	local dec = "";
	foreach (i, ch in enc)
	{
		local key_index = i % GetSecret().len();
		local key_char  = GetSecret()[key_index];

		local dec_char = (ch - 32 - h - iv[i] - key_char) % 95;
		if (dec_char < 32)
			dec_char += 95 * ceil((32 - dec_char) / 95.0);
		dec += dec_char.tochar();
	}

	return dec;
}

local function SetDestroyCallback(entity, callback)
{
	entity.ValidateScriptScope();
	local scope = entity.GetScriptScope();
	scope.setdelegate({}.setdelegate({
			parent   = scope.getdelegate(),
			id       = entity.GetScriptId(),
			index    = entity.entindex(),
			callback = callback,
			_get = function(k)
			{
				return parent[k];
			},
			_delslot = function(k)
			{
				if (k == id)
				{
					entity = EntIndexToHScript(index);
					local scope = entity.GetScriptScope();
					scope.self <- entity;
					callback.pcall(scope);
				}
				delete parent[k];
			},
		})
	);
}

// Filter the source that called us in the VM stack
local function ValidateCaller(src, func)
{
	if (func == "" || typeof(func) != "string") return false;

	// Do not allow anonymous callers
	if (!src || !endswith(src, ".nut")) return false;

	// Whitelist
	if (func && SOURCE_WHITELIST.len())
	{
		// Do not allow untrustworthy source files
		if (!(src in SOURCE_WHITELIST)) return false;

		local interfaces = SOURCE_WHITELIST[src];

		// Any function may be used
		if (!interfaces || !interfaces.len()) return true;

		// Only specific interface function calls allowed
		local found = false;
		foreach (s in interfaces)
		{
			if (typeof(s) != "string") continue;

			// Regexp
			if (s.len() > 2 && startswith(s, "/") && endswith(s, "/"))
			{
				local rex = regexp(s.slice(1, -1));
				if (rex.match(func))
				{
					found = true;
					break;
				}
			}
			else if (s == func)
			{
				found = true;
				break;
			}
		}

		return found;
	}

	return true;
}

// Class instantiation is faster than using tables
local VPICallInfo = class
{
	token    = null;
	func     = null;
	kwargs   = null;
	callback = null;
	urgent   = null;
	timeout  = null;

	GetScript = null;

	constructor(secret, s=null, f=null, k=null, c=null, u=null, t=null)
	{
		if (secret != GetSecret())
			PrintMessage(null, "*** PROTECTED FUNCTION TAMPERING DETECTED; ABORTING ***", MSG_ERROR, NOTIFY_CHAT);

		token  = UniqueString();

		// Squirrel has no private members or way to detect instance modification
		// so we provide closure getters instead for sensitive data that should not be tampered with
		local script = s;
		GetScript    = function() { return script };

		func     = f;
		urgent   = u;
		callback = c;
		kwargs   = k;

		timeout  = t;
	}
}

// Encode either our normal calls or urgent calls into JSON
// JSON format:
// {...} -- VPICallInfo table
/*
	"Calls": {
		"async": [
			{...},
			{...}
		],
	}
*/
local function EncodeOutput(list)
{
	// This structure gets turned into JSON
	local table = { "Calls":{"async":[]} };

	// Encrypt our secret and send it to the server for verification
	table.Identity <- Encrypt(GetSecret());

	// We don't want every member of VPICallInfo to be sent to server
	// Make a table of only what's needed
	local function GetCallTable(call)
	{
		local t = {};

		foreach (k, v in call.getclass())
		{
			if (typeof(v) == "function" && k != "callback") continue;
			if (k == "urgent" || k == "timeout") continue;

			t[k] <- call[k];
		}

		// Private
		t.script <- call.GetScript();

		// Turn function value into bool
		// Server only needs to know if it needs to send the result back or not
		if (t.callback) t.callback = true;
		else t.callback = false;

		return t;
	}

	foreach (call in list.async)
		table.Calls.async.append(GetCallTable(call));

	return JSON.Encode(table);
}

// Write interface calls to file as JSON
local last_write_time = null;
local function WriteCallList(list, combined=false)
{

	if (!list.async.len()) return 0;

	// Our write file name's uniqueness is based on tick count
	// Don't write if we already wrote this tick
	local time = Time();
	if (time <= last_write_time) return -1;

	// Reading files seems to be about 3x as expensive as writing
	// If we used a single output file we would have to read to see if we can write,
	// so the simple solution is to base file name off timestamp and tick count and let the server handle the hard work
	local output_file = format("%s_vpi_%d_%d_output.interface", HOSTNAME, Timestamp(), time / 0.015);

	StringToFile(output_file, EncodeOutput(list));

	// Document the write time for current callbacks
	foreach (call in list.async)
	{
		if (!(call.token in callbacks)) continue;

		local cbt = callbacks[call.token];
		cbt.calltime = time;
	}

	// Clear calls
	if (combined)
	{
		call_list = {
			normal = {
				async=[],
			},
			urgent = {
				async=[],
			},
		};
	}
	else
	{
		list.async = [];
	}

	last_write_time = time;

	// Start watching for a response from the server more frequently
	expecting_iters = 0;

	return 1;
}

local function TryExecCallback(token, data, error)
{
	if (token in callbacks)
	{
		local cbt = callbacks[token];

		try { cbt.callback(data, error); }
		catch (e) {
			PrintMessage(null, format("User callback '%s' threw error '%s'", token, e), MSG_WARNING);
		}

		delete callbacks[token];
	}
}

// Read callbacks results from the server
local function HandleCallbacks()
{
	if (!callbacks.len()) return;

	local contents = FileToString(INPUT_FILE);
	if (!contents || contents == "") return;

	try
	{
		local table = JSON.Decode(contents);

		local id = table.Identity;
		id = Decrypt(id.enc, id.iv, id.timestamp, id.ticks)
		if (id != GetSecret())
		{
			PrintMessage(null, format("Invalid identification received from file: '%s'", INPUT_FILE), MSG_WARNING);
			throw null;
		}

		local calls = table.Calls;

		// Look to see if any of our callbacks have results
		foreach (token, cbt in callbacks)
		{
			if (!(token in calls)) continue;

			local calldata = calls[token];

			// Peek at calldata and print if error
			local error = false;
			if (typeof(calldata) == "string" && startswith(calldata, "[VPI ERROR]"))
			{
				PrintMessage(null, format("Server returned error for call -\ntoken: %s\nerror: %s\n", token, calldata), MSG_WARNING);
				error = true;
			}

			TryExecCallback(token, calldata, error);
		}

	}
	catch (e)
		if (e != null)
			PrintMessage(null, format("Invalid input from file: '%s'", INPUT_FILE), MSG_WARNING);

	// Wipe the file to let the server know we've handled its contents
	// and it can send anything else it's waiting to write
	StringToFile(INPUT_FILE, "");

	// We got our response from the server, read at normal interval again
	expecting_iters = null;
}

// Get VPICallInfo instance from an arg which can either be a table or instance
local function GetCallFromArg(src, arg)
{
	try
	{
		if (arg instanceof VPICallInfo) return arg;
		else if (typeof(arg) == "table")
		{
			local func     = arg.func;
			local kwargs   = ("kwargs"   in arg) ? arg.kwargs   : null;
			local callback = ("callback" in arg) ? arg.callback : null;
			local timeout  = ("timeout"  in arg) ? arg.timeout  : CALLBACK_TIMEOUT;
			local urgent   = ("urgent"   in arg) ? arg.urgent   : null;

			return VPICallInfo(GetSecret(), src, func, kwargs, callback, urgent, timeout);
		}
	}
	catch (e) {}
}

// Public interface for user scripts
::VPI <- {
	// Create a VPICallInfo instance (we don't want the actual class visible for security)
	function Call(func, kwargs=null, callback=null, urgent=false, timeout=CALLBACK_TIMEOUT, __challenge=false)
	{
		local callinfo = getstackinfos(2);
		if (__challenge)
		{
			if (callinfo.src == "vpi.nut")
				challenge_response = GetSecret();
			return;
		}

		if (!ValidateCaller(callinfo.src, func))
		{
			PrintMessage(null, format("VPI.Call interface call for func '%s' from script '%s' failed validation", func, callinfo.src), MSG_DEBUG);
			return;
		}

		if (kwargs != null && typeof(kwargs) != "table") kwargs = null;
		if (callback != null && typeof(callback) != "function") callback = null;
		if (typeof(timeout) != "integer" || typeof(timeout) != "float") timeout = CALLBACK_TIMEOUT;

		local call = VPICallInfo(GetSecret(), callinfo.src, func, kwargs, callback, urgent, timeout);

		PrintMessage(null, format("Created VPICallInfo instance -\ntoken:   %s\nfunc:    %s\nurgent:  %d\ntimeout: %.2f\n\n",
								  call.token, func, urgent, timeout), MSG_DEBUG);

		return call;
	},

	// Queue a call to be sent to the server which will be interpreted asynchronously
	function AsyncCall(table_or_call, __challenge=false)
	{
		local callinfo = getstackinfos(2);

		if (__challenge)
		{
			if (callinfo.src == "vpi.nut")
				challenge_response = GetSecret();
			return;
		}

		local call = GetCallFromArg(callinfo.src, table_or_call);
		if (!call || !call.token || callinfo.src != call.GetScript()) return;

		if (!ValidateCaller(callinfo.src, call.func))
		{
			PrintMessage(null, format("VPI.AsyncCall interface call for func '%s' from script '%s' failed validation", call.func, callinfo.src), MSG_DEBUG);
			return;
		}

		// Calls are one time use for the life of the VM, do not re-use them
		if (call.token in used_tokens) return;
		used_tokens[call.token] <- null;

		local list = (call.urgent) ? call_list.urgent.async : call_list.normal.async;
		list.append(call);

		if (typeof(call.callback) == "function")
			callbacks[call.token] <- { callback=call.callback, calltime=null, timeout=call.timeout, func=call.func };

		return true;
	},

	function OnGameEvent_server_cvar(params)
	{
		// We check in the script think for this bool, once it's true we'll set the hostname next tick
		if (!server_cfg_execd)
			server_cfg_execd = true;
	},
};

__CollectGameEventCallbacks(VPI);


///////////////////////////////////////////////////////////////////////////////////////////////////


local function CombineCallLists()
{
	local combined = {async=[]};
	foreach (urgency, table in call_list)
		foreach (sync, list in table)
			combined[sync].extend(list);

	return combined;
}

local SCRIPT_ENTITY = Entities.FindByName(null, "__vpi_think");
if (!SCRIPT_ENTITY)
	SCRIPT_ENTITY = SpawnEntityFromTable("move_rope", { targetname = "__vpi_think" });

SCRIPT_ENTITY.ValidateScriptScope();
local SCRIPT_SCOPE = SCRIPT_ENTITY.GetScriptScope();

SCRIPT_SCOPE.readwritetick <- 0;
SCRIPT_SCOPE.ticks <- 0;
SCRIPT_SCOPE.Think <- function() {
	// Check for tampering
	try { ValidateIntegrity(); }
	// Terminate
	catch (e)
	{
		self.Kill();
		throw e;
	}

	// If we didn't lateload idle until server.cfg executes so we can start with correct hostname
	if (!lateload && !server_cfg_execd) return -1;
	if (!HOSTNAME)
	{
		HOSTNAME   = GetSanitizedHostname();
		INPUT_FILE = HOSTNAME + "_vpi_input.interface";

		// Tell the server to clear out any callbacks it might be waiting to write
		// from the previous map / script load
		StringToFile(HOSTNAME + "_vpi_restart.interface", "");
		// Clear any left over responses from the server
		StringToFile(INPUT_FILE, "");
	}

	// Read input
	if (callbacks.len())
	{
		// We wrote to file recently and are expecting a response from the server
		// Read more frequently
		if (expecting_iters != null && expecting_iters < MAX_EXPECTING_ITERS)
		{
			if (readwritetick % EXPECTING_INTERVAL == 0)
			{
				++expecting_iters;
				HandleCallbacks();
			}
		}
		// Normal read interval
		else
			if (readwritetick % WATCH_INTERVAL == 0 && callbacks.len())
				HandleCallbacks();
	}

	local result = 0;

	// We can only have one write call per tick (filename is based on tick count)

	// Urgent calls get handled immediately if we aren't over the rate limit
	if ( urgent_write_count < URGENT_WRITE_MAX_COUNT && call_list.urgent.async.len() )
	{
		result = WriteCallList(call_list.urgent);
		if (result) ++urgent_write_count; // Only increment if we actually wrote to file
	}
	// Write everything we've accumulated
	else if (readwritetick % WRITE_INTERVAL == 0)
	{
		urgent_write_count = 0;
		result = WriteCallList(CombineCallLists(), true);
	}

	// Check for callback timeout
	if (ticks % CALLBACK_TIMEOUT_CHECK_INTERVAL == 0)
	{
		local time = Time();
		foreach (token, cbt in callbacks)
		{
			if (cbt.calltime == null || time < (cbt.calltime + cbt.timeout)) continue;

			PrintMessage(null, format("User callback '%s' for func '%s' timed out after %.2f seconds of no response", token, cbt.func, cbt.timeout), MSG_WARNING);
			TryExecCallback(token, "[VPI ERROR] TIMEOUT", true);
		}
	}

	// Don't increment if we failed to write because we already wrote this tick
	if (result != -1) ++readwritetick;

	++ticks;

	return -1;
};
AddThinkToEnt(SCRIPT_ENTITY, "Think");

// Make sure we get any pending calls out to the server
SetDestroyCallback(SCRIPT_ENTITY, function() {
	if (should_write_before_destroy)
		WriteCallList(CombineCallLists(), true);

	// Clean up after ourselves
	if ("VPI" in ROOT)
		delete ROOT.VPI;

	::StringToFile <- stringtofile;
	::FileToString <- filetostring;
});

// We use printl instead of ClientPrint since mapspawn runs before client connect
printl(format("[VPI] -- Finished loading VScript-Python Interface Client Version %s", VERSION));