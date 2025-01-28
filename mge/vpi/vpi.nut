// VScript-Python Interface
// Client

// Made by Mince (STEAM_0:0:41588292)

//////////////////////////////////////////  SCRIPT VARS  //////////////////////////////////////////
// Server owners modify this section

// Token used to verify the identity of the functions we expose to the public to prevent tampering
// If they do not return this secret when prompted the program will abort
// Do not put this token into a variable as error locals traces can give away its value
local function GetSecret() {
	return SECRET_VPI_KEY;
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
	"mge.nut": null,
	"functions.nut": null,
};

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

///////////////////////////////////////////////////////////////////////////////////////////////////

if (GetSecret() == "") throw "[VPI ERROR] Please set your secret token";

local lateload = (Entities.FindByName(null, "bignet") != null);
if (lateload && !split(Convars.GetStr("sv_tags"), ",").find("potato"))
	throw "[VPI ERROR] Late loading is not permitted as it is a security risk, please load in mapspawn.nut"

local ROOT = getroottable();

local stringtofile = ::StringToFile;
local filetostring = ::FileToString;

local function ValidateIntegrity()
{
	try
	{
		if (PROTECTED_FILE_FUNCTIONS)
		{
			if (::StringToFile(null, null, true) != GetSecret()) throw null;
			if (::FileToString(null, true) != GetSecret()) throw null;
		}

		if ("VPI" in ROOT)
		{
			if (VPI.Call(null, null, null, null, true) != GetSecret()) throw null;
			if (VPI.AsyncCall(null, true) != GetSecret()) throw null;
			if (VPI.ChainCall(null, null, null, true) != GetSecret()) throw null;
		}
	}
	catch (e) { throw "[VPI ERROR] *** POSSIBLE VPI FUNCTION TAMPERING, ABORTING ***" }
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
			if (callinfo.src != "vpi.nut") return;
			else return GetSecret();
		}

		if (typeof(file) != "string") return;
		if (typeof(str)  != "string") return;
		if (!ValidateFileCaller(callinfo.src, file)) return;

		stringtofile(file, str);
	};

	::FileToString <- function(file, __challenge=false) {
		local callinfo = getstackinfos(2);
		if (__challenge)
		{
			if (callinfo.src != "vpi.nut") return;
			else return GetSecret();
		}

		if (typeof(file) != "string") return;
		if (!ValidateFileCaller(callinfo.src, file)) return;

		return filetostring(file);
	};
}


// Storage for interface calls so we can write on an interval
local call_list = {
	normal = {
		async=[],
		chain=[],
	},
	urgent = {
		async=[],
		chain=[],
	},
};

local callbacks   = {};
local used_tokens = {};

// Strip hostname of characters other than [a-z0-9_]
local hostname = Convars.GetStr("hostname").tolower();
try
{
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
	hostname = str;
}
catch (e) {}

local INPUT_FILE = hostname + "_vpi_input.interface";

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


//////////////////////////////////////////////  JSON  /////////////////////////////////////////////
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
		obj = token.slice(1, -1);
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

	GetScript = null;

	constructor(secret, s=null, f=null, k=null, c=null, u=null)
	{
		if (secret != GetSecret())
			throw "[VPI ERROR] *** POSSIBLE VPI FUNCTION TAMPERING, ABORTING ***";

		token  = UniqueString();

		// Squirrel has no private members or way to detect instance modification
		// so we provide closure getters instead for sensitive data that should not be tampered with
		local script = s;
		GetScript    = function() { return script };

		func        = f;
		urgent      = u;
		callback    = c;
		kwargs      = k;
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
		"chain": [
			[{...}, {...}],
			[{...}]
		]
	}
