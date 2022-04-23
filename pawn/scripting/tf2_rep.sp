#include <sourcemod>
#include <hg_jbaio>

#define PLUGIN_NAME "hg_jbaio"
#define MSG_PREFIX "\x01[\x04HG JB\x01]\x04"

#define REP_INTERVAL 90.0
#define REP_IDLE 1
#define REP_PLAYING 2

new Handle:hDBConn = INVALID_HANDLE;
new Handle:g_hRep_UpdateQueue_Array = INVALID_HANDLE;
new Handle:g_hRep_UpdateQueue_Reps = INVALID_HANDLE;
new Handle:g_hRep_UpdateQueue_Names = INVALID_HANDLE;

new g_iRepThisConnect[MAXPLAYERS + 1];
new bool:g_bNoRepForYou[MAXPLAYERS + 1];

new String:g_sLogPath[PLATFORM_MAX_PATH];
new String:g_sDBNames[2][32] = {"prisonrep", "prisonrep_csgo"};

/* ----- Events ----- */


public OnPluginStart()
{
    CreateTimer(REP_INTERVAL, Timer_GiveRep, _, TIMER_REPEAT);
    CreateTimer(600.0, Timer_SaveRep, _, TIMER_REPEAT);

    g_hRep_UpdateQueue_Array = CreateArray(ByteCountToCells(32));
    g_hRep_UpdateQueue_Reps = CreateTrie();
    g_hRep_UpdateQueue_Names = CreateTrie();

    BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/fuckbags.log");

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            OnClientPutInServer(i);
        }
    }
}

public OnMapStart()
{
    ConnectToDB(INVALID_HANDLE);
}

public OnClientPutInServer(client)
{
    g_bNoRepForYou[client] = false;
    g_iRepThisConnect[client] = 0;

    decl String:clientIP[32];
    decl String:targetIP[32];

    GetClientIP(client, clientIP, sizeof(clientIP));

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || i == client)
            continue;

        GetClientIP(i, targetIP, sizeof(targetIP));

        if (StrEqual(clientIP, targetIP))
        {
            g_bNoRepForYou[i] = true;
            g_bNoRepForYou[client] = true;

            LogToFile(g_sLogPath, "%L and %L have matching IPs - %s", i, client, clientIP);
        }
    }
}

/* ----- Callbacks ----- */

public Action:Timer_GiveRep(Handle:timer, any:data)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        if (g_bNoRepForYou[i])
        {
            // debug
            GivePlayerRep(i, -15);
            //PrintToChat(i, "%s You recieved \x03zero\x04 rep. Bitch don't double dip");
            //KeyHintText(i, "+0 rep\nBitch don't double dip");

            //continue;
        }

        if (GetClientTeam(i) <= 1)
        {
            GivePlayerRep(i, REP_IDLE);
            PrintToChat(i, "%s You recieved \x03%d\x04 CS:GO, CS:S, and TF2 prison rep for idling in spectate", MSG_PREFIX, REP_IDLE);
        }

        else
        {
            GivePlayerRep(i, REP_PLAYING);
            KeyHintText(i, "+%d CS:GO rep\n+%d CS:S rep\n+%d TF2 rep", REP_PLAYING, REP_PLAYING, REP_PLAYING);
        }
    }
}

public Action:Timer_SaveRep(Handle:timer, any:data)
{
    new rep;
    decl String:query[512];
    decl String:steamid[32];
    decl String:name[MAX_NAME_LENGTH];
    decl String:sEscapedName[MAX_NAME_LENGTH * 2 + 1];

    for (new i = 0; i < GetArraySize(g_hRep_UpdateQueue_Array); i++)
    {
        GetArrayString(g_hRep_UpdateQueue_Array, i, steamid, sizeof(steamid));
        GetTrieString(g_hRep_UpdateQueue_Names, steamid, name, sizeof(name));
        GetTrieValue(g_hRep_UpdateQueue_Reps, steamid, rep);

        ReplaceString(steamid, sizeof(steamid), "STEAM_0:", "");

        SQL_EscapeString(hDBConn, name, sEscapedName, sizeof(sEscapedName));

        for (new j = 0; j < 2; j++)
        {
            Format(query, sizeof(query),
                   "INSERT INTO %s (steamid, ingamename, points) VALUES ('%s', '%s', %d) ON DUPLICATE KEY UPDATE ingamename = '%s', points = points + %d",
                   g_sDBNames[j], steamid, sEscapedName, rep, sEscapedName, rep);

            SQL_TQuery(hDBConn, EmptyCallback, query);
        }

    }

    ClearArray(g_hRep_UpdateQueue_Array);
    ClearTrie(g_hRep_UpdateQueue_Reps);
    ClearTrie(g_hRep_UpdateQueue_Names);
}

public DBConnectCallback(Handle:driver, Handle:conn, const String:error[], any:data)
{
    if (conn == INVALID_HANDLE)
    {
        LogError("Unable to connect to %s (%s)", PLUGIN_NAME, error);
        CreateTimer(600.0, ConnectToDB);

        return;
    }

    new Handle:old = hDBConn;
    hDBConn = CloneHandle(conn);

    if (old != INVALID_HANDLE)
        CloseHandle(old);
}

public Action:ConnectToDB(Handle:timer)
{
    if(!SQL_CheckConfig(PLUGIN_NAME))
    {
        SetFailState("ERROR: There is no entry for %s in databases.cfg", PLUGIN_NAME);
        return Plugin_Stop;
    }

    SQL_TConnect(DBConnectCallback, PLUGIN_NAME);
    return Plugin_Stop;
}

public EmptyCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!StrEqual(error, ""))
        LogError(error);
}


/* ----- Functions ----- */


stock KeyHintText(client, const String:message[], any:...)
{
    decl String:formatted[256];
    VFormat(formatted, sizeof(formatted), message, 3);

    new Handle:hBuffer = StartMessageOne("KeyHintText", client);
    BfWriteByte(hBuffer, 1);
    BfWriteString(hBuffer, formatted);
    EndMessage();  
}

stock GivePlayerRep(client, rep)
{
    g_iRepThisConnect[client] += rep;

    decl String:steamid[32];
    decl String:name[MAX_NAME_LENGTH];

    GetClientAuthString(client, steamid, sizeof(steamid));
    GetClientName(client, name, sizeof(name));

    new old;
    GetTrieValue(g_hRep_UpdateQueue_Reps, steamid, old)

    if (FindStringInArray(g_hRep_UpdateQueue_Array, steamid) == -1)
        PushArrayString(g_hRep_UpdateQueue_Array, steamid);

    SetTrieValue(g_hRep_UpdateQueue_Reps, steamid, old + rep);
    SetTrieString(g_hRep_UpdateQueue_Names, steamid, name);

    PrisonRep_AddPoints(client, rep, false);
}
