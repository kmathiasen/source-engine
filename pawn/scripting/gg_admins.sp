#include <sourcemod>

#pragma semicolon 1

#define TEAM_SPEC 1
#define DB_NAME "gungame"

// Should be in a .cfg... Oh well.
#define MIN_PLAYERS_FOR_RANK 4
#define UPDATE_FREQUENCY 600.0
#define MIN_PLAYTIME_PERCENT 0.25
#define ADVERT_FREQUENCY 73.29
#define PREMIUM_TOP_PLAYERS 10
#define PREMIUM_TOP_ACTIVE 8
#define FREE_VIP_TIMESPAN 60 * 60 * 24 * 14

new String:g_sFreeAdminPath[PLATFORM_MAX_PATH];

new g_iStartTime;
new g_iSpawned[MAXPLAYERS + 1];

new Handle:g_hFreeAdmin = INVALID_HANDLE;
new Handle:g_hDBConn = INVALID_HANDLE;
new Handle:g_hReconnectTimer = INVALID_HANDLE;
new Handle:g_hTime = INVALID_HANDLE;
new Handle:g_hFreeVIP = INVALID_HANDLE;


/* ----- Events ----- */


public OnPluginStart()
{
    BuildPath(Path_SM,
              g_sFreeAdminPath, sizeof(g_sFreeAdminPath),
              "configs/gg_admins_free.txt");

    g_hFreeAdmin = CreateTrie();
    g_hTime = CreateTrie();
    g_hFreeVIP = CreateTrie();

    RegConsoleCmd("sm_reloadadmins", Command_ReloadAdmins);

    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_team", OnPlayerTeam);

    if (!SQL_CheckConfig(DB_NAME))
        SetFailState("ERROR: There is no entry for \"%s\" in databases.cfg", DB_NAME);

    SQL_TConnect(DBConnectCallback, DB_NAME);

    CreateTimer(2.5, RebuildFreeAdmins);
    CreateTimer(ADVERT_FREQUENCY, Advertise, _, TIMER_REPEAT);
}

public OnMapStart()
{
    g_iStartTime = GetTime();

    ClearTrie(g_hTime);
    ClearTrie(g_hFreeVIP);

    if (g_hDBConn == INVALID_HANDLE)
        return;

    decl String:query[512];

    Format(query, sizeof(query),
           "DELETE FROM gungame_rounds WHERE (UNIX_TIMESTAMP() - timestamp) > %d",
           FREE_VIP_TIMESPAN);

    SQL_TQuery(g_hDBConn, EmptyCallback, query);

    Format(query, sizeof(query),
           "DELETE FROM gungame_wins WHERE (UNIX_TIMESTAMP() - timestamp) > %d",
           FREE_VIP_TIMESPAN);

    SQL_TQuery(g_hDBConn, EmptyCallback, query);

    Format(query, sizeof(query),
           "SELECT p.id, p.authid FROM gungame_playerdata p JOIN gungame_rounds r ON p.id = r.pid GROUP BY r.pid ORDER BY COUNT(r.pid) DESC LIMIT %d",
           PREMIUM_TOP_ACTIVE);

    SQL_TQuery(g_hDBConn, GiveFreeVIPCallback, query);

    Format(query, sizeof(query),
           "SELECT p.id, p.authid FROM gungame_playerdata p JOIN gungame_wins w ON p.id = w.pid GROUP BY w.pid ORDER BY COUNT(w.pid) DESC LIMIT %d",
           PREMIUM_TOP_PLAYERS);

    SQL_TQuery(g_hDBConn, GiveFreeVIPCallback, query);
}

public OnRebuildAdminCache(AdminCachePart:part)
{
    CreateTimer(2.5, RebuildFreeAdmins);
}

public OnClientPostAdminCheck(client)
{
    decl String:steamid[32];
    decl String:name[MAX_NAME_LENGTH];

    GetClientAuthString(client, steamid, sizeof(steamid));

    if (GetTrieString(g_hFreeAdmin, steamid, name, sizeof(name)))
        GivePlayerAdmin(name, steamid, "Free Admin [Gungame]", g_hFreeAdmin);

    else if (GetTrieString(g_hFreeVIP, steamid, name, sizeof(name)))
        GivePlayerAdmin(name, steamid, "Reserve", g_hFreeVIP);
}

