#include <sourcemod>

#define PLUGIN_NAME "hg_manager"
#define SERVER_MOD "css"
#define PLUGIN_VERSION "0.0.0b"

#define LEN_STEAMIDS 24
#define LEN_IPS 24
#define LEN_CONVARS 255
#define LEN_MESSAGES 255

/*
CREATE TABLE IF NOT EXISTS serverusage
(
    ip VARCHAR(255),
    port INTEGER,
    name VARCHAR(255),
    mod_type VARCHAR(255),
    rcon VARCHAR(255),
    pass VARCHAR(255),
    lastseen INTEGER,
    version VARCHAR(255),
    cvar_frequency REAL,

    UNIQUE KEY (ip)
);

CREATE TABLE IF NOT EXISTS actionlogs
(
    id INTEGER NOT NULL AUTO_INCREMENT,
    ip VARCHAR(255),
    port INTEGER,
    timestamp INTEGER,
    action_type VARCHAR(255),
    admin_name VARCHAR(32),
    admin_steamid VARCHAR(24),
    target_name VARCHAR(32),
    target_steamid VARCHAR(24),
    parameters VARCHAR(255),

    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS globalmessages
(
    id INTEGER NOT NULL AUTO_INCREMENT,
    active TINYINT,
    timestamp INTEGER,
    repeat_times INTEGER,
    repeat_interval REAL,
    message VARCHAR(255),

    PRIMARY KEY (id)
);
 */

new g_iTimeOfDeath[MAXPLAYERS + 1];

new String:g_sIP[LEN_IPS];
new g_iPort = 27015;

new Handle:g_hRequiresTarget = INVALID_HANDLE;

new Handle:g_hDBConn = INVALID_HANDLE;
new Handle:g_hReconnectFrequency = INVALID_HANDLE;

/* ----- Events ----- */


public OnPluginStart()
{
    RegAdminCmd("sm_mute", OnAdminCommand, ADMFLAG_KICK);
    RegAdminCmd("sm_map", OnAdminCommand, ADMFLAG_CHANGEMAP);
    RegAdminCmd("sm_kick", OnAdminCommand, ADMFLAG_KICK);
    RegAdminCmd("sm_slap", OnAdminCommand, ADMFLAG_KICK);
    RegAdminCmd("sm_msay", OnAdminCommand, ADMFLAG_CHAT);
    RegAdminCmd("sm_csay", OnAdminCommand, ADMFLAG_CHAT);
    RegAdminCmd("sm_tsay", OnAdminCommand, ADMFLAG_CHAT);
    RegAdminCmd("sm_ban", OnAdminCommand, ADMFLAG_BAN);
    RegAdminCmd("sm_slay", OnAdminCommand, ADMFLAG_SLAY);
    RegAdminCmd("sm_noclip", OnAdminCommand, ADMFLAG_ROOT);
    RegAdminCmd("sm_gravity", OnAdminCommand, ADMFLAG_CHANGEMAP);
    RegAdminCmd("sm_drug", OnAdminCommand, ADMFLAG_CHANGEMAP);

    g_hRequiresTarget = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));

    PushArrayString(g_hRequiresTarget, "mute");
    PushArrayString(g_hRequiresTarget, "kick");
    PushArrayString(g_hRequiresTarget, "slap");
    PushArrayString(g_hRequiresTarget, "psay");
    PushArrayString(g_hRequiresTarget, "slay");
    PushArrayString(g_hRequiresTarget, "ban");
    PushArrayString(g_hRequiresTarget, "noclip");
    PushArrayString(g_hRequiresTarget, "gravity");
    PushArrayString(g_hRequiresTarget, "drug");

    g_hReconnectFrequency = CreateConVar("hg_manager_reconnect_frequency",
                                         "1200",
                                         "Every <x> seconds to reconnect to the hg_manager DB");

    LoadTranslations("common.phrases");

    GetServerIP();
    g_iPort = GetServerPort();

    ConnectToDB(INVALID_HANDLE);
    CreateTimer(1200.0, ConnectToDB);

    HookEvent("player_death", OnPlayerDeath);
}

