
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <regex>

#undef REQUIRE_EXTENSIONS
#include <steamworks>
#define REQUIRE_EXTENSIONS

#define PLUGIN_NAME "hg_bans"
#define PLUGIN_VERSION "0.1.1"
#define LEN_STEAMIDS 24
#define LEN_INTSTRING 13
#define LEN_IPSTRING 17
#define LEN_CONVARS 255
#define LEN_HEXUUID 42
#define IP_BAN_MINUTES 3
#define APPROVED_STATE_PENDING 0
#define APPROVED_STATE_APPROVED 1
#define APPROVED_STATE_DISAPPROVED 2
#define APPROVED_STATE_SERVERBAN 3
#define BAN_CAT_REGULARBAN -1
#define BAN_CAT_TLIST -2
#define TEAM_UNASSIGNED 0
#define TEAM_SPEC 1
#define TEAM_PRISONERS 2
#define TEAM_GUARDS 3
#define TARGET_TYPE_MAGICWORD 0
#define TARGET_TYPE_USERID 1
#define TARGET_TYPE_STEAM 2
#define TARGET_TYPE_NAME 3
#define MSG_PREFIX "\x01[\x04HG Bans\x01]\x04"
#define MSG_PREFIX_NOFORMAT "[HG Bans]"
#define UPDATE_FREQ 60.0
#define PERM_DURATION -1
#define MENU_TIMEOUT_NORMAL 30
#define MENU_TIMEOUT_QUICK 2

// Game definitions.
// Note we only really need two here. CS:GO, and all other games.
// CS:GO engine behaves one way
// All other games, CS:S, TF2, L4D, behave another.

#define GAMETYPE_CSS 0
#define GAMETYPE_CSGO 1

// Server info.
new g_iIP;
new g_iPort;
new g_iGame;
new String:g_sServerMod[24];

// Regex patterns.
new Handle:g_hPatternSteam = INVALID_HANDLE;
#define REGEX_STEAMID "^STEAM_(0|1):(0|1):\\d{1,9}\\z"

// ConVars.
new Handle:g_hTlistEnabled = INVALID_HANDLE;
new Handle:g_hDefaultBan = INVALID_HANDLE;
new Handle:g_hTeamSpamProtection = INVALID_HANDLE;
new Handle:g_hBanMessage = INVALID_HANDLE;
new bool:g_bTlistEnabled = false;
new g_iDefaultBan = 120;
new g_iTeamSpamProtection = 6;
new String:g_sBanMessage[255] = "You are banned. Visit hellsgamers.com/hgbans for more info";

// Sounds.
new String:g_sSoundDeny[32] = "buttons/weapon_cant_buy.wav";

// Database globals.
new Handle:g_hDbConn_Main = INVALID_HANDLE;

// For passing info into menu CB.
new g_iBanTimes[MAXPLAYERS + 1];
new String:g_sBanReasons[MAXPLAYERS + 1][LEN_CONVARS];
new g_iBanCategories[MAXPLAYERS + 1];

// Hold the IPs that we ban, so we can unban them later.
new Handle:g_hBannedIps = INVALID_HANDLE;

// Stores how many times a player tried to join CT in a round (to prevent team join spam).
new g_iTriedJoiningTeam[MAXPLAYERS + 1];

// Variables used to track and prevent rogue admins from mass banning.
new g_iBans[MAXPLAYERS + 1];
new g_iLastBan[MAXPLAYERS + 1];

// Prevent family sharing
new String:g_sOwnerSteamid[MAXPLAYERS + 1][LEN_STEAMIDS];

// Includes.
#include "hg_bans/common.sp"
#include "hg_bans/findtarget.sp"
#include "hg_bans/db.sp"
#include "hg_bans/usage.sp"
#include "hg_bans/latest.sp"
#include "hg_bans/joincheck.sp"
#include "hg_bans/teamcheck.sp"
#include "hg_bans/ban.sp"
#include "hg_bans/unban.sp"

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "Global Ban System",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/hgbans"
};

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

