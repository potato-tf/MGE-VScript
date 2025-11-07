# VScript-Python Interface
# Version 1.0.0
# Server

# Made by Mince (STEAM_0:0:41588292)
# And modified by Braindawg (STEAM_0:0:14133131)

print("VScript-Python Interface (MGE) \n")
import os
import json, time, math, asyncio, importlib, datetime
from itertools import islice
from random import randint
import vpi_interfaces
from vpi_config import SECRET, BYPASS_SECRET, SCRIPTDATA_DIR, LOGGER, VERSION, POOL, DB_SUPPORT

###################################################################################################

loop = asyncio.new_event_loop()

# {
#	  "<host>": {
#		  "async": [ {...}, {...} ],
#		  "chain": [
#			  [ {...}, {...} ],
#			  []
#		  ]
#	  }
# }
calls = {}

# {
#	  "<host>": {
#		  "<token>": <response>
#	  }
# }
callbacks = {}


# Handle some types not handled by the json module
class Encoder(json.JSONEncoder):
	def default(self, o):
		if isinstance(o, bytes):
			if (o == b"\x00"):	 return False
			elif (o == b"\x01"): return True
			else:				 return o.decode("ascii")
		elif isinstance(o, (datetime.date, datetime.datetime, datetime.time)):
			return o.isoformat()
		elif isinstance(o, datetime.timedelta):
			return str(o)
		else:
			return super().default(o)

# Emulate behavior of modulus in C / Squirrel
def mod(a, b):
	return (a % b + b) % b

# Simple encryption algorithm based on timestamp, time, and a key
def Encrypt(string):
	timestamp = int(round(time.time()))

	# Add a bit of randomness
	t = mod(timestamp, 1024)        # Sin doesn't give good output for large values, keep things small
	f = math.fabs(math.sin(16 * t)) # Give our time a bit of variance
	h = math.floor(f * 127 + 0.5)   # Get a hash value from 0 - 127 (really this could be any number though)

	# Initialization vector to provide true randomness since we always use the same key
	# Without this the output tends to repeat quite often
	iv = ""
	for ch in string:
		iv += chr(randint(35, 126))

	enc = ""
	for i, ch in enumerate(string):
		key_index = mod(i, len(SECRET)) # Corresponding index in our key, loop if necessary
		key_char  = SECRET[key_index]

		# Encode the character; shifted using hash and key_char; limited to 32 - 127 ASCII
		enc += chr(32 + mod(ord(ch) + h + ord(iv[i]) + ord(key_char), 95))

	return {
		"enc"       : enc,
		"iv"        : iv,
		"timestamp" : timestamp,
		"ticks"     : 0,
	}

# Decryption
def Decrypt(enc, iv, timestamp, ticks):
	t = mod(timestamp + ticks, 1024)
	f = math.fabs(math.sin(16 * t))
	h = math.floor(f * 127 + 0.5)

	dec = ""
	for i, ch in enumerate(enc):
		key_index = mod(i, len(SECRET))
		key_char  = SECRET[key_index]

		dec_char = mod(ord(ch) - 32 - h - ord(iv[i]) - ord(key_char), 95)
		if (dec_char < 32):
			dec_char += 95 * math.ceil((32 - dec_char) / 95.0)
		dec += chr(dec_char)

	return dec

# Grab the hostname from a path
def GetHostname(path):
	host = os.path.basename(path) # Remove the path to the file
	sep	 = host.find("_vpi_")	  # The client separates hostname from the rest of the filename with _vpi_

	if (sep < 0): return
	return host[:sep]

# Write responses from interface functions to file
MAX_FILE_SIZE = 16000
def WriteCallbacksToFile():
	# Hosts to delete
	delete = []

	for host, info in callbacks.items():
		path = os.path.join(SCRIPTDATA_DIR, f"{host}_vpi_input.interface")
		with open(path, "a+") as f:
			# "a+" file mode seeks to the end of the file, need to go back to the beginning
			f.seek(0)
			# and then read
			contents = f.read()

			# Client hasn't handled our previous write, don't overwrite
			if (len(contents) > 0 and not contents.isspace() and contents != "\x00"):
				continue

			# Wipe the file
			f.truncate(0)

			table = {"Calls": info}
			table["Identity"] = Encrypt(SECRET)

			string   = json.dumps(table, cls=Encoder)
			overflow = {}

			if (len(string) >= MAX_FILE_SIZE):
				# Sort responses by size
				cbs = [[token, response] for token, response in info.items()]
				for l in cbs: l.append(len(json.dumps(l)))
				cbs.sort(key=lambda l: l[2])

				# Loop through and get as many as can fit
				totalsize = 0
				fits = {}
				for l in cbs:
					token, response, size = l

					# Client expects error responses to start with [VPI ERROR]
					if (size >= MAX_FILE_SIZE):
						response = "[VPI ERROR] (token) :: Response size exceeds maximum"
						size = len(json.dumps(response, cls=Encoder))

					if (totalsize + size < MAX_FILE_SIZE):
						totalsize   += size
						fits[token] =  response
					else:
						overflow[token] = response

				table["Calls"] = fits
				string = json.dumps(table, cls=Encoder)
				strlen = len(string)

				# Half what we have if it's too much
				i = table["Calls"]
				if (strlen >= 16000):
					it = iter(i.items())

					halflen = len(i) // 2

					# This means we have a single chungus response larger than our max write size
					if (halflen == 0): raise RuntimeError

					half_1 = dict(islice(it, halflen))
					half_2 = dict(it)

					table["Calls"] = half_1
					overflow.update(**half_2)
				else:
					break

			# Store what we can't fit from our buffer back into callbacks
			if (len(overflow)):
				callbacks[host] = overflow
			# Exhausted all callbacks
			else:
				delete.append(host)

			if (not len(string)): continue

			LOGGER.info(f"WriteCallbacksToFile: [{host}] {len(string)} bytes")
			f.write(string)

	for host in delete:
		del callbacks[host]