public OnPlayerDeath(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_iTimeOfDeath[client] = GetTime();
}

/* ----- Functions ----- */


stock DB_UpdateServerUsage()
{
    // Hold the table's column names in a string.  This will be used when the SQL statement is constructed below.
    decl String:columns[] = "ip, port, name, mod_type, rcon, pass, lastseen, version, cvar_frequency";

    // [name]
    decl String:name[LEN_CONVARS];
    if(!SQL_EscapeString(g_hDBConn, GetServerCvar("hostname"), name, sizeof(name)))
        Format(name, sizeof(name), "Server name too long");

    // [rcon]
    decl String:rcon[LEN_CONVARS];
    if(!SQL_EscapeString(g_hDBConn, GetServerCvar("rcon_password"), rcon, sizeof(rcon)))
        Format(rcon, sizeof(rcon), "Server RCON too long");

    // [pass]
    decl String:pass[LEN_CONVARS];
    if(!SQL_EscapeString(g_hDBConn, GetServerCvar("sv_password"), pass, sizeof(pass)))
        Format(pass, sizeof(pass), "Server password too long");

    // Combine values into SQL statement string.
    decl String:values[1024];
    Format(values, sizeof(values), "'%s', %i, '%s', '%s', '%s', '%s', UNIX_TIMESTAMP(), '%s%s', %f",
        g_sIP, g_iPort,
        name, SERVER_MOD, rcon, pass, PLUGIN_VERSION, SERVER_MOD, GetConVarFloat(g_hReconnectFrequency));

    decl String:updates[1024];
    Format(updates, sizeof(updates), "name='%s', mod_type='%s', rcon='%s', pass='%s', lastseen=UNIX_TIMESTAMP(), version='%s%s', \
         cvar_frequency=%f",
        name, SERVER_MOD, rcon, pass, PLUGIN_VERSION, SERVER_MOD, GetConVarFloat(g_hReconnectFrequency));

    decl String:q[2048];
    Format(q, sizeof(q), "INSERT INTO serverusage (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s", columns, values, updates);

    // Execute statement.
    SQL_TQuery(g_hDBConn, EmptyCallback, q);
}

stock GetServerIP()
{
    new longip = GetConVarInt(FindConVar("hostip"));
    Format(g_sIP, sizeof(g_sIP), "%i.%i.%i.%i", (longip >> 24) & 0x000000FF,
                                                (longip >> 16) & 0x000000FF,
                                                (longip >>  8) & 0x000000FF,
                                                 longip        & 0x000000FF);
}

String:GetServerCvar(const String:cvarname[])
{
    decl String:val[LEN_CONVARS];
    GetConVarString(FindConVar(cvarname), val, LEN_CONVARS);
    return val;
}

GetServerPort()
{
    return GetConVarInt(FindConVar("hostport"));
}

/* ----- Callbacks ----- */


