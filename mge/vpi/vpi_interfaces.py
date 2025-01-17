import asyncio
import functools
import re
import git
import os
import tempfile
import shutil

os.system('')  # enables ansi escape characters in terminal

COLOR = {
    'CYAN': '\033[96m',
    'HEADER': '\033[95m',
    'GREEN2': '\033[32m',
    'YELLOW': '\033[93m',
    'GREEN': '\033[92m',
    'RED': '\033[91m',
    "ENDC": '\033[0m',
}
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

player_data_columns = "steam_id, elo, wins, losses, kills, deaths, damage_taken, damage_dealt, airshots, market_gardens, hoops_scored, koth_points_capped"
@WrapDB
async def VPI_MGE_DBInit(info, cursor):
	print(COLOR['HEADER'], "Initializing MGE database...", COLOR['ENDC'])
	# await cursor.execute("CREATE TABLE IF NOT EXISTS mge_leaderboard (steam_id TEXT PRIMARY KEY, elo INTEGER)")

	try:
		await cursor.execute(f"SELECT {player_data_columns} FROM mge_playerdata LIMIT 1")
	except Exception as e:
		print(COLOR['YELLOW'], "No mge_playerdata table found, creating...", COLOR['ENDC'])
		await cursor.execute("""CREATE TABLE IF NOT EXISTS mge_playerdata (
			steam_id INTEGER PRIMARY KEY, 
			elo BIGINT, 
			wins BIGINT, 
			losses BIGINT, 
			kills BIGINT, 
			deaths BIGINT, 
			damage_taken BIGINT, 
			damage_dealt BIGINT, 
			airshots BIGINT, 
			market_gardens BIGINT, 
			hoops_scored BIGINT, 
			koth_points_capped BIGINT)"""
		)
	finally:
		print(COLOR['GREEN'], "MGE database initialized, check server console for '[VPI]: Database initialized successfully'", COLOR['ENDC'])
	return await cursor.fetchall()

DEFAULT_MAX_LEADERBOARD_ENTRIES = 25
@WrapDB
async def VPI_MGE_PopulateLeaderboard(info, cursor):
	kwargs = info["kwargs"]
	order_filter = kwargs["order_filter"] if "order_filter" in kwargs else "elo"
	max_leaderboard_entries = kwargs["max_leaderboard_entries"] if "max_leaderboard_entries" in kwargs else DEFAULT_MAX_LEADERBOARD_ENTRIES
	await cursor.execute(f"SELECT steam_id FROM mge_playerdata ORDER BY {order_filter} DESC LIMIT {max_leaderboard_entries}")

	return await cursor.fetchall()

default_zeroes = ", ".join(["0"] * (len(player_data_columns.split(",")) - 2))
@WrapDB
async def VPI_MGE_ReadWritePlayerStats(info, cursor):
    kwargs = info["kwargs"]
    query_mode = kwargs["query_mode"] 
    network_id = kwargs["network_id"]
    default_elo = kwargs["default_elo"] if "default_elo" in kwargs else 1000
    
    if (query_mode == "read" or query_mode == 0):
        print(COLOR['CYAN'], f"Fetching player data for steam ID {network_id}", COLOR['ENDC'])
        await cursor.execute(f"SELECT {player_data_columns} FROM mge_playerdata WHERE steam_id = {network_id}")
        result = await cursor.fetchall()
        
        # If no record exists, create one with default values
        if not result:
            print(COLOR['YELLOW'], f"No record exists for steam ID {network_id}, adding...", COLOR['ENDC'])
            await cursor.execute(f"INSERT INTO mge_playerdata ({player_data_columns}) VALUES ({network_id}, {default_elo}, {default_zeroes})")
            await cursor.execute(f"SELECT {player_data_columns} FROM mge_playerdata WHERE steam_id = {network_id}")
            result = await cursor.fetchall()
            
        return result
    elif (query_mode == "write" or query_mode == 1):
        # Build SET clause from stats dictionary
        set_clauses = []
        for key, value in kwargs['stats'].items():
            set_clauses.append(f"{key} = {value}")
        set_clause = ", ".join(set_clauses)
        
        print(COLOR['CYAN'], f"Updating player data for steam ID {network_id} with stats: {set_clause}", COLOR['ENDC'])
        await cursor.execute(f"UPDATE mge_playerdata SET {set_clause} WHERE steam_id = {network_id}")
        return await cursor.fetchall()
    
banned_files = [".gitignore", ".git", ".vscode", "README.md", "mge_windows_setup.bat", "config.nut"]
@WrapInterface
async def VPI_MGE_AutoUpdate(info, test=False):
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
            print(COLOR['RED'], "[VPI] Error: No repository URL provided", COLOR['ENDC'])
            return []
            
        # Create temp directory for clone
        temp_dir = tempfile.mkdtemp()
        
        print(COLOR['GREEN2'], f"Cloning repository {repo_url} into {temp_dir}", COLOR['ENDC'])
        # Clone the repository using GitPython
        repo = git.Repo.clone_from(repo_url, temp_dir, branch=branch)
        
        # Get list of changed files by comparing with current directory
        changed_files = []
        current_dir = clone_dir
        
        for root, _, files in os.walk(temp_dir):
            for file in files:
                # Skip .git directory
                if any(banned in file for banned in banned_files) or any(banned in root for banned in banned_files):
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
	
        print(COLOR['GREEN'], f"Changed files: {changed_files}", COLOR['ENDC'])
        
        #move changed files to the clone directory
        for file in changed_files:
            shutil.move(os.path.join(temp_dir, file), os.path.join(clone_dir, file))
        

        return changed_files
        
    except Exception as e:
        print(COLOR['RED'], f"[VPI] Error during auto-update: {str(e)}", COLOR['ENDC'])
        return []
    
    finally:
        # Cleanup temp directory
        if 'temp_dir' in locals():
            try:
                shutil.rmtree(temp_dir, ignore_errors=True)
            except Exception as e:
                print(COLOR['YELLOW'], f"Warning: Could not clean up temp directory {temp_dir}: {str(e)}", COLOR['ENDC'])

@WrapDB
async def VPI_MGE_UpdateServerData(info, cursor):
    kwargs = info["kwargs"]
    server_data = kwargs["server_data"]
    await cursor.execute("UPDATE mge_serverdata SET server_data = %s", (server_data,))
    return await cursor.fetchall()