async def ExecCalls():
	tasks	 = []
	contexts = []

	async def ExecCallChain(call_chain):
		result = None
		for call in call_chain:
			func = call["func"]
			if (not func.startswith("VPI_")): continue
			try:
				func = getattr(vpi_interfaces, func)
				result = await func(call, POOL)
			except Exception as e:
				LOGGER.error(f"Error in ExecCallChain: {e}")
				continue

		LOGGER.info(f"ExecCallChain: [{host}] {func}")
		return result

	# Prepare calls
	for host, table in calls.items():
		for call in table["async"]:
			func = call["func"]
			LOGGER.info(f"ExecCalls: [{host}] {func}")
			if (not func.startswith("VPI_")): continue
			try:
				func = getattr(vpi_interfaces, func)
				tasks.append(func(call, POOL))
				contexts.append({"host":host, "call":call})
			except Exception as e:
				LOGGER.error(f"Error in ExecCalls: {e}")

		for call_chain in table["chain"]:
			if (not len(call_chain)): continue
			last = call_chain[-1]
			tasks.append(ExecCallChain(call_chain))
			contexts.append({"host":host, "call":last})

	# Go
	results = await asyncio.gather(*tasks)

	# Set callbacks
	for result, context in zip(results, contexts):
		host  = context["host"]
		call  = context["call"]
		token = call["token"]

		if call["callback"] and token:
			if host not in callbacks:
				callbacks[host] = {}
			callbacks[host][token] = result

def ExtractCallsFromFile(path):

	# try:
	with open(path, "r+") as f:
		contents = f.read()
		if (contents.endswith("\x00")):
			contents = contents[:-1]

		data = json.loads(contents)

		ident = Decrypt(**data["Identity"])
		if (ident != SECRET and not BYPASS_SECRET):
			LOGGER.error(f"Error in ExtractCallsFromFile: Invalid identification in file: {path}; ignoring")
			return

		host = GetHostname(path)
		if (host not in calls):
			calls[host] = {"async":[], "chain":[]}

		calls[host]["async"].extend(data["Calls"]["async"])
		calls[host]["chain"].extend(data["Calls"]["chain"])

	# except Exception as e:
		# LOGGER.error(f"Invalid input received from client in: \"{path}\"")

async def main():

	LOGGER.info("VScript-Python Interface Server version %s startup", VERSION)

	global calls
	global callbacks

	last_interface_modtime = os.path.getmtime("vpi_interfaces.py")

	# Watchdog loop
	while True:

		time.sleep(0.2)
		current_time = time.time()

		# Watch for changes to vpi_interfaces and reload the module if necessary
		last_modtime = os.path.getmtime("vpi_interfaces.py")
		if (last_modtime != last_interface_modtime):
			# quit()	# restart on update
			os._exit(0)
			# last_interface_modtime = last_modtime
			# try:
			# 	importlib.reload(vpi_interfaces)
			# 	LOGGER.info("Successfully hot-loaded changes to vpi_interfaces.py")
			# except:
			# 	LOGGER.error("Failed to hot-load changes to vpi_interfaces.py due to error:", exc_info=True)



		files = os.listdir(SCRIPTDATA_DIR)

		for file in files:
			path = os.path.join(SCRIPTDATA_DIR, file)
			host = GetHostname(path)
			if (not host): continue

			# Client tells us our callbacks list is outdated (e.g. map change)
			if (file.endswith("_restart.interface")):
				if (host in callbacks): del callbacks[host]
				os.remove(path)
			# Grab info from clients
			elif (file.endswith("_output.interface")):
				ExtractCallsFromFile(path)
				os.remove(path)

		await ExecCalls()

		# Send to clients
		WriteCallbacksToFile()

		calls = {}


loop.run_until_complete(main())