public Action:OnLogAction(Handle:source, Identity:identity, client, target, const String:message[])
{
    decl String:admin_name[MAX_NAME_LENGTH] = "CONSOLE";
    decl String:admin_steamid[LEN_STEAMIDS] = "CONSOLE";
    decl String:target_name[MAX_NAME_LENGTH] = "N/A";
    decl String:target_steamid[LEN_STEAMIDS] = "N/A";
    decl String:command[MAX_NAME_LENGTH] = "";
    decl String:parameters[LEN_MESSAGES];

    if (client > 0)
    {
        GetClientName(client, admin_name, sizeof(admin_name));
        GetClientAuthString(client, admin_steamid, sizeof(admin_steamid));
    }

    if (StrContains(message, "triggered sm_say (") > -1)
        command = "all chat";

    else if (StrContains(message, "triggered sm_chat (") > -1)
        command = "admin chat";

    else if (StrContains(message, "triggered sm_psay to") > -1)
        command = "private chat";

    else
        return Plugin_Continue;

    Format(parameters, sizeof(parameters),
           message[StrContains(message, "(text ") + 6]);

    parameters[strlen(parameters) - 1] = '\0';

    if (StrEqual(command, "private chat"))
    {
        decl String:unformatted[LEN_MESSAGES];

        Format(unformatted, sizeof(unformatted),
               message[StrContains(message, "sm_psay to ") + 11]);

        unformatted[StrContains(unformatted, " (text ")] = '\0';
        StripQuotes(unformatted);

        Format(target_name, sizeof(target_name), unformatted);
        target_name[StrContains(target_name, "><STEAM_0:") - 2] = '\0';

        Format(target_steamid, sizeof(target_steamid),
               unformatted[StrContains(unformatted, "><STEAM_0:") + 2]);
        target_steamid[StrContains(target_steamid, ">")] = '\0';
    }

    decl String:esc_admin_name[MAX_NAME_LENGTH * 2 + 1];
    decl String:esc_admin_steamid[LEN_STEAMIDS * 2 + 1];
    decl String:esc_target_name[MAX_NAME_LENGTH * 2 + 1];
    decl String:esc_target_steamid[LEN_STEAMIDS * 2 + 1];
    decl String:esc_parameters[LEN_MESSAGES * 2 + 1];

    SQL_EscapeString(g_hDBConn, admin_name, esc_admin_name, sizeof(esc_admin_name));
    SQL_EscapeString(g_hDBConn, admin_steamid, esc_admin_steamid, sizeof(esc_admin_steamid));
    SQL_EscapeString(g_hDBConn, target_name, esc_target_name, sizeof(esc_target_name));
    SQL_EscapeString(g_hDBConn, target_steamid, esc_target_steamid, sizeof(esc_target_steamid));
    SQL_EscapeString(g_hDBConn, parameters, esc_parameters, sizeof(esc_parameters));

    decl String:query[2048];
    decl String:columns[256];
    decl String:values[1536];

    Format(columns, sizeof(columns),
           "ip, port, timestamp, action_type, admin_name, admin_steamid, target_name, target_steamid, parameters");

    Format(values, sizeof(values),
           "'%s', %d, UNIX_TIMESTAMP(), '%s', '%s', '%s', '%s', '%s', '%s'",
           g_sIP, g_iPort, command,
           esc_admin_name, esc_admin_steamid,
           esc_target_name, esc_target_steamid,
           esc_parameters);

    Format(query, sizeof(query),
           "INSERT INTO actionlogs (%s) VALUES (%s)",
           columns, values)

    SQL_TQuery(g_hDBConn, EmptyCallback, query);
    return Plugin_Continue;
}