public OnPluginStart()
{
    // Compile commonly used RegEx patterns.
    new flags = PCRE_CASELESS;
    g_hPatternSteam = CompileRegex(REGEX_STEAMID, flags);

    // ConVars.
    decl String:intbuf[LEN_INTSTRING];
    Format(intbuf, sizeof(intbuf), "%b", g_bTlistEnabled);
    g_hTlistEnabled = CreateConVar("hg_bans_tlist_enabled", intbuf,
                                   "Is T-List enforced on this server?",
                                   _, true, 0.0, true, 1.0);
    IntToString(g_iDefaultBan, intbuf, sizeof(intbuf));
    g_hDefaultBan = CreateConVar("hg_bans_default_ban_mins", intbuf,
                                 "The default ban time (in minutes) if a time is not specified",
                                 _, true, 1.0, true, 240.0);
    IntToString(g_iTeamSpamProtection, intbuf, sizeof(intbuf));
    g_hTeamSpamProtection = CreateConVar("hg_bans_team_spam_protection", intbuf,
                                         "If a player tries to join CT X times in 1 round, it will IP ban him for a short time",
                                         _, true, 2.0, true, 20.0);
    g_hBanMessage = CreateConVar("hg_bans_ban_message",
                                 g_sBanMessage,
                                 "The message that appears to a user when they are banned");
    AutoExecConfig(true);

    // Pre-cache sounds.
    PrecacheSound(g_sSoundDeny, true);
    decl String:sFullSoundPath[sizeof(g_sSoundDeny) + 8];
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundDeny);
    AddFileToDownloadsTable(sFullSoundPath);

    // Hook events.
    HookEvent("round_start", OnRoundStart);
    AddCommandListener(OnJoinTeam, "jointeam");

    // Perform applicable tasks.
    Db_OnPluginStart();
    Usage_OnPluginStart();
    Ban_OnPluginStart();
    Unban_OnPluginStart();
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Mark GetUserMessageType as an optional native
    MarkNativeAsOptional("GetUserMessageType");

    // Mark Socket natives as optional
    MarkNativeAsOptional("SocketIsConnected");
    MarkNativeAsOptional("SocketCreate");
    MarkNativeAsOptional("SocketBind");
    MarkNativeAsOptional("SocketConnect");
    MarkNativeAsOptional("SocketDisconnect");
    MarkNativeAsOptional("SocketListen");
    MarkNativeAsOptional("SocketSend");
    MarkNativeAsOptional("SocketSendTo");
    MarkNativeAsOptional("SocketSetOption");
    MarkNativeAsOptional("SocketSetReceiveCallback");
    MarkNativeAsOptional("SocketSetSendqueueEmptyCallback");
    MarkNativeAsOptional("SocketSetDisconnectCallback");
    MarkNativeAsOptional("SocketSetErrorCallback");
    MarkNativeAsOptional("SocketSetArg");
    MarkNativeAsOptional("SocketGetHostName");

    // Mark SteamTools natives as optional
    MarkNativeAsOptional("Steam_IsVACEnabled");
    MarkNativeAsOptional("Steam_GetPublicIP");
    MarkNativeAsOptional("Steam_RequestGroupStatus");
    MarkNativeAsOptional("Steam_RequestGameplayStats");
    MarkNativeAsOptional("Steam_RequestServerReputation");
    MarkNativeAsOptional("Steam_IsConnected");
    MarkNativeAsOptional("Steam_SetRule");
    MarkNativeAsOptional("Steam_ClearRules");
    MarkNativeAsOptional("Steam_ForceHeartbeat");
    MarkNativeAsOptional("Steam_AddMasterServer");
    MarkNativeAsOptional("Steam_RemoveMasterServer");
    MarkNativeAsOptional("Steam_GetNumMasterServers");
    MarkNativeAsOptional("Steam_GetMasterServerAddress");
    MarkNativeAsOptional("Steam_SetGameDescription");
    MarkNativeAsOptional("Steam_RequestStats");
    MarkNativeAsOptional("Steam_GetStat");
    MarkNativeAsOptional("Steam_GetStatFloat");
    MarkNativeAsOptional("Steam_IsAchieved");
    MarkNativeAsOptional("Steam_GetNumClientSubscriptions");
    MarkNativeAsOptional("Steam_GetClientSubscription");
    MarkNativeAsOptional("Steam_GetNumClientDLCs");
    MarkNativeAsOptional("Steam_GetClientDLC");
    MarkNativeAsOptional("Steam_GetCSteamIDForClient");
    MarkNativeAsOptional("Steam_SetCustomSteamID");
    MarkNativeAsOptional("Steam_GetCustomSteamID");
    MarkNativeAsOptional("Steam_RenderedIDToCSteamID");
    MarkNativeAsOptional("Steam_CSteamIDToRenderedID");
    MarkNativeAsOptional("Steam_GroupIDToCSteamID");
    MarkNativeAsOptional("Steam_CSteamIDToGroupID");
    MarkNativeAsOptional("Steam_CreateHTTPRequest");
    MarkNativeAsOptional("Steam_SetHTTPRequestNetworkActivityTimeout");
    MarkNativeAsOptional("Steam_SetHTTPRequestHeaderValue");
    MarkNativeAsOptional("Steam_SetHTTPRequestGetOrPostParameter");
    MarkNativeAsOptional("Steam_SendHTTPRequest");
    MarkNativeAsOptional("Steam_DeferHTTPRequest");
    MarkNativeAsOptional("Steam_PrioritizeHTTPRequest");
    MarkNativeAsOptional("Steam_GetHTTPResponseHeaderSize");
    MarkNativeAsOptional("Steam_GetHTTPResponseHeaderValue");
    MarkNativeAsOptional("Steam_GetHTTPResponseBodySize");
    MarkNativeAsOptional("Steam_GetHTTPResponseBodyData");
    MarkNativeAsOptional("Steam_WriteHTTPResponseBody");
    MarkNativeAsOptional("Steam_ReleaseHTTPRequest");
    MarkNativeAsOptional("Steam_GetHTTPDownloadProgressPercent");

    // Mark cURL natives as optional
    MarkNativeAsOptional("curl_easy_init");
    MarkNativeAsOptional("curl_easy_setopt_string");
    MarkNativeAsOptional("curl_easy_setopt_int");
    MarkNativeAsOptional("curl_easy_setopt_int_array");
    MarkNativeAsOptional("curl_easy_setopt_int64");
    MarkNativeAsOptional("curl_OpenFile");
    MarkNativeAsOptional("curl_httppost");
    MarkNativeAsOptional("curl_slist");
    MarkNativeAsOptional("curl_easy_setopt_handle");
    MarkNativeAsOptional("curl_easy_setopt_function");
    MarkNativeAsOptional("curl_load_opt");
    MarkNativeAsOptional("curl_easy_perform");
    MarkNativeAsOptional("curl_easy_perform_thread");
    MarkNativeAsOptional("curl_easy_send_recv");
    MarkNativeAsOptional("curl_send_recv_Signal");
    MarkNativeAsOptional("curl_send_recv_IsWaiting");
    MarkNativeAsOptional("curl_set_send_buffer");
    MarkNativeAsOptional("curl_set_receive_size");
    MarkNativeAsOptional("curl_set_send_timeout");
    MarkNativeAsOptional("curl_set_recv_timeout");
    MarkNativeAsOptional("curl_get_error_buffer");
    MarkNativeAsOptional("curl_easy_getinfo_string");
    MarkNativeAsOptional("curl_easy_getinfo_int");
    MarkNativeAsOptional("curl_easy_escape");
    MarkNativeAsOptional("curl_easy_unescape");
    MarkNativeAsOptional("curl_easy_strerror");
    MarkNativeAsOptional("curl_version");
    MarkNativeAsOptional("curl_protocols");
    MarkNativeAsOptional("curl_features");
    MarkNativeAsOptional("curl_OpenFile");
    MarkNativeAsOptional("curl_httppost");
    MarkNativeAsOptional("curl_formadd");
    MarkNativeAsOptional("curl_slist");
    MarkNativeAsOptional("curl_slist_append");
    MarkNativeAsOptional("curl_hash_file");
    MarkNativeAsOptional("curl_hash_string");

    // If the game is CS:GO, we need to have the 9 key as the exit button.
    // If the game is any other game (CS:S, TF2, L4D, ect) we need to have the 10 key as the exit button

    decl String:game[PLATFORM_MAX_PATH];
    GetGameFolderName(game, sizeof(game));

    if (StrEqual(game, "csgo"))
        g_iGame = GAMETYPE_CSGO;

    else
        g_iGame = GAMETYPE_CSS;

    return APLRes_Success;
}