*/
local function EncodeOutput(list)
{
	// This structure gets turned into JSON
	local table = { "Calls":{"async":[], "chain":[]} };

	// We don't want every member of VPICallInfo to be sent to server
	// Make a table of only what's needed
	local function GetCallTable(call)
	{
		local t = {};

		foreach (k, v in call.getclass())
		{
			if (typeof(v) == "function" && k != "callback") continue;
			if (k == "urgent") continue;

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

	foreach (calls in list.chain)
	{
		local list = [];
		foreach (call in calls)
			list.append(GetCallTable(call));

		table.Calls.chain.append(list);
	}

	return JSON.Encode(table);
}

// Write interface call to file as JSON
local last_write_time = null;
local function WriteCallList(list, combined=false)
{
	if (!list.async.len() && !list.chain.len()) return 0;

	// Our write file name's uniqueness is based on tick count
	// Don't write if we already wrote this tick
	local time = Time();
	if (time <= last_write_time) return -1;

	// Reading files seems to be about 3x as expensive as writing
	// If we used a single output file we would have to read to see if we can write,
	// so the simple solution is to base file name off timestamp and tick count and let the server handle the hard work
	local output_file = format("%s_vpi_%d_%d_output.interface", hostname, Timestamp(), time / 0.015);

	StringToFile(output_file, EncodeOutput(list));

	// Clear calls
	if (combined)
	{
		call_list = {
			normal = {
				async=[],
				chain=[],
			},
			urgent = {
				async=[],
				chain=[],
			},
		};
	}
	else
	{
		list.async = [];
		list.chain = [];
	}

	last_write_time = time;

	// Start watching for a response from the server more frequently
	expecting_iters = 0;

	return 1;
}

// Read callbacks results from the server
local function HandleCallbacks()
{
	// Don't bother reading if we don't have anything to look for
	if (!callbacks.len()) return;

	// The good thing about a single input file is that it seems VScript stores the
	// modify time of the file and skips trying to read it if it hasn't changed
	// As a result reading an unchanged file is much faster, and we can have a relatively
	// small WATCH_INTERVAL without much complication
	local contents = FileToString(INPUT_FILE);

	if (!contents || contents == "") return;
	try
	{
		local table = JSON.Decode(contents);

		// Look to see if any of our callbacks have results
		local calls = table.Calls;
		foreach (token, data in calls)
		{
			if (!(token in callbacks)) continue;

			// Peek at data and print if error
			local error = false;
			if (typeof(data) == "string" && startswith(data, "[VPI ERROR]"))
			{
				printl(data);
				data  = null;
				error = true;
			}

			try { callbacks[token](data, error); }
			catch (e) {
				printl(format("[VPI ERROR] Callback %s failed with error: %s", callbacks[token].tostring(), e));
			}

			delete callbacks[token];
		}
	}
	catch (e)
	{
		printl("[VPI] INVALID INPUT RECEIVED FROM SERVER");
	}

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
			local func = arg.func;
			local kwargs   = ("kwargs" in arg)   ? arg.kwargs   : null;
			local callback = ("callback" in arg) ? arg.callback : null;
			local urgent   = ("urgent" in arg)   ? arg.urgent   : null;

			return VPICallInfo(GetSecret(), src, func, kwargs, callback, urgent);
		}
	}
	catch (e) {}
}