public GG_OnWinner(client, const String:Weapon[], victim)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    new count;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) > 1)
        {
            decl String:steamid[32];
            GetClientAuthString(i, steamid, sizeof(steamid));

            if (!StrEqual(steamid, "BOT", false))
                count++;
        }
    }

    if (count < MIN_PLAYERS_FOR_RANK)
    {
        PrintToChatAll("\x03[Free VIP]:\x01 Not enough active players for this map's stats to count");
        return;
    }

    CreateTimer(2.5, AddWin, GetClientUserId(client));
}

public OnClientPutInServer(client)
{
    g_iSpawned[client] = -1;
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!client)
        return;

    if (GetClientTeam(client) <= TEAM_SPEC)
        g_iSpawned[client] = -1;

    else if (g_iSpawned[client] > 0)
    {

        decl String:steamid[32];
        GetClientAuthString(client, steamid, sizeof(steamid));

        new previous_time;
        GetTrieValue(g_hTime, steamid, previous_time);

        SetTrieValue(g_hTime, steamid,
                     previous_time + (GetTime() - g_iSpawned[client]));
        
    }

    g_iSpawned[client] = GetTime();
}

public OnPlayerTeam(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (GetEventInt(event, "team") <= TEAM_SPEC)
        g_iSpawned[client] = -1;

    if (!client)
        return;

    decl String:steamid[32];
    decl String:dummy[2];
    GetClientAuthString(client, steamid, sizeof(steamid));

    if (GetTrieString(g_hFreeVIP, steamid, dummy, sizeof(dummy)))
        PrintToChat(client,
                    "\x03[GG TOP]: \x01Congratulations! You have \x04Free VIP\x01. Type \x03!freevip\x01 for more info.");
}


/* ----- Commands ----- */


public Action:Command_ReloadAdmins(client, args)
{
    if (!client)
        return Plugin_Continue;

    new bits = GetUserFlagBits(client);
    if (bits & ADMFLAG_ROOT || bits & ADMFLAG_CHANGEMAP)
        CreateTimer(2.5, RebuildFreeAdmins);

    return Plugin_Continue;
}


/* ----- Callbacks ----- */


public Action:Advertise(Handle:timer, any:data)
{
    static ad;

    switch (ad++)
    {
        case 0:
            PrintToChatAll("\x01This server provides \x04Free VIP\x01. Type \x03!freevip\x01 for more info");

        case 1:
            PrintToChatAll("\x01Top %d winners recieve \x04Free VIP\x01. Type \x03!freevip\x01 for more info", PREMIUM_TOP_PLAYERS);

        case 2:
            PrintToChatAll("\x01Top %d most active recieve \x04Free VIP\x01. Type \x03!freevip\x01 for more info", PREMIUM_TOP_ACTIVE);

        case 3:
            PrintToChatAll("\x01Want \x04Free VIP\x01? Hats, trails and more? Type \x03!freevip\x01 for more info");

        default:
        {
            PrintToChatAll("\x04VIP members \x01recieve hats, trails, and more!. Type \x03!freevip\x01 for more info");
            ad = 0;
        }
    }
}

public Action:AddWin(Handle:timer, any:client)
{
    decl String:query[512];
    decl String:steamid[32];

    client = GetClientOfUserId(client);
    new map_time = GetTime() - g_iStartTime;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        GetClientAuthString(i, steamid, sizeof(steamid));

        if (i == client)
        {
            Format(query, sizeof(query),
                   "INSERT INTO gungame_wins (pid, timestamp) VALUES ((SELECT id FROM gungame_playerdata WHERE authid = '%s'), UNIX_TIMESTAMP())",
                   steamid);
    
            SQL_TQuery(g_hDBConn, EmptyCallback, query);
        }

        else
        {
            new time_played;
            GetTrieValue(g_hTime, steamid, time_played);

            new Float:percent = float(time_played) / float(map_time);

            if (percent < MIN_PLAYTIME_PERCENT)
            {
                PrintToChat(i,
                            "\x03[Free VIP]: \x01You only played \x04%.1f%%\x01 of this map",
                            percent * 100);

                PrintToChat(i,
                            "\x03[Free VIP]: \x01You must play \x04%.1f%%\x01 of the map to count as a play",
                            MIN_PLAYTIME_PERCENT * 100);

                continue;
            }
        }

        decl String:player_name[MAX_NAME_LENGTH];
        decl String:esc_player_name[MAX_NAME_LENGTH * 2 + 1];

        GetClientName(i, player_name, sizeof(player_name));
        SQL_EscapeString(g_hDBConn, player_name, esc_player_name, sizeof(esc_player_name));

        Format(query, sizeof(query),
               "INSERT IGNORE INTO gungame_playerdata (wins, name, timestamp, authid) VALUES (0, '%s', UNIX_TIMESTAMP(), '%s')",
               esc_player_name, steamid);

        SQL_TQuery(g_hDBConn, EmptyCallback, query);

        Format(query, sizeof(query),
               "INSERT INTO gungame_rounds (pid, timestamp) VALUES ((SELECT id FROM gungame_playerdata WHERE authid = '%s'), UNIX_TIMESTAMP())",
               steamid);

        SQL_TQuery(g_hDBConn, EmptyCallback, query);
    }
}

public EmptyCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
        LogError(error);
}

public GiveFreeVIPCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
        LogError(error);

    decl String:steamid[32];
    decl String:admin_name[MAX_NAME_LENGTH + 8];

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

        if (FindAdminByIdentity(AUTHMETHOD_STEAM, steamid) != INVALID_ADMIN_ID)
            continue;

        Format(admin_name, sizeof(admin_name), "%d-%s", SQL_FetchInt(hndl, 0), steamid);
        ReplaceString(admin_name, sizeof(admin_name), "STEAM_0:", "", false);

        GivePlayerAdmin(admin_name, steamid, "Reserve", g_hFreeVIP);
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            RunAdminCacheChecks(i);
    }
}

public DBConnectCallback(Handle:driver, Handle:conn, const String:error[], any:data)
{
    if (conn == INVALID_HANDLE && g_hReconnectTimer == INVALID_HANDLE)
    {
        LogError("GG Admins: Could not connect to the database");

        g_hDBConn = INVALID_HANDLE;
        g_hReconnectTimer = CreateTimer(UPDATE_FREQUENCY, OnDBReconnect);
    }

    g_hDBConn = CloneHandle(conn);

    SQL_TQuery(conn, EmptyCallback, "CREATE TABLE IF NOT EXISTS gungame_wins (id INTEGER NOT NULL AUTO_INCREMENT, pid INTEGER NOT NULL, timestamp INTEGER, PRIMARY KEY (id))");
    SQL_TQuery(conn, EmptyCallback, "CREATE TABLE IF NOT EXISTS gungame_rounds (id INTEGER NOT NULL AUTO_INCREMENT, pid INTEGER NOT NULL, timestamp INTEGER, PRIMARY KEY (id))");

    OnMapStart();
}

public Action:OnDBReconnect(Handle:timer)
{
    g_hReconnectTimer = INVALID_HANDLE;
    SQL_TConnect(DBConnectCallback, DB_NAME);
}

/* ----- Functions ----- */


stock GivePlayerAdmin(const String:name[], const String:steamid[], const String:group[], Handle:trie)
{
    new AdminId:admin = INVALID_ADMIN_ID;
    SetTrieString(trie, steamid, name);

    if ((admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamid)) != INVALID_ADMIN_ID)
    {
        AdminInheritGroup(admin, FindAdmGroup(group));
        return;
    }

    admin = CreateAdmin(name);
    if (!BindAdminIdentity(admin, AUTHMETHOD_STEAM, steamid))
    {
        LogError("%s can't bind identity (%s)", name, steamid);
        return;
    }

    AdminInheritGroup(admin, FindAdmGroup(group));
}

public Action:RebuildFreeAdmins(Handle:timer)
{
    new Handle:oFile = OpenFile(g_sFreeAdminPath, "r");
    decl String:line[MAX_NAME_LENGTH * 2 + 4];
    decl String:sParts[2][MAX_NAME_LENGTH];

    while (ReadFileLine(oFile, line, sizeof(line)))
    {
        TrimString(line);
        if (StrEqual(line, ""))
            continue;

        ExplodeString(line, " - ", sParts, 2, MAX_NAME_LENGTH);
        GivePlayerAdmin(sParts[0], sParts[1], "Free Admin [Gungame]", g_hFreeAdmin);
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            RunAdminCacheChecks(i);
    }

    CloseHandle(oFile);
}

