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
		LOGGER.info("No mge_playerdata table found, creating...")
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

default_zeroes = ", ".join(["0"] * (len(player_data_columns.split(",")) - 2))
@WrapDB
async def VPI_MGE_ReadWritePlayerStats(info, cursor):
    kwargs = info["kwargs"]
    query_mode = kwargs["query_mode"] 
    network_id = kwargs["network_id"]
    name = kwargs["name"]  # This should be properly escaped

    if network_id == "BOT": return

    default_elo = kwargs.get("default_elo", 1000)

    if (query_mode == "read" or query_mode == 0):
        
        # print(COLOR['CYAN'], f"Fetching player data for steam ID {network_id}", COLOR['ENDC'])
        LOGGER.info(f"Fetching player data for steam ID {network_id}")
        await cursor.execute(f"SELECT * FROM mge_playerdata WHERE steam_id = {network_id}")
        result = await cursor.fetchall()

        if not result:
            # Parameterized INSERT with proper value ordering
            await cursor.execute(
                f"INSERT INTO mge_playerdata ({player_data_columns}) VALUES (%s, %s, %s, {default_zeroes})",
                (network_id, name, default_elo)
            )
            await cursor.execute(f"SELECT * FROM mge_playerdata WHERE steam_id = {network_id}")
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
            LOGGER.error("[VPI] Error: No repository URL provided")
            return []

        # Create temp directory for clone
        temp_dir = tempfile.mkdtemp()

        LOGGER.info(f"Cloning repository {repo_url} into {temp_dir}")
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
	
        LOGGER.info(f"Changed files: {changed_files}")

        #move changed files to the clone directory
        for file in changed_files:
            shutil.move(os.path.join(temp_dir, file), os.path.join(clone_dir, file))


        return changed_files

    except Exception as e:
        LOGGER.error(f"[VPI] Error during auto-update: {str(e)}")
        return []

    finally:
        # Cleanup temp directory
        if 'temp_dir' in locals():
            try:
                shutil.rmtree(temp_dir, ignore_errors=True)
            except Exception as e:
                LOGGER.warning(f"Warning: Could not clean up temp directory {temp_dir}: {str(e)}")

@WrapInterface
async def VPI_MGE_UpdateServerData(info, cursor):

    return info

@WrapDB
async def VPI_MGE_UpdateServerDataDB(info, cursor):
    kwargs = info["kwargs"]

    # Convert time dictionary to datetime object
    time_data = kwargs["update_time"]

    timestamp = datetime.datetime(
        year=time_data.get("year", datetime.datetime.now().year),
        month=time_data.get("month", 1),
        day=time_data.get("day", 1),
        hour=time_data.get("hour", 0),
        minute=time_data.get("minute", 0),
        second=time_data.get("second", 0)
    ).strftime('%Y-%m-%d %H:%M:%S')

    name = kwargs["server_name"]

    response = requests.get(rf"https://api.steampowered.com/IGameServersService/GetServerList/v1/?access_token={ACCESS_TOKEN}&limit=50000&filter=\gamedir\tf\gametype\mge\gametype\potato")

    server = [server for server in response.json()['response']['servers'] if server['name'] == name][0]

    if server and "address" in server:
        kwargs['address'] = server['address']

    if (kwargs["map"].startswith("workshop/")):
        kwargs["map"] = server['map']
        # kwargs["mission"] = server['map']

    await cursor.execute("""
        CREATE TABLE IF NOT EXISTS mge_serverdata (
            server_key VARCHAR(255),
            address VARCHAR(255),
            classes VARCHAR(255),
            map VARCHAR(255),
            max_wave INTEGER,
            mission VARCHAR(255),
            players_blu INTEGER,
            players_connecting INTEGER,
            players_max INTEGER,
            players_red INTEGER,
            region VARCHAR(255),
            server_name VARCHAR(255),
            status VARCHAR(255),
            update_time VARCHAR(255),
            wave INTEGER,
            campaign_name VARCHAR(255),
            domain VARCHAR(255),
            in_protected_match BIT,
            matchmaking_disable_time FLOAT,
            password VARCHAR(255),
            is_fake_ip BIT,
            PRIMARY KEY (server_key, region, campaign_name)
        )"""
    )
    await cursor.execute("""
        INSERT INTO mge_serverdata (
            server_key, address, classes, map, max_wave, mission, 
            players_blu, players_connecting, players_max, players_red,
            region, server_name, status, update_time, wave, campaign_name,
            domain, in_protected_match, matchmaking_disable_time, password, is_fake_ip
        ) VALUES (
            %s, %s, '', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
            NULL, NULL, NULL, NULL, NULL
        )
        ON DUPLICATE KEY UPDATE
            address = VALUES(address),
            classes = VALUES(classes),
            map = VALUES(map),
            max_wave = VALUES(max_wave),
            mission = VALUES(mission),
            players_blu = VALUES(players_blu),
            players_connecting = VALUES(players_connecting),
            players_max = VALUES(players_max),
            players_red = VALUES(players_red),
            region = VALUES(region),
            server_name = VALUES(server_name),
            status = VALUES(status),
            update_time = VALUES(update_time),
            wave = VALUES(wave),
            campaign_name = VALUES(campaign_name)
    """, (
        kwargs["server_key"],
        kwargs["address"], 
        kwargs["map"],
        kwargs["max_wave"],
        kwargs["mission"],
        kwargs["players_blu"],
        kwargs["players_connecting"],
        kwargs["players_max"], 
        kwargs["players_red"],
        kwargs["region"],
        kwargs["server_name"],
        kwargs["status"],
        timestamp,
        kwargs["wave"],
        kwargs["campaign_name"]
    ))
    return server