public Action:OnAdminCommand(client, args)
{
    decl String:admin_name[MAX_NAME_LENGTH] = "CONSOLE";
    decl String:admin_steamid[LEN_STEAMIDS] = "CONSOLE";
    decl String:target_name[MAX_NAME_LENGTH] = "N/A";
    decl String:target_steamid[LEN_STEAMIDS] = "N/A";
    decl String:parameters[LEN_STEAMIDS] = "N/A";

    if (client > 0)
    {
        GetClientName(client, admin_name, sizeof(admin_name));
        GetClientAuthString(client, admin_steamid, sizeof(admin_steamid));
    }

    GetCmdArgString(parameters, sizeof(parameters));

    decl String:command[MAX_NAME_LENGTH];
    GetCmdArg(0, command, sizeof(command));

    for (new i = 0; i < strlen(command); i++)
        command[i] = CharToLower(command[i]);

    ReplaceString(command, sizeof(command), "sm_", "");

    // The command executed requires a target.
    if (FindStringInArray(g_hRequiresTarget, command) > -1)
    {
        decl String:sTarget[MAX_NAME_LENGTH];
        GetCmdArg(1, sTarget, sizeof(sTarget));

        new bool:tn_is_ml;
        new target = FindTarget(client, sTarget, false, false);
        new targets[2];

        Format(parameters, sizeof(parameters),
               parameters[StrContains(parameters, sTarget) + strlen(sTarget)]);

        if (parameters[0] == '"' && parameters[1] == ' ')
            Format(parameters, sizeof(parameters), parameters[2]);

        if (target > 0)
        {
            // The command wasn't actually executed because they're dead.
            if ((StrEqual(command, "slay") || StrEqual(command, "slap")) &&
                (!IsPlayerAlive(target) || GetClientTeam(target) <= 1) &&
                (GetTime() - g_iTimeOfDeath[target]) > 0)
                return Plugin_Continue;

            GetClientAuthString(target, target_steamid, sizeof(target_steamid));
            GetClientName(target, target_name, sizeof(target_name));
        }

        else if (ProcessTargetString(sTarget, client,
                                     targets, sizeof(targets),
                                     COMMAND_FILTER_NO_IMMUNITY,
                                     target_name, sizeof(target_name),
                                     tn_is_ml))
            target_steamid = "N/A";

        // No target was found. They done derped.
        else
            return Plugin_Continue;
    }
    
    decl String:esc_admin_name[MAX_NAME_LENGTH * 2 + 1];
    decl String:esc_admin_steamid[LEN_STEAMIDS * 2 + 1];
    decl String:esc_target_name[MAX_NAME_LENGTH * 2 + 1];
    decl String:esc_target_steamid[LEN_STEAMIDS * 2 + 1];
    decl String:esc_parameters[LEN_MESSAGES * 2 + 1];

    SQL_EscapeString(g_hDBConn, admin_name, esc_admin_name, sizeof(esc_admin_name));
    SQL_EscapeString(g_hDBConn, admin_steamid, esc_admin_steamid, sizeof(esc_admin_steamid));
    SQL_EscapeString(g_hDBConn, target_name, esc_target_name, sizeof(esc_target_name));
    SQL_EscapeString(g_hDBConn, target_steamid, esc_target_steamid, sizeof(esc_target_steamid));
    SQL_EscapeString(g_hDBConn, parameters, esc_parameters, sizeof(esc_parameters));

    decl String:query[2048];
    decl String:columns[256];
    decl String:values[1536];

    Format(columns, sizeof(columns),
           "ip, port, timestamp, action_type, admin_name, admin_steamid, target_name, target_steamid, parameters");

    Format(values, sizeof(values),
           "'%s', %d, UNIX_TIMESTAMP(), '%s', '%s', '%s', '%s', '%s', '%s'",
           g_sIP, g_iPort, command,
           esc_admin_name, esc_admin_steamid,
           esc_target_name, esc_target_steamid,
           esc_parameters);

    Format(query, sizeof(query),
           "INSERT INTO actionlogs (%s) VALUES (%s)",
           columns, values)

    SQL_TQuery(g_hDBConn, EmptyCallback, query);
    return Plugin_Continue;
}

public Action:ConnectToDB(Handle:timer)
{
    CreateTimer(GetConVarFloat(g_hReconnectFrequency), ConnectToDB);

    if (g_hDBConn != INVALID_HANDLE)
        CloseHandle(g_hDBConn);

    g_hDBConn = INVALID_HANDLE;

    if(!SQL_CheckConfig(PLUGIN_NAME))
    {
        SetFailState("ERROR: There is no entry for \"%s\" in databases.cfg", PLUGIN_NAME);
        return;
    }

    SQL_TConnect(ConnectToDBFinish, PLUGIN_NAME);
}

public ConnectToDBFinish(Handle:driver, Handle:conn, const String:error[], any:data)
{
    if (conn == INVALID_HANDLE)
    {
        LogError("Unabled to connect to \"%s\" (%s)", PLUGIN_NAME, error);
        return;
    }

    g_hDBConn = CloneHandle(conn);
    DB_UpdateServerUsage();
}

public EmptyCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
        LogError("ERROR: hg_manager returned invalid DB Handle (%s)", error);
}

