import functools
import re
import vpi_config

LOGGER = vpi_config.LOGGER

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
	async def inner(info):
		try:
			conn   = await vpi_config._GetDBConnection()
			cursor = await conn.cursor()
		except Exception as e:
			LOGGER.error("Failed to establish connection to database in WrapDB due to error:", exc_info=True)
			error = f"[VPI ERROR] ({func.__name__}) :: {type(e).__name__}"
			return error

		result = None
		error  = None

		try:
			result = await func(info, cursor)
			LOGGER.debug("Executing interface function with info: %s", info)
		except Exception as e:
			LOGGER.error("Failed to execute interface function due to error:", exc_info=True)
			error = f"[VPI ERROR] ({func.__name__}) :: {type(e).__name__}"
		finally:
			await cursor.close()
			if (error is None):
				await conn.commit()

			if (vpi_config.DB_TYPE == "mysql"):
				vpi_config.DB.release(conn)

			if (error is None): return result
			else:				return error

	# So we can check elsewhere if a specified function was a result of this wrapper
	inner.__WrapDB__ = True

	return inner

# Wrapper for generic interface functions
def WrapInterface(func):
	@functools.wraps(func)
	async def inner(info):
		result = None
		error  = None

		try:
			result = await func(info)
			LOGGER.debug("Executing interface function with info: %s", info)
		except Exception as e:
			LOGGER.error("Failed to execute interface function due to error:", exc_info=True)
			error = f"[VPI ERROR] ({func.__name__}) :: {type(e).__name__}"
		finally:
			if (error is None): return result
			else:				return error

	return inner

player_data_columns = "steam_id, name, elo, wins, losses, kills, deaths, damage_taken, damage_dealt, airshots, market_gardens, hoops_scored, koth_points_capped"
@WrapDB
async def VPI_MGE_DBInit(info, cursor):
	LOGGER.info("Initializing MGE database...")
	# await cursor.execute("CREATE TABLE IF NOT EXISTS mge_leaderboard (steam_id TEXT PRIMARY KEY, elo INTEGER)")

	try:
		await cursor.execute(f"SELECT {player_data_columns} FROM mge_playerdata LIMIT 1")
	except Exception as e:
		LOGGER.warning("No mge_playerdata table found, creating...")
		await cursor.execute("""CREATE TABLE IF NOT EXISTS mge_playerdata (
			steam_id INTEGER PRIMARY KEY, 
			name VARCHAR(255),
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
		LOGGER.info("MGE database initialized, check server console for '[VPI]: Database initialized successfully'")
	return await cursor.fetchall()

DEFAULT_MAX_LEADERBOARD_ENTRIES = 7
@WrapDB
async def VPI_MGE_PopulateLeaderboard(info, cursor):
	kwargs = info["kwargs"]
	order_filter = kwargs["order_filter"] if "order_filter" in kwargs else "elo"
	max_leaderboard_entries = kwargs["max_leaderboard_entries"] if "max_leaderboard_entries" in kwargs else DEFAULT_MAX_LEADERBOARD_ENTRIES
	await cursor.execute(f"SELECT steam_id, {order_filter}, `name` FROM mge_playerdata ORDER BY {order_filter} DESC LIMIT {max_leaderboard_entries}")

	return await cursor.fetchall()

default_zeroes = ", ".join(["0"] * (len(player_data_columns.split(",")) - 3))
@WrapDB
async def VPI_MGE_ReadWritePlayerStats(info, cursor):
    kwargs = info["kwargs"]
    query_mode = kwargs["query_mode"] 
    network_id = kwargs["network_id"]
    name = kwargs["name"]  # This should be properly escaped

    if network_id == "BOT": return

    default_elo = kwargs.get("default_elo", 1000)

    if (query_mode == "read" or query_mode == 0):
        
        LOGGER.info(f"Fetching player data for steam ID {network_id}")
        await cursor.execute(f"SELECT * FROM mge_playerdata WHERE steam_id = {network_id}")
        result = await cursor.fetchall()

        if not result:
            # Parameterized INSERT with proper value ordering
            await cursor.execute(
                f"INSERT INTO mge_playerdata ({player_data_columns}) VALUES (%s, %s, %s, {default_zeroes})",
                (network_id, name, default_elo)
            )
            await cursor.execute("SELECT * FROM mge_playerdata WHERE steam_id = %s", (network_id,))
            result = await cursor.fetchall()

        return result

    elif query_mode == "write" or query_mode == 1:
        # Parameterized UPDATE
        set_clauses = []
        params = []
        for key, value in kwargs['stats'].items():
            set_clauses.append(f"{key} = %s")
            params.append(value)

        params.append(network_id)  # Add WHERE clause param
        query = f"UPDATE mge_playerdata SET {', '.join(set_clauses)} WHERE steam_id = %s"

        await cursor.execute(query, params)
        return await cursor.fetchall()
    
banned_files = [".gitignore", ".git", ".vscode", "README.md", "mge_windows_setup.bat", "config.nut", "vpi_config.py"]
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
            LOGGER.error("[VPI] Error: No repository URL provided")
            return []

        os = vpi_config.os
        git = vpi_config.git
        # Create temp directory for clone
        temp_dir = os.path.join(os.getcwd(), "__temp_mge_autoupdate")
        os.makedirs(temp_dir, exist_ok=True)

        LOGGER.info(f"Cloning repository {repo_url}")
        # Clone the repository using GitPython
        repo = git.Repo.clone_from(repo_url, temp_dir, branch=branch)

        # Get list of changed files by comparing with current directory
        changed_files = []
        current_dir = clone_dir

        for root, _, files in os.walk(temp_dir):
            for file in files:
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
	
        LOGGER.info(f"Changed files: {changed_files}")

        #move changed files to the clone directory
        for file in changed_files:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(os.path.join(clone_dir, file)), exist_ok=True)
            # Copy the file
            os.rename(os.path.join(temp_dir, file), os.path.join(clone_dir, file))


        return changed_files

    except Exception as e:
        LOGGER.error(f"[VPI] Error during auto-update: {str(e)}")
        return []

    finally:
        # Cleanup temp directory
        if 'temp_dir' in locals():
            try:

                if 'repo' in locals() and repo:
                    repo.close()

                from shutil import rmtree

                git_dir = os.path.join(temp_dir, '.git')
                if os.path.exists(git_dir):
                    from subprocess import run, PIPE
                    run(['attrib', '-r', '-h', '-s', '/s', '/d', git_dir], shell=True, stderr=PIPE)

                    for root, dirs, files in os.walk(git_dir, topdown=False):
                        for file in files:
                            try:
                                os.chmod(os.path.join(root, file), 0o777)
                                os.remove(os.path.join(root, file))
                            except:
                                pass
                        for dir in dirs:
                            try:
                                os.chmod(os.path.join(root, dir), 0o777)
                                os.rmdir(os.path.join(root, dir))
                            except:
                                pass

                rmtree(temp_dir, ignore_errors=True)

                if os.path.exists(temp_dir):
                    LOGGER.warning(f"Could not remove temp directory {temp_dir} completely")
            except Exception as e:
                LOGGER.warning(f"Could not clean up temp directory {temp_dir}: {str(e)}")

@WrapInterface
async def VPI_MGE_UpdateServerData(info, cursor):

    return info

@WrapDB
async def VPI_MGE_UpdateServerDataDB(info, cursor):
    
    return info