public OnConfigsExecuted()
{
    g_bTlistEnabled = GetConVarBool(g_hTlistEnabled);
    g_iDefaultBan = GetConVarInt(g_hDefaultBan);
    g_iTeamSpamProtection = GetConVarInt(g_hTeamSpamProtection);
    GetConVarString(g_hBanMessage, g_sBanMessage, sizeof(g_sBanMessage));
    HookConVarChange(g_hTlistEnabled, OnConVarChange);
    HookConVarChange(g_hDefaultBan, OnConVarChange);
    HookConVarChange(g_hTeamSpamProtection, OnConVarChange);
    HookConVarChange(g_hBanMessage, OnConVarChange);

    // Unload basebans (if it exists).
    decl String:filename[200];
    BuildPath(Path_SM, filename, sizeof(filename), "plugins/basebans.smx");
    if(FileExists(filename))
    {
        decl String:newfilename[200];
        BuildPath(Path_SM, newfilename, sizeof(newfilename), "plugins/disabled/basebans.smx");
        ServerCommand("sm plugins unload basebans");
        if(FileExists(newfilename))
            DeleteFile(newfilename);
        RenameFile(newfilename, filename);
        LogMessage("plugins/basebans.smx was unloaded and moved to plugins/disabled/basebans.smx");
    }
}

public OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    if(CVar == g_hTlistEnabled)
        g_bTlistEnabled = GetConVarBool(CVar);
    else if(CVar == g_hDefaultBan)
        g_iDefaultBan = GetConVarInt(CVar);
    else if(CVar == g_hTeamSpamProtection)
        g_iTeamSpamProtection = GetConVarInt(CVar);
    else if(CVar == g_hBanMessage)
        GetConVarString(CVar, g_sBanMessage, sizeof(g_sBanMessage));
}

OnDbTickSuccess(Handle:conn)
{
    /*
        Called when database is sucessfully connected to, and also whenever
        the connection to the database is successfully confirmed.  Normally
        this event is called at plugin start and every UPDATE_FREQ seconds.
    */

    // Perform applicable tasks.
    Usage_OnDbTickSuccess(conn);
    Latest_OnDbTickSuccess(conn);
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Perform applicable tasks.
    if(g_bTlistEnabled)
        TeamCheck_OnRoundStart();
}

public OnClientPutInServer(client)
{
    // Perform applicable tasks.
    if(g_bTlistEnabled)
        TeamCheck_OnClientPutInServer(client);

    g_iBans[client] = 0;
    g_iLastBan[client] = 0;
}

public SW_OnValidateClient(ownerSteam, clientSteam)
{
    decl String:oSteamid[LEN_STEAMIDS];
    Format(oSteamid, sizeof(oSteamid), "STEAM_0:%d:%d", ownerSteam & 1, ownerSteam >> 1);

    new client = -1;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i))
        {
            if (GetSteamAccountID(i) == clientSteam)
            {
                client = i;
                break;
            }
        }
    }

    if (client > -1)
    {
        if (ownerSteam && ownerSteam != clientSteam)
        {
            Format(g_sOwnerSteamid[client], LEN_STEAMIDS, "%s", oSteamid);
        }

        else
        {
            g_sOwnerSteamid[client][0] = '\0';
        }
    }
}

public OnClientAuthorized(client, const String:auth[])
{
    // Exit if the joining player is a bot (it's not expected that bots will be used with this plugin).
    if(IsFakeClient(client) || strcmp(auth, "BOT", true) == 0)
        return;

    // Perform applicable tasks.
    if (GetExtensionFileStatus("SteamWorks.ext") == 1)
    {
        JoinCheck_OnClientAuthorized(client, auth);
    }

    else
    {
        g_sOwnerSteamid[client][0] = '\0';

        if (!CheckSharedAccountEasyHTTP(client))
        {
            g_sOwnerSteamid[client][0] = '\0';
            JoinCheck_OnClientAuthorized(client, auth);
        }
    }
}

public Action:OnJoinTeam(client, const String:command[], argc)
{
    // Ensure client is valid player.
    if(!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    // What team did the client join?
    decl String:info[7];
    GetCmdArg(1, info, sizeof(info));
    new team = StringToInt(info); // 0=autoassign, 1=spec, 2=prisoner, 3=guard

    // Perform applicable tasks.
    if(g_bTlistEnabled && !TeamCheck_OnJoinTeam(client, team))
        return Plugin_Handled;

    // Show player what his available commands are.
    CreateTimer(3.5, DisplayPlayerCommands, client);

    // Allow the player to join the team.
    return Plugin_Continue;
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public Action:DisplayPlayerCommands(Handle:timer, any:client)
{
    if(!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    // Is admin?
    new AdminId:admid = GetUserAdmin(client);
    if(admid != INVALID_ADMIN_ID)
    {
        PrintToChat(client, "%s Available Banning Commands: \x03!\x01ban\x04, \x03!\x01unban", MSG_PREFIX);
        if(g_bTlistEnabled)
            PrintToChat(client, "%s Available T-Listing Commands: \x03!\x01tlist\x04, \x03!\x01untlist", MSG_PREFIX);
    }
    else
    {
        // pass
    }

    return Plugin_Continue;
}
