import asyncio
import functools
import re
import git
import os
import tempfile

# Note:
# All interface functions should be decorated with either WrapDB or WrapInterface
# Otherwise any errors that occur will not be handled gracefully and brick the entire program

# Remove problematic characters from strings (return copy)
def SanitizeString(string):
	sanitized = re.sub("[\0\x1a;]", "", string)
	return sanitized

# Sanitize the strings in an object (dict or list) (return copy)
def SanitizeObj(o):
	t = type(o)
	if (t is str): return SanitizeString(o)
	elif (t is not list and t is not dict): return o

	obj = None

	if (t is list):
		obj = []
		for e in o:
			obj.append(SanitizeObj(e))
	elif (t is dict):
		obj = {}
		for key, val in o.items():
			k = SanitizeObj(key)
			v = SanitizeObj(val)
			obj[k] = v
	else:
		obj = o

	return obj

# Make sure we're trying to access a user table that we have access to (is associated with our script.nut name)
# user_<script_name>_<name>
def ValidateUserTable(info, table):
	if (type(table) is not str): raise ValueError

	table = SanitizeString(table)
	table = table.split('_')
	if (len(table) < 3 or table[0] != "user" or table[1] != info["script"][:-4]):
		raise PermissionError
	table = '_'.join(table)

	if (not table or not len(table)): raise ValueError

	return table

# Wrapper for DB interface functions
def WrapDB(func):
	@functools.wraps(func)
	async def inner(info, pool):
		conn   = await pool.acquire()
		cursor = await conn.cursor()

		result = None
		error  = None

		try:
			result = await func(info, cursor)
		except Exception as e:
			# Client expects error responses to start with [VPI ERROR]
			error = f"[VPI ERROR] ({func.__name__}) :: {type(e).__name__}"
			print(error)
			print(e)
		finally:
			await cursor.close()
			if (error is None):
				await conn.commit()
			pool.release(conn)

			if (error is None): return result
			else:				return error

	return inner

# Wrapper for generic interface functions
def WrapInterface(func):
	@functools.wraps(func)
	async def inner(*args, **kwargs):
		result = None
		error  = None

		try:
			result = await func(*args, **kwargs)
		except Exception as e:
			# Client expects this to start with [VPI ERROR]
			error = f"[VPI ERROR] ({func.__name__}) :: {type(e).__name__}"
			print(error)
			print(e)
		finally:
			if (error is None): return result
			else:				return error

	return inner


# Arbitrary SQL execution
# *** DO NOT GIVE USERS ACCESS TO THIS ***
# kwargs:
# 	required:
#		query  (string) -- Query to execute
# 	optional:
#		format (array)  -- Values to insert into query on %s as '<val>'
@WrapDB
async def VPI_DB_RawExecute(info, cursor):
	# While we already defined a whitelist on the client, this is here
	# to ensure this is not exposed unintentionally (e.g. from empty client whitelist)
	source_whitelist = ["vpi.nut"] # Script names go here
	if (not len(source_whitelist)): raise PermissionError
	if (info["script"] not in source_whitelist): raise PermissionError

	kwargs = info["kwargs"]
	query  = kwargs["query"]
	form   = kwargs["format"] if "format" in kwargs else None

	if (type(query) is not str or (form is not None and type(form) is not list)): raise ValueError

	await cursor.execute(query, form)

	return await cursor.fetchall()


########################################## USER FUNCTIONS #########################################
# Admin or server owner will need to create DB tables as needed by users manually
# (or define interface functions for such a purpose themselves, but it is recommended to do it manually for security and DB integrity)

# User tables must follow a specific name format to be accessible by user interface functions: user_<script_name>_<name> (See: ValidateUserTable)
# E.g. user_contracts_players for client user script contracts.nut

# This is to isolate client scripts to only accessing their associated tables
# As a result you may also have tables in the same database that do not start with 'user' for administrative or other purposes


# Simple SELECT statement wrapper for users
# kwargs:
# 	required:
# 		table (string) -- String table name to select from
# 	optional:
# 		columns       (array)      -- Columns to select, * if not provided
# 		filter_column (string)     -- Column to filter results by (WHERE)
# 		filter_op     (string)     -- Operator for value (> < >= <= = != <>)
# 		filter_value  (string|int) -- Value for filter
@WrapDB
async def VPI_DB_UserSelect(info, cursor):
	kwargs = SanitizeObj(info["kwargs"])

	# FROM
	table = ValidateUserTable(info, kwargs["table"])

	# SELECT
	columns = kwargs["columns"] if "columns" in kwargs else []

	# WHERE
	filter_column = kwargs["filter_column"] if "filter_column" in kwargs else None
	filter_op     = kwargs["filter_op"]     if "filter_op"     in kwargs else "="
	filter_value  = kwargs["filter_value"]  if "filter_value"  in kwargs else None

	# Construct query
	s_columns = "*"
	if (type(columns) is list and len(columns)):
		s_columns = ','.join([s for s in columns if type(s) is str])

	s_filter = ""
	# We only care if all of them are specified
	# filter_value can be something other than str (e.g. int 0) so we check against None instead of truthy
	if (filter_column and filter_op and filter_value is not None):
		s_filter = f"WHERE {filter_column} {filter_op} '{filter_value}'"

	await cursor.execute(f"SELECT {s_columns} FROM {table} {s_filter}")

	return await cursor.fetchall()