// Public interface for user scripts
::VPI <- {
	// Create a VPICallInfo instance (we don't want the actual class visible for security)
	function Call(func, kwargs=null, callback=null, urgent=false, __challenge=false)
	{
		local callinfo = getstackinfos(2);
		if (__challenge)
		{
			if (callinfo.src != "vpi.nut") return;
			else return GetSecret();
		}

		if (!ValidateCaller(callinfo.src, func)) return;
		return VPICallInfo(GetSecret(), callinfo.src, func, kwargs, callback, urgent);
	},

	// Queue a call to be sent to the server which will be interpreted asynchronously
	function AsyncCall(table_or_call, __challenge=false)
	{
		local callinfo = getstackinfos(2);
		if (__challenge)
		{
			if (callinfo.src != "vpi.nut") return;
			else return GetSecret();
		}

		local call = GetCallFromArg(callinfo.src, table_or_call);
		if (!call || !call.token || callinfo.src != call.GetScript()) return;

		if (!ValidateCaller(callinfo.src, call.func)) return;

		// Calls are one time use for the life of the VM, do not re-use them
		if (call.token in used_tokens) return;
		used_tokens[call.token] <- null;

		local list = (call.urgent) ? call_list.urgent.async : call_list.normal.async;
		list.append(call);

		if (typeof(call.callback) == "function")
			callbacks[call.token] <- call.callback;

		return true;
	},

	// Queue a list of calls to be sent to the server which will be interpreted synchronously
	function ChainCall(calls, callback=null, urgent=false, __challenge=false)
	{
		local callinfo = getstackinfos(2);
		if (__challenge)
		{
			if (callinfo.src != "vpi.nut") return;
			else return GetSecret();
		}

		if (typeof(calls) != "array" || !calls.len()) return;

		local new_calls = [];
		foreach (el in calls)
		{
			local call = GetCallFromArg(callinfo.src, el);
			if (!call || !call.token || callinfo.src != call.GetScript()) return;

			if (!ValidateCaller(callinfo.src, call.func)) return;

			// Calls are one time use for the life of the VM, do not re-use them
			if (call.token in used_tokens) return;
			used_tokens[call.token] <- null;

			// We handle these a few lines down
			call.token    = null;
			call.callback = false;

			new_calls.append(call);
		}

		local list = (urgent) ? call_list.urgent.chain : call_list.normal.chain;
		list.append(new_calls);

		// Generate a token for the whole chain call if we need one
		local token;
		if (typeof(callback) == "function")
		{
			token = UniqueString();
			callbacks[token] <- callback;
		}

		// The server uses the last call's info to determine if it needs to send back results
		local last = new_calls.top();
		last.token    = token;
		last.callback = (last.token) ? true : false;

		// Consume the input call list
		calls = [];

		return true;
	},
};


///////////////////////////////////////////////////////////////////////////////////////////////////


local function CombineCallLists()
{
	local combined = {async=[], chain=[]};
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

SCRIPT_SCOPE.tickcount <- 0;
SCRIPT_SCOPE.Think <- function() {
	// Check for tampering
	try { ValidateIntegrity(); }
	// Terminate
	catch (e)
	{
		self.Kill();
		throw e;
	}

	// Read input
	if (callbacks.len())
	{
		// We wrote to file recently and are expecting a response from the server
		// Read more frequently
		if (expecting_iters != null && expecting_iters < MAX_EXPECTING_ITERS)
		{
			if (tickcount % EXPECTING_INTERVAL == 0)
			{
				++expecting_iters;
				HandleCallbacks();
			}
		}
		// Normal read interval
		else
			if (tickcount % WATCH_INTERVAL == 0 && callbacks.len())
				HandleCallbacks();
	}

	local result = 0;

	// We can only have one write call per tick (filename is based on tick count)

	// Urgent calls get handled immediately if we aren't over the rate limit
	if ( urgent_write_count < URGENT_WRITE_MAX_COUNT &&
	   ( call_list.urgent.async.len() || call_list.urgent.chain.len()) )
	{
		result = WriteCallList(call_list.urgent);
		if (result) ++urgent_write_count; // Only increment if we actually wrote to file
	}
	// Write everything we've accumulated
	else if (tickcount % WRITE_INTERVAL == 0)
	{
		urgent_write_count = 0;
		result = WriteCallList(CombineCallLists(), true);
	}

	// Don't increment if we failed to write because we already wrote this tick
	if (result != -1) ++tickcount;

	return -1;
};
AddThinkToEnt(SCRIPT_ENTITY, "Think");

// Make sure we get any pending calls out to the server
SetDestroyCallback(SCRIPT_ENTITY, function() {
	WriteCallList(CombineCallLists(), true);

	// Clean up after ourselves
	if ("VPI" in ROOT)
		delete ROOT.VPI;

	::StringToFile <- stringtofile;
	::FileToString <- filetostring;
});

// Tell the server to clear out any callbacks it might be waiting to write
// from the previous map / script load
StringToFile(hostname + "_vpi_restart.interface", "");