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


# Grab the hostname from a path
def GetHostname(path):
	host = os.path.basename(path) # Remove the path to the file
	sep	 = host.find("_vpi_")	  # The client separates hostname from the rest of the filename with _vpi_

	if (sep < 0): return
	return host[:sep]

# Write responses from interface functions to file
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

			table	 = {"Calls": info}
			overflow = {}

			# Find the number of responses we can write fitting into the max VScript readable file size of 16kb
			string = None
			while (True):
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
				LOGGER.info(f"Executing call: [{host}] {func}")
				func = getattr(vpi_interfaces, func)
				result = await func(call, POOL)
			except:
				LOGGER.error(f"Error executing call: [{host}] {func}")

		return result

	# Prepare calls
	for host, table in calls.items():

		for call in table["async"]:

			func = call["func"]
			if (not func.startswith("VPI_")): continue

			try:
				LOGGER.info(f"Preparing call: [{host}] {func}")
				func = getattr(vpi_interfaces, func)
				tasks.append( func(call, POOL) )
				contexts.append({"host":host, "call":call})

			except Exception as e:
				LOGGER.error(e)

		LOGGER.info(f"Prepared {len(tasks)} calls")

		for call_chain in table["chain"]:

			LOGGER.info(f"Preparing call chain: [{host}] {len(call_chain)} calls")

			if (not len(call_chain)): continue

			last = call_chain[-1]
			tasks.append(ExecCallChain(call_chain))
			contexts.append({"host":host, "call":last})

	# Go
	LOGGER.info(f"Tasks: {tasks}")
	results = await asyncio.gather(*tasks, return_exceptions=True)
	LOGGER.info(f"Results: {results}")

	# Set callbacks
	for result, context in zip(results, contexts):

		host  = context["host"]
		call  = context["call"]
		token = call["token"]

		LOGGER.info(f"Setting callback: [{host}] {token}")
		if call["callback"] and token:
			if host not in callbacks:
				callbacks[host] = {}
			callbacks[host][token] = result

def ExtractCallsFromFile(path):

	try:

		with open(path, "r+") as f:

			LOGGER.info(f"Extracting calls from {path}")
			contents = f.read()

			if (contents.endswith("\x00")):
				contents = contents[:-1]

			data = json.loads(contents)

			host = GetHostname(path)
			if (host not in calls):
				calls[host] = {"async":[], "chain":[]}

			calls[host]["async"].extend(data["Calls"]["async"])
			calls[host]["chain"].extend(data["Calls"]["chain"])

	except Exception as e:
		LOGGER.error(f"Invalid input received from client in: \"{path}\"")

async def main():

	LOGGER.info("VScript-Python Interface Server version %s startup", VERSION)

	global calls
	global callbacks

	last_interface_modtime = os.path.getmtime("vpi_interfaces.py")

	# Watchdog loop
	while True:
		time.sleep(0.2)

		# Watch for changes to vpi_interfaces and reload the module if necessary
		last_modtime = os.path.getmtime("vpi_interfaces.py")
		if (last_modtime != last_interface_modtime):
			os._exit(0)

		files = os.listdir(SCRIPTDATA_DIR)
		LOGGER.info(f"Found {len(files)} files in {SCRIPTDATA_DIR}")

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
		LOGGER.info(f"Writing callbacks to files")
		WriteCallbacksToFile()

		calls = {}


loop.run_until_complete(main())