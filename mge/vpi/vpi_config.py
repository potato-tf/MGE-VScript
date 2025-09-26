import os
import sys
import logging
from   logging.handlers import TimedRotatingFileHandler

genv = os.environ.get

USE_COLOR = True
try:
	from colorama import Fore, Back, Style
except:
	USE_COLOR = False

# Environment Variables:
# VPI_SCRIPTDATA_DIR - tf/scriptdata directory
# If MySQL Database:
#	DB_HOST         - hostname
#	DB_USER         - user
#	DB_PORT         - port
#	DB_DATABASE     - database name
#	DB_PASSWORD     - password

# If you don't want to set environment variables feel free to simply set the default values below instead
# They're mainly for when you host your source code publicly

# ====================================================================================================================== #

# This should be the same token returned in the GetSecret function in vpi.nut
# It's used to identify files created by VPI
SECRET = r""
BYPASS_SECRET = False #do not set this to true unless you know what you're doing
if (not SECRET and not BYPASS_SECRET):
	raise RuntimeError("Please set your secret token")

def find_env_vars(var = None, default = "", ignore_env = True):
	env_vars = {}
	if os.path.exists("env") and not ignore_env:
		with open("env", "r") as f:
			for line in f:
				if "=" in line and (var is None or line.startswith(var)):
					key, value = line.split("=")
					env_vars[r""+key.strip()] = r""+value.strip().removesuffix('"')
					if var is not None: break

	elif var is not None:
		env_vars[r""+var] = r""+genv(var, default)
	return env_vars

env = find_env_vars()
_dir = os.path.abspath(__file__)
SCRIPTDATA_DIR = os.path.normpath(os.path.join(_dir, env["SCRIPTDATA_DIR"]))
print(SCRIPTDATA_DIR)
if (not os.path.exists(SCRIPTDATA_DIR)): raise RuntimeError(f"{SCRIPTDATA_DIR} does not exist")

# Are you going to be interacting with a database?
DB_SUPPORT = True

# Default values if no env vars or env file is found
DB_TYPE = "mysql"
DB_HOST = "localhost"
DB_USER = "root"
DB_PORT = 3306
DB_DATABASE = "mge"
DB_PASSWORD = ""
DB_LITE = "sqlite_filename.db"
STEAM_API_KEY = "000000"
WEB_API_KEY = "000000"

aiomysql = None
aiosqlite = None

if DB_SUPPORT:
	DB_TYPE		  = env["DB_TYPE"]
	DB_HOST       = env["DB_HOST"]
	DB_USER       = env["DB_USER"]
	DB_PORT	      = int(env["DB_PORT"])
	DB_DATABASE	  = env["DB_DATABASE"]
	DB_PASSWORD	  = env["DB_PASSWORD"]
	STEAM_API_KEY = env["STEAM_API_KEY"]
	WEB_API_KEY   = env["WEB_API_KEY"]

	if DB_TYPE != "sqlite":
		import aiomysql as _aiomysql
		aiomysql = _aiomysql
	else:
		DB_LITE = env["DB_LITE"]
		import aiosqlite as _aiosqlite
		aiosqlite = _aiosqlite

# Get a connection to the current database
async def _GetDBConnection():
	if (DB_TYPE == "mysql"):
		return await DB.acquire() # Pool
	elif (DB_TYPE == "sqlite"):
		return DB # Connection
	else:
		return

DB = None
# Ping the database to see if we're connected
async def PingDB():
	try:
		conn = await _GetDBConnection()
		try:
			cursor = await conn.cursor()
			await cursor.execute("SELECT 1")
			return True
		except:
			return False
		finally:
			if (DB_TYPE == "mysql"):
				DB.release(conn)
	except:
		return False

if (DB_SUPPORT):
	DB = None

	DB_TYPE = DB_TYPE.lower()
	if (DB_TYPE == "mysql"):

		# Validation
		for db_env in [DB_HOST, DB_USER, DB_PORT, DB_DATABASE, SCRIPTDATA_DIR]:
			assert db_env is not None

		if (DB_PASSWORD is None):
			DB_PASSWORD = input(f"Enter password for {DB_USER}@{DB_HOST}:{DB_PORT} >>> ")
			print()

	elif (DB_TYPE == "sqlite"):

        # Put the path to your .db file here
		DB_LITE = "test.db"

	else:
		raise RuntimeError("DB_TYPE must be either 'mysql' or 'sqlite'")

# ====================================================================================================================== #

# Logging

# Should we send messages to console?
LOG_USE_CONSOLE = True
# Should we send messages to log files?
LOG_USE_FILE    = True

# Levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
# What min level of messages should reach the console?
LOG_MIN_CONSOLE_LEVEL = logging.INFO
# What min level of messages should reach our log files?
LOG_MIN_FILE_LEVEL    = logging.WARNING

# ====================================================================================================================== #

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

FILE_FORMATTER = logging.Formatter("{asctime} - {levelname} - {message}", style="{")
if (USE_COLOR):
	class ColoredConsoleFormatter(logging.Formatter):
		def __init__(self, fmt, style="%", *args, **kwargs):
			super().__init__(fmt, *args, style=style, **kwargs)
			self.fmt   = fmt
			self.style = style
			self.FORMATS = {
				logging.DEBUG:    Back.LIGHTBLACK_EX + Fore.WHITE,
				logging.WARNING:  Back.BLACK         + Fore.YELLOW,
				logging.ERROR:    Back.BLACK         + Fore.RED,
				logging.CRITICAL: Back.RED           + Fore.WHITE,
			}

		def format(self, record):
			fmt = self.FORMATS[record.levelno] if record.levelno in self.FORMATS else ""
			fmt += self.fmt + Style.RESET_ALL
			return logging.Formatter(fmt, style=self.style).format(record)

	CONSOLE_FORMATTER = ColoredConsoleFormatter("{asctime} - {levelname} - {message}", style="{")
else:
	CONSOLE_FORMATTER = FILE_FORMATTER

CONSOLE_HANDLER = logging.StreamHandler(stream=sys.stdout)
CONSOLE_HANDLER.setLevel(LOG_MIN_CONSOLE_LEVEL)
CONSOLE_HANDLER.setFormatter(CONSOLE_FORMATTER)
CONSOLE_HANDLER.addFilter(lambda _: LOG_USE_CONSOLE)
LOGGER.addHandler(CONSOLE_HANDLER)

FILE_HANDLER = TimedRotatingFileHandler("vpi.log", when="W0", encoding="utf-8", backupCount=5, delay=True)
FILE_HANDLER.setLevel(LOG_MIN_FILE_LEVEL)
FILE_HANDLER.setFormatter(FILE_FORMATTER)
FILE_HANDLER.addFilter(lambda _: LOG_USE_FILE)
LOGGER.addHandler(FILE_HANDLER)