@WrapDB
async def VPI_MGE_DBInit(info, cursor):
	print("Initializing MGE database...")
	# await cursor.execute("CREATE TABLE IF NOT EXISTS mge_leaderboard (steam_id TEXT PRIMARY KEY, elo INTEGER)")
	await cursor.execute("CREATE TABLE IF NOT EXISTS mge_playerdata (steam_id INTEGER PRIMARY KEY, elo BIGINT, wins BIGINT, losses BIGINT, kills BIGINT, deaths BIGINT, damage_taken BIGINT, damage_dealt BIGINT, airshots BIGINT, market_gardens BIGINT, hoops_scored BIGINT, koth_points_capped BIGINT)")

	return await cursor.fetchall()

@WrapDB
async def VPI_MGE_PopulateLeaderboard(info, cursor):
	await cursor.execute("SELECT * FROM mge_leaderboard")

	return await cursor.fetchall()

@WrapDB
async def VPI_MGE_ReadWritePlayerStats(info, cursor):
    kwargs = info["kwargs"]
    query_mode = kwargs["query_mode"] 
    network_id = kwargs["network_id"]
    default_elo = kwargs["default_elo"] if "default_elo" in kwargs else 1000
    
    if (query_mode == "read" or query_mode == 0):
        print(f"Fetching player data for steam ID {network_id}")
        await cursor.execute(f"SELECT * FROM mge_playerdata WHERE steam_id = {network_id}")
        result = await cursor.fetchall()
        
        # If no record exists, create one with default values
        if not result:
            print(f"No record exists for steam ID {network_id}, adding...")
            await cursor.execute(f"""
                INSERT INTO mge_playerdata (
                    steam_id, elo, wins, losses, kills, deaths, 
                    damage_taken, damage_dealt, airshots, market_gardens,
                    hoops_scored, koth_points_capped
                ) VALUES (
                    {network_id}, {default_elo}, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                )
            """)
            await cursor.execute(f"SELECT * FROM mge_playerdata WHERE steam_id = {network_id}")
            result = await cursor.fetchall()
            
        return result
    elif (query_mode == "write" or query_mode == 1):
        # Build SET clause from stats dictionary
        set_clauses = []
        for key, value in kwargs['stats'].items():
            set_clauses.append(f"{key} = {value}")
        set_clause = ", ".join(set_clauses)
        
        print(f"Updating player data for steam ID {network_id} with stats: {set_clause}")
        await cursor.execute(f"UPDATE mge_playerdata SET {set_clause} WHERE steam_id = {network_id}")
        return await cursor.fetchall()

@WrapInterface
async def VPI_MGE_AutoUpdate(info):
    """
    Git clones a repository and returns a list of changed files
    
    Args:
        kwargs (dict): Dictionary containing:
            repo (str): Repository URL to clone
            branch (str): Branch to clone (optional, defaults to main)
            
    Returns:
        list: List of changed files, or empty list if no changes/error
    """
    try:
        # Get repo URL and branch from kwargs
        kwargs = info["kwargs"]
        repo_url = kwargs["repo"]
        branch = kwargs["branch"] if "branch" in kwargs else "main"
        clone_dir = kwargs["clone_dir"] if "clone_dir" in kwargs else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if not repo_url:
            print("[VPI] Error: No repository URL provided")
            return []
            
        # Create temp directory for clone
        temp_dir = tempfile.mkdtemp()
        
        # Clone the repository using GitPython
        repo = git.Repo.clone_from(repo_url, temp_dir, branch=branch)
        
        # Get list of changed files by comparing with current directory
        changed_files = []
        current_dir = clone_dir
        
        for root, _, files in os.walk(temp_dir):
            for file in files:
                # Skip .git directory
                if ".git" in root:
                    continue
                    
                temp_path = os.path.join(root, file)
                relative_path = os.path.relpath(temp_path, temp_dir)
                current_path = os.path.join(current_dir, relative_path)
                
                # Check if file exists and has different content
                if not os.path.exists(current_path):
                    changed_files.append(relative_path)
                else:
                    with open(temp_path, 'rb') as f1, open(current_path, 'rb') as f2:
                        if f1.read() != f2.read():
                            changed_files.append(relative_path)
        
        return await changed_files
        
    except Exception as e:
        print(f"[VPI] Error during auto-update: {str(e)}")
        return []
    
    finally:
        # Cleanup temp directory
        if 'temp_dir' in locals():
            os.rmdir(temp_dir)
