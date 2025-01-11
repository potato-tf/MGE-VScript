# VScript-Python Interface
# Server

# Made by Mince (STEAM_0:0:41588292)

import os
import datetime
import time
import json
import importlib
import asyncio
import aiomysql
import argparse

import vpi_interfaces

PARSER = argparse.ArgumentParser()
PARSER.add_argument("--host", help="Hostname for database connection", type=str)
PARSER.add_argument("-u", "--user", help="User for database connection", type=str)
PARSER.add_argument("-p", "--port", help="Port for database connection", type=int)
PARSER.add_argument("-db", "--database", help="Database to use", type=str)
PARSER.add_argument("--password", help="Password for database connection", type=str)

args = PARSER.parse_args()

############################################ ENV VARS #############################################
# Server owners modify this section

genv = os.environ.get

# Modify VPI_* with your environment variables if you named them something else
DB_HOST     = args.host     if args.host     else genv("VPI_HOST",      "localhost")
DB_USER     = args.user     if args.user     else genv("VPI_USER",      "user")
DB_PORT	    = args.port     if args.port     else int(genv("VPI_PORT",  3306))
DB_DATABASE	= args.database if args.database else genv("VPI_INTERFACE", "interface")
DB_PASSWORD	= args.password if args.password else genv("VPI_PASSWORD")

SCRIPTDATA_DIR = genv("VPI_SCRIPTDATA_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\scriptdata")

# ----

# Validation
for env in [DB_HOST, DB_USER, DB_PORT, DB_DATABASE, SCRIPTDATA_DIR]:
	assert env is not None

if (DB_PASSWORD is None):
	DB_PASSWORD = input(f"Enter password for {DB_USER}@{DB_HOST}:{DB_PORT} >>> ")
	print()

if (not os.path.exists(SCRIPTDATA_DIR)): raise RuntimeError("SCRIPTDATA_DIR does not exist")

###################################################################################################

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

			table    = {"Calls": info}
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

# Gather and execute interface functions from calls dict
async def ExecCalls():
	tasks	 = [] # Tasks to gather
	contexts = [] # Needed context for parsing task results

	# Execute calls in call chain synchronously
	async def ExecCallChain(call_chain):
		result = None
		for call in call_chain:
			func = call["func"]
			if (not func.startswith("VPI_")): continue
			try:
				func = getattr(vpi_interfaces, func)
				result = await func(call, POOL)
			except:
				continue

		return result

	# Prepare calls
	for host, table in calls.items():
		# Async calls can just be added to tasks directly
		for call in table["async"]:
			func = call["func"]
			if (not func.startswith("VPI_")): continue
			try:
				func = getattr(vpi_interfaces, func)
				tasks.append(func(call, POOL))
				contexts.append({"host":host, "call":call})
			except:
				continue

		# Calls in call chains should be executed synchronously, but still add that to tasks
		for call_chain in table["chain"]:
			if (not len(call_chain)): continue
			last = call_chain[-1]
			tasks.append(ExecCallChain(call_chain))
			contexts.append({"host":host, "call":last})

	# Go
	results = await asyncio.gather(*tasks)

	# Set callbacks (to return results to client later)
	for result, context in zip(results, contexts):
		host  = context["host"]
		call  = context["call"]
		token = call["token"]

		if call["callback"] and token:
			if host not in callbacks:
				callbacks[host] = {}
			callbacks[host][token] = result

# Parse JSON from client output file
def ExtractCallsFromFile(path):
	try:
		with open(path, "r+") as f:
			contents = f.read()

			# StringToFile in VScript ends files with a null byte, which python's json parser doesn't like
			if (contents.endswith("\x00")):
				contents = contents[:-1]

			data = json.loads(contents)

			host = GetHostname(path)
			if (host not in calls):
				calls[host] = {"async":[], "chain":[]}

			calls[host]["async"].extend(data["Calls"]["async"])
			calls[host]["chain"].extend(data["Calls"]["chain"])

	except Exception as e:
		print(f"Invalid input received from client in: \"{path}\"")


POOL = None
async def main():
	global POOL
	POOL = await aiomysql.create_pool(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, port=DB_PORT, db=DB_DATABASE, autocommit=False)
	print(str(POOL) + "\n")

	global calls
	global callbacks

	last_interface_modtime = os.path.getmtime("vpi_interfaces.py")

	# Watchdog loop
	while True:
		time.sleep(0.2)

		# Watch for changes to vpi_interfaces.py and reload the module if necessary
		# This allows server owners to hotload new interface functions without restarting vpi.py
		last_modtime = os.path.getmtime("vpi_interfaces.py")
		if (last_modtime != last_interface_modtime):
			last_interface_modtime = last_modtime
			try:
				importlib.reload(vpi_interfaces)
			except:
				print("INVALID INTERFACE MODULE CODE!")


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

		# Execute interface functions if appropriate and populate callbacks with results
		await ExecCalls()

		# Send results to clients
		WriteCallbacksToFile()

		calls = {}


asyncio.run(main())
