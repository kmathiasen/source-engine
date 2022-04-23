// To add
// paintball

// ###################### PLUGIN INFORMATION ######################

/* FORMAT STANDARDS:

    (1) INDENTATION - Use 4 spaces for each indentation level.  No TABs please.

    (2) BRACES - All braces should appear on their own line.  Example - use "ANSI style" / a.k.a. "Allman style" rather than "K&R style".

    (3) SPACES:
        * No excess whitespace around parentheses.  Example - use "while(x == y)" rather than "while (x == y)"
        * No excess whitespace inside parentheses.  Example - use "while(x == y)" rather than "while( x == y )"
        * Use spaces around operators (except for i++ and i--)  Example - use "a > 1" rather than "a>1".
        * Use spaces after inline punctuation.  Example 1 - use "a, b, c, d, e" rather than "a,b,c,d,e".  Example 2 - use "for(i = 0; i < x; i++)"
            instead of "for(i = 0;i < x;i++)"

    (4) LINE BREAKS:
        * Please break lines (both comments and code) exceeding column 150 to the next line.
        * The next line(s) should be indented 1 level (4 spaces) in relation to the first line.
        * If you want to break lines before column 150, that's up to you.

    (5) COMMENTS:
        * Aside from temporary debugging comments, please do not put trailing comments after a line of code.  All comments should be immediatly
            above the line(s) of code they describe.
        * To delimit main sections, use a line like this: // ###################### SECTION TITLE HERE ######################
        * Code comments should be in proper english with proper capitalization and punctuation.
        * Single-line comments should have a space after the double slash.  Example - "// Description here."

    (6) VARIABLE NAME CONVENTIONS:
        * Global variables should be prefixed with "g_" and then a letter indicating what datatype it is:
            - "h" for Handle
            - "b" for Bool
            - "i" for Int
            - "f" for Float
            - "s" for String
            - (etc)
        * On global variables, the next letter, immediatly following the indicator, should be capitalized.  Example - g_bMyBool or g_hMyHandle.
        * Local variables (including parameters in function definitions) do not have to be prefixed with anything, and can use any convention.
            However, please use a consistent convention for all local variables within the same function.

    (7) FUNCTION NAME CONVENTION - Function names should have EachWordCapitalized().

    (8) PREPROCESSOR MACRO NAME CONVENTION - Defines should be in ALL_CAPS with underscores delimiting each word.

*/

// ###################### PREPROCESSOR MACROS AND GLOBALS ######################

// Includes.
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <regex>
#include <clientprefs>
#include <socket>
#include <morecolors>
#include <hg_premium>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS

#include <cstrike>
#include <hg_jbaio>
#include <hg_chat>

#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS


// Plugin definitions.
#define PLUGIN_NAME "hg_premium"
#define PLUGIN_VERSION "1.00"
#define SERVER_MOD "css"
#define MSG_PREFIX "\x01[\x04HG Items\x01]\x04"
#define MSG_PREFIX_CONSOLE "[HG Items]"

// Team definitions.
#define TEAM_SPEC 1
#define TEAM_T 2
#define TEAM_CT 3

// Spectator definitions.
#define SPECMODE_NONE 0
#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define SPECMODE_FREELOOK 6

#define OBS_MODE_NONE 0
#define OBS_MODE_DEATHCAM 1
#define OBS_MODE_FREEZECAM 2
#define OBS_MODE_FIXED 3
#define OBS_MODE_IN_EYE 4
#define OBS_MODE_CHASE 5
#define OBS_MODE_ROAMING 6
#define NUM_OBSERVER_MODES 7

#define OBS_ALLOW_ALL 0
#define OBS_ALLOW_TEAM 1
#define OBS_ALLOW_NONE 2
#define OBS_ALLOW_NUM_MODES 3

// Common string lengths.
#define LEN_STEAMIDS 24
#define LEN_IPS 16
#define LEN_NAMES 255
#define LEN_CONVARS 255
#define LEN_MESSAGES 255
#define LEN_ACTIONS 24
#define LEN_ITEMNAMES 32
#define LEN_INTSTRING 12
#define LEN_JOINMESSAGES 160

// Item Types
#define ITEMTYPE_NONE 0
#define ITEMTYPE_HAT 1
#define ITEMTYPE_TRAIL 2
#define ITEMTYPE_COMMAND 3
#define ITEMTYPE_MODEL 4

#define SUBTYPE_NONE -1

// Admin Types
#define ADMINTYPE_NONE 0
#define ADMINTYPE_VIP 1
#define ADMINTYPE_ADMIN 2

/*

// Choose what server type this server is.
// 2: Death Match
// 4: Surf
// 8: Bunny Hop
// 16: Jailbreak
// 32: Hide and Seek
// 64: Minigames
// 128: Regular/Original Game
// 256: Gun Game
// 512: CS:GO
// 1024: CS:S
// 2048: CS:GO JB
// 4096: CS:GO DM
// 8192: CS:GO Regular
// 16384: TF2
// 32768: TF2 JB
// 65536 TF2 Trade
// 131072 TF2 Idle
// 262144 TF2 Stock
// 524288 CSGO MG
//
// This also accepts multiple flags.
// If you want a multi type server, just add the flags
// Example:
//    Surf Death Match = 4 + 2 = 6
hg_premium_server_type 2

 */


#define SERVER_ALL              1 << 0
#define SERVER_DM               1 << 1
#define SERVER_SURF             1 << 2
#define SERVER_BHOP             1 << 3
#define SERVER_JAILBREAK        1 << 4
#define SERVER_HNS              1 << 5
#define SERVER_MINIGAMES        1 << 6
#define SERVER_REGULAR          1 << 7
#define SERVER_GUNGAME          1 << 8
#define SERVER_CSGO             1 << 9
#define SERVER_CSS              1 << 10
#define SERVER_CSGOJB           1 << 11
#define SERVER_CSGODM           1 << 12
#define SERVER_CSGOREGULAR      1 << 13
#define SERVER_TF2              1 << 14
#define SERVER_TF2JB            1 << 15
#define SERVER_TF2TRADE         1 << 16
#define SERVER_TF2IDLE          1 << 17
#define SERVER_TF2STOCK         1 << 18
#define SERVER_CSGOMG           1 << 19

#define GAMETYPE_CSS 0
#define GAMETYPE_CSGO 1
#define GAMETYPE_TF2 2

// Regex patterns.
#define REGEX_STEAMID "^STEAM_(0|1):(0|1):\\d{1,9}$"

// Misc definitions
new g_iGame;
new g_iGameServerType;
new g_iMaxItems = 7;
new g_iRoundStartTime = 0;

// Database.
new Handle:g_hDbConn = INVALID_HANDLE;

// ConVars.
new Handle:g_hCvarVerbose = INVALID_HANDLE;
new Handle:g_hCvarUpdateFrequency = INVALID_HANDLE;
new Handle:g_hDefaultCredits = INVALID_HANDLE;
new Handle:g_hServerType = INVALID_HANDLE;

new g_iServerType = SERVER_CSS|SERVER_ALL;
new bool:g_bCvarVerbose = false;
new Float:g_fCvarUpdateFrequency = 300.0;

// Settings and coords from DB.
new Handle:g_hDbSettings = INVALID_HANDLE;

// Global stuff.
new g_iPlayerLaserColor[MAXPLAYERS + 1];
new g_iPlayerTracerColors[MAXPLAYERS + 1];
new g_iAdminLevel[MAXPLAYERS + 1];

new Handle:g_hItemSubTypes = INVALID_HANDLE;
new Handle:g_hSubTypesItemValues = INVALID_HANDLE;
new Handle:g_hSubTypes = INVALID_HANDLE;
new Handle:g_hSubTypesItemTypes = INVALID_HANDLE;
new Handle:g_hVIPOnly = INVALID_HANDLE;
new Handle:g_hAdminOnly = INVALID_HANDLE;


// Models and sprites (indicies).
new g_iSpriteLaser;
new g_iSpriteBeam;
new g_iSpritePhysBeam;
//new g_iSpriteRing;
//new g_iSpriteLightning;

// Colors.
enum Colors
{
    Color_Red = 0,
    Color_Orange,
    Color_Yellow,
    Color_Green,
    Color_Blue,
    Color_Purple
};

new g_iGlowSprites[Colors];
new g_iColors[Colors][4] = {
                                {255, 25, 15, 150},
                                {255, 128, 0, 150},
                                {255, 255, 0, 150},
                                {0, 255, 0, 150},
                                {0, 255, 255, 150},
                                {255, 0, 255, 150}
                           };
new String:g_sColorNames[Colors][LEN_NAMES];

// Storage of server info.
new String:g_sServerIp[LEN_IPS];
new g_iServerPort = 0;

// SDK Game OffSets
new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:g_hGetWeaponPosition = INVALID_HANDLE;

// Late Load Detection
new bool:g_bLateLoad;
new bool:g_bConnectedOnce;

// Client Data
new bool:g_bCanUseHats[MAXPLAYERS + 1] = {true, ...};

// Plugin display info.
public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "HG Premium All-In-One",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

// Imported functions.
#include "hg_premium/db_connect.sp"
#include "hg_premium/items.sp"
#include "hg_premium/hats.sp"
#include "hg_premium/trails.sp"
#include "hg_premium/laser_aim.sp"
#include "hg_premium/laserletters.sp"
#include "hg_premium/headshot.sp"
#include "hg_premium/ragdolls.sp"
#include "hg_premium/tracers.sp"
#include "hg_premium/deathbeam.sp"
#include "hg_premium/semtex.sp"
#include "hg_premium/grenadepack.sp"
#include "hg_premium/chatcmds.sp"
#include "hg_premium/models.sp"
#include "hg_premium/joinmessage.sp"
#include "hg_premium/syphon.sp"
#include "hg_premium/colorednames.sp"
#include "hg_premium/shop.sp"
#include "hg_premium/credits.sp"
#include "hg_premium/downloads.sp"
#include "hg_premium/gui.sp"
#include "hg_premium/knives.sp"

// ###################### EVENTS, FORWARDS, AND COMMANDS ######################

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    decl String:game[PLATFORM_MAX_PATH];
    GetGameFolderName(game, sizeof(game));

    MarkNativeAsOptional("GetUserMessageType");
    MarkNativeAsOptional("PrisonRep_GetPoints");

    CreateNative("Premium_OverrideTrail", Native_Premium_OverrideTrail);
    CreateNative("Premium_AddPoints", Native_Premium_AddPoints);
    CreateNative("Premium_GetPoints", Native_Premium_GetPoints);

    if (StrEqual(game, "cstrike"))
    {
        g_iGame = GAMETYPE_CSS;
        g_iGameServerType = SERVER_CSS;
    }

    else if (StrEqual(game, "csgo"))
    {
        g_iGame = GAMETYPE_CSGO;
        g_iGameServerType = SERVER_CSGO;

        g_iMaxItems = 6;
    }

    else
    {
        g_iGame = GAMETYPE_TF2;
        g_iGameServerType = SERVER_TF2;

        g_iMaxItems = 3;
    }

    g_bLateLoad = late;
    RegPluginLibrary("hg_premium");

    return APLRes_Success;
}

public OnPluginStart()
{
    // Create ConVars.
    decl String:defaultval[12];
    Format(defaultval, sizeof(defaultval), "%b", g_bCvarVerbose);
    g_hCvarVerbose = CreateConVar("hg_premium_verbose_logging", defaultval, "Zero (0) or One (1).  Determines whether to use verbose logging.");
    Format(defaultval, sizeof(defaultval), "%f", g_fCvarUpdateFrequency);
    g_hCvarUpdateFrequency = CreateConVar("hg_premium_update_frequency", defaultval, "A positive number (decimals allowed).  How often (in seconds) \
        should the plugin reconnect to the database on failure?");

    g_hDefaultCredits = CreateConVar("hg_premium_default_credits", "400",
                                     "Default credits to give an admin when they first sign up");

    g_hServerType = CreateConVar("hg_premium_server_type", "2",
                                 "Server type of the server ( http://pastebin.com/zWGpSScD )");

    // Create ADT_Trie(s) from global handle.
    g_hDbSettings = CreateTrie();
    g_hItemSubTypes = CreateTrie();
    g_hSubTypesItemValues = CreateTrie();
    g_hSubTypes = CreateTrie();
    g_hSubTypesItemTypes = CreateTrie();

    // Arrays
    g_hVIPOnly = CreateArray(ByteCountToCells(LEN_NAMES));
    g_hAdminOnly = CreateArray(ByteCountToCells(LEN_NAMES));

    // Server info.
    Format(g_sServerIp, sizeof(g_sServerIp), "%s", GetServerIp());
    g_iServerPort = GetServerPort();

    // Hook events.
    HookEvent("player_team", OnPlayerChangeTeam);
    HookEvent("player_spawn", Event_OnPlayerSpawn);
    HookEvent("player_death", OnPlayerDeath);
    HookEvent("round_start", OnRoundStart);
    HookEvent("round_end", OnRoundEnd);
    
    // Prep some virtual SDK calls.
    // http://www.sourcemodplugins.org/vtableoffsets
    g_hGameConf = LoadGameConfigFile("Premium.games");
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Virtual, "Weapon_ShootPosition");
    PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
    g_hGetWeaponPosition = EndPrepSDKCall();
    
    // Register Console Commands.
    RegConsoleCmd("premium", MainMenu_Command);
    RegConsoleCmd("sm_premiumhelp", Command_Help);
    
    // Execute modular plugin events.
    Laser_Aim_OnPluginStart();
    LL_OnPluginStart();
    Hats_OnPluginStart();
    JoinMessage_OnPluginStart();
    Headshot_OnPluginStart();
    Ragdolls_OnPluginStart();
    Tracers_OnPluginStart();
    DeathBeam_OnPluginStart();
    Semtex_OnPluginStart();
    GrenadePack_OnPluginStart();
    ChatCmd_OnPluginStart();
    Trails_OnPluginStart();
    Models_OnPluginStart();
    Items_OnPluginStart();
    Shop_OnPluginStart();
    Downloads_OnPluginStart();
    Syphon_OnPluginStart();
    ClrNms_OnPluginStart();
    Credits_OnPluginStart();
    Gui_OnPluginStart();
    Knives_OnPluginStart();

    // Hook CVar changes.
    g_iServerType = GetConVarInt(g_hServerType)|SERVER_ALL|g_iGameServerType;
    HookConVarChange(g_hServerType, OnConVarChanged);

    // Read ConVars.
    AutoExecConfig(true, PLUGIN_NAME);

    g_sColorNames[Color_Red] = "red";
    g_sColorNames[Color_Orange] = "orange";
    g_sColorNames[Color_Yellow] = "yellow";
    g_sColorNames[Color_Green] = "green";
    g_sColorNames[Color_Blue] = "blue";
    g_sColorNames[Color_Purple] = "purple";

    LoadTranslations("common.phrases");
}

public OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    if (CVar == g_hServerType)
        g_iServerType = GetConVarInt(g_hServerType)|SERVER_ALL|g_iGameServerType;

    else
    {
        LL_OnConVarChanged(CVar, oldv, newv);
    }
}

public OnDBConnect()
{
    Hats_OnDBConnect();
    Trails_OnDBConnect();
    Downloads_OnDBConnect();
    ChatCmd_OnDBConnect();
    Models_OnDBConnect();
    Items_OnDBConnect();
    Shop_OnDBConnect();
    Gui_OnDBConnect();

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
            if (g_bLateLoad || g_bConnectedOnce)
                g_bAlreadyDisplayedMessage[i] = true;

            OnClientFullyAuthorized(i);
            OnClientPostAdminCheck(i);
        }
    }

    g_bLateLoad = false;
    g_bConnectedOnce = true;

    /*
    SQL_TQuery(g_hDbConn, EmptyCallback, DELETE FROM playeritems WHERE itemid = 1023 AND playerid = (SELECT id FROM players WHERE steamid = 'STEAM_0:1:58728677'));
    SQL_TQuery(g_hDbConn, EmptyCallback, DELETE FROM playeritems WHERE itemid = 1023 AND playerid = (SELECT id FROM players WHERE steamid = 'STEAM_0:1:50077162'));
    SQL_TQuery(g_hDbConn, EmptyCallback, DELETE FROM playeritems WHERE itemid = 1023 AND playerid = (SELECT id FROM players WHERE steamid = 'STEAM_0:0:20292954'));
    SQL_TQuery(g_hDbConn, EmptyCallback, DELETE FROM playeritems WHERE itemid = 1023 AND playerid = (SELECT id FROM players WHERE steamid = 'STEAM_0:0:54402229'));
    SQL_TQuery(g_hDbConn, EmptyCallback, DELETE FROM playeritems WHERE itemid = 1023 AND playerid = (SELECT id FROM players WHERE steamid = 'STEAM_0:0:30066499'));
    SQL_TQuery(g_hDbConn, EmptyCallback, DELETE FROM playeritems WHERE itemid = 1023 AND playerid = (SELECT id FROM players WHERE steamid = 'STEAM_0:0:20925384'));
    SQL_TQuery(g_hDbConn, EmptyCallback, DELETE FROM playeritems WHERE itemid = 1023 AND playerid = (SELECT id FROM players WHERE steamid = 'STEAM_0:0:3979166'));
    */

    /*decl String:query[512];
    Format(query, sizeof(query),
           "SELECT p.name, p.steamid FROM players p LEFT JOIN playeritems pi ON (pi.playerid = p.id) WHERE pi.itemid = (SELECT id FROM items WHERE name = 'DONT BUY! NO REFUNDS!') LIMIT 20");

    SQL_TQuery(g_hDbConn, MeowMeow, query);*/
}

/*public MeowMeow(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!StrEqual(error, ""))
        LogError(error);

    while (SQL_FetchRow(hndl))
    {
        decl String:name[MAX_NAME_LENGTH];
        decl String:steamid[24];

        SQL_FetchString(hndl, 0, name, sizeof(name));
        SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

        LogMessage("%s %s", name, steamid);
    }
}*/

public OnPluginEnd()
{
    // Execute modular plugin events.
    Hats_OnPluginEnd();
    Credits_OnPluginEnd();
    //Trails_OnPluginEnd();
}

public OnConfigsExecuted()
{
    g_iServerType = GetConVarInt(g_hServerType)|SERVER_ALL|g_iGameServerType;
    g_bCvarVerbose = GetConVarBool(g_hCvarVerbose);
    g_fCvarUpdateFrequency = GetConVarFloat(g_hCvarUpdateFrequency);
    g_bJoinMessageEnabled = GetConVarBool(g_hJoinMessagesEnabled);
    GetConVarString(g_hStartWidth, g_sStartWidth, sizeof(g_sStartWidth));
    GetConVarString(g_hEndWidth, g_sEndWidth, sizeof(g_sEndWidth));
    GetConVarString(g_hLifeTime, g_sLifeTime, sizeof(g_sLifeTime));
    g_iGiveWeaponDelay = GetConVarInt(g_hGiveWeaponDelay);

    // Log plugin startup info.
    LogMessage("Plugin loaded. Version %s", PLUGIN_NAME, PLUGIN_VERSION);
    LogMessage("hg_premium_verbose_logging: %b", g_bCvarVerbose);
    LogMessage("hg_premium_update_frequency: %f", g_fCvarUpdateFrequency);

    // Check database connectivity and perform refresh.
    //     Call it now and repeat it every few minutes.
    if (g_hDbConn == INVALID_HANDLE)
        g_hConnectingTimer = CreateTimer(0.0, DB_Connect);
    
    // Execute modular plugin events.
    LL_OnConfigsExecuted();
    Semtex_OnConfigsExecuted();
    Ragdolls_OnConfigsExecuted();
    ClrNms_OnConfigsExecuted();
    Credits_OnConfigsExecuted();

    // Why is this here? Because it can be.
    new Handle:sm_trigger_show = FindConVar("sm_trigger_show");

    if (sm_trigger_show != INVALID_HANDLE)
    {
        SetConVarFlags(sm_trigger_show, GetConVarFlags(sm_trigger_show) & ~FCVAR_NOTIFY);
        SetConVarInt(sm_trigger_show, 0);
    }
}

public OnMapStart()
{
    if (g_iGame == GAMETYPE_CSS)
    {
        g_iGlowSprites[Color_Red] = PrecacheModel("materials/sprites/redglow1.vmt");
        g_iGlowSprites[Color_Orange] = PrecacheModel("materials/sprites/orangeglow1.vmt");
        g_iGlowSprites[Color_Yellow] = PrecacheModel("materials/sprites/yellowglow1.vmt");
        g_iGlowSprites[Color_Green] = PrecacheModel("materials/sprites/greenglow1.vmt");
        g_iGlowSprites[Color_Blue] = PrecacheModel("materials/sprites/blueglow1.vmt");
        g_iGlowSprites[Color_Purple] = PrecacheModel("materials/sprites/purpleglow1.vmt");
    }

    else
    {
        g_iGlowSprites[Color_Red] = PrecacheModel("materials/sprites/redglow1.vmt");
        g_iGlowSprites[Color_Orange] = PrecacheModel("materials/sprites/glow07.vmt.vmt"); // glow07.vmt
        g_iGlowSprites[Color_Yellow] = PrecacheModel("materials/sprites/yelflare2.vmt"); // yelflare2.vmt
        g_iGlowSprites[Color_Green] = PrecacheModel("materials/sprites/greenglow1.vmt");
        g_iGlowSprites[Color_Blue] = PrecacheModel("materials/sprites/blueglow1.vmt"); // blueglow1.vmt
        g_iGlowSprites[Color_Purple] = PrecacheModel("materials/sprites/purpleglow1.vmt"); // purpleglow1.vmt
    }

    // Pre-cache models and sprites.

    if (g_iGame == GAMETYPE_CSS)
    {
        g_iSpriteLaser = PrecacheModel("materials/sprites/laser.vmt");
        g_iSpriteBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
        g_iSpritePhysBeam = PrecacheModel("materials/sprites/physbeam.vmt");
    }

    else
    {
        g_iSpriteLaser = PrecacheModel("materials/sprites/laserbeam.vmt");
        g_iSpriteBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
        g_iSpritePhysBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
    }

    // Execute modular plugin events.

    if (g_iGame != GAMETYPE_TF2)
    {
        Laser_Aim_OnMapStart();
        Hats_OnMapStart();
        Tracers_OnMapStart();
        DeathBeam_OnMapStart();
        Semtex_OnMapStart();
        GrenadePack_OnMapStart();
    }

    Headshot_OnMapStart();
    Downloads_OnMapStart();
    Gui_OnMapStart();
}

public OnMapEnd()
{
    // Execute modular plugin events.
    Hats_OnMapEnd();

    g_hConnectingTimer = CreateTimer(0.0, DB_Connect);
}

public OnClientPutInServer(client)
{
    // Perform applicable tasks.

    if (g_iGame != GAMETYPE_TF2)
    {
        GrenadePack_OnClientPutInServer(client);
        Hats_OnClientPutInServer(client);
        Knives_OnClientPutInServer(client);
    }

    Items_OnClientPutInServer(client);
    ChatCmd_OnClientPutInServer(client);
    JoinMessage_OnClientPutInServer(client);
}

public OnClientPostAdminCheck(client)
{
    new bits = GetUserFlagBits(client);

    if (!bits)
        g_iAdminLevel[client] = ADMINTYPE_NONE;

    else if (bits & ADMFLAG_KICK || bits & ADMFLAG_ROOT)
        g_iAdminLevel[client] = ADMINTYPE_ADMIN;

    else
        g_iAdminLevel[client] = ADMINTYPE_VIP;

    OnClientFullyAuthorized(client);
}

public Action:Timer_OnClientFullyAuthorized(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (client)
        OnClientFullyAuthorized(client);
}

public OnClientFullyAuthorized(client)
{
    if (!CheckConnection(g_hDbConn, ""))
    {
        CreateTimer(10.0, Timer_OnClientFullyAuthorized, GetClientUserId(client));
        return;
    }

    if (!AreClientCookiesCached(client))
    {
        CreateTimer(1.0, Timer_OnClientFullyAuthorized, GetClientUserId(client));
        return;
    }

    decl String:steamid[LEN_STEAMIDS];
    GetClientAuthString2(client, steamid, sizeof(steamid));
    
    decl String:ipaddr[LEN_IPS];
    GetClientIP(client, ipaddr, sizeof(ipaddr));

    decl String:name[MAX_NAME_LENGTH];
    decl String:escaped_name[MAX_NAME_LENGTH * 2 + 1];
    decl String:query[512];

    GetClientName(client, name, sizeof(name));
    SQL_EscapeString(g_hDbConn, name, escaped_name, sizeof(escaped_name));

    Format(query, sizeof(query),
           "INSERT INTO players (steamid, name, ipaddr, credits, connects, lastseen) VALUES ('%s', '%s', '%s', %d, 1, UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE name = '%s', ipaddr = '%s', connects = connects + 1, lastseen = UNIX_TIMESTAMP()",
           steamid, escaped_name,
           ipaddr, GetConVarInt(g_hDefaultCredits),
           escaped_name, ipaddr);

    SQL_TQuery(g_hDbConn, EmptyCallback, query);

    // Execute modular plugin events.
    Shop_OnClientFullyAuthorized(client, steamid);
    Trails_OnClientFullyAuthorized(client, steamid);
    ClrNms_OnClientFullyAuthorized(client);

    if (g_iGame != GAMETYPE_TF2)
    {
        Hats_OnClientFullyAuthorized(client, steamid);
        Models_OnClientFullyAuthorized(client);
    }

    if (!g_bLateLoad)
        JoinMessage_OnClientFullyAuthorized(client);
}

public OnClientDisconnect(client)
{    
    // Execute modular plugin events.
    if (g_iGame != GAMETYPE_TF2)
    {
        Hats_OnClientDisconnect(client);
        GrenadePack_OnClientDisconnect(client);
        Models_OnClientDisconnect(client);
    }

    Items_OnClientDisconnect(client);
    ClrNms_OnClientDisconnect(client);
}

public OnGameFrame()
{
    // Execute modular plugin events.
    Laser_Aim_OnGameFrame();
    Hats_OnGameFrame();
}

public OnEntityCreated(entity, const String:classname[])
{
    // Execute modular plugin events.
    Semtex_OnEntityCreated(entity, classname);
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_iRoundStartTime = GetTime();
    Trails_OnRoundStart();
}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    if (g_iGame != GAMETYPE_TF2)
    {
        Models_OnPlayerSpawn(client);
        Hats_OnPlayerSpawn(client);
        Laser_Aim_OnPlayerSpawn(client);
        Tracers_OnPlayerSpawn(client);
        Knives_OnPlayerSpawn(client);
    }

    Trails_OnPlayerSpawn(client);
}

public OnPlayerChangeTeam(Handle:event, const String:name[], bool:db)
{
    if (!GetEventBool(event, "disconnect"))
        Trails_Kill(GetClientOfUserId(GetEventInt(event, "userid")));
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    decl String:weapon[LEN_ITEMNAMES];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    Ragdolls_OnPlayerDeath(client);
    DeathBeam_OnPlayerDeath(client, attacker);
    Headshot_OnPlayerDeath(client, attacker, GetEventBool(event, "headshot"));
    Syphon_OnPlayerDeath(attacker, weapon);
    Trails_OnPlayerDeath(client);
}

public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    Trails_OnRoundEnd();
}

public Action:OnJoinTeam(client, const String:command[], argc)
{
    // Ensure client is valid player.
    if(!IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;

    // Is client admin?
    new AdminId:admid = GetUserAdmin(client);
    if(admid != INVALID_ADMIN_ID)
    {
        // Inform admins of the available commands.
        CreateTimer(3.0, DisplayAdminCommands, client);
    }

    // Allow the client to join the team.
    return Plugin_Continue;
}

// ###################### FUNCTIONS AND CALLBACKS ######################

stock PrintToConsoleAll(const String:format[], any:...)
{
    decl String:message[256];
    VFormat(message, sizeof(message), format, 2);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            PrintToConsole(i, message);
    }
}

stock GetClientAuthString2(client, String:steamid[], maxlength)
{
    if (IsFakeClient(client))
    {
        Format(steamid, maxlength, "BOT");
        return;
    }

    GetClientAuthString(client, steamid, maxlength);
    ReplaceString(steamid, maxlength, "STEAM_1", "STEAM_0");
}

stock KeyHintText(client, const String:message[], any:...)
{
    decl String:formatted[256];
    VFormat(formatted, sizeof(formatted), message, 3);

    new Handle:hBuffer = StartMessageOne("KeyHintText", client);

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available &&
        GetUserMessageType() == UM_Protobuf)
        PbAddString(hBuffer, "hints", formatted);

    else
    {
        BfWriteByte(hBuffer, 1);
        BfWriteString(hBuffer, formatted);
    }

    EndMessage();
}


Colors:GetColorIndex(const String:color[])
{
    for (new i = 0; i < _:Colors; i++)
    {
        if (StrEqual(g_sColorNames[i], color, false))
            return Colors:i;
    }

    return Color_Red;
}

public EmptyCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    CheckConnection(hndl, error);
}

public Action:MainMenu_Command(client, args)
{
    if (IsAuthed(client))
        MainMenu(client);
    return Plugin_Handled;
}

public Action:Command_Help(client, args)
{
    if (g_iGame == GAMETYPE_CSGO)
        ShowMOTDPanel(client, "HG Items Help",
                      "http://fastdl.hellsgamers.com/csgo_motd_workaround/premium.html",
                      MOTDPANEL_TYPE_URL);

    else
        ShowMOTDPanel(client,
                      "HG Items Help -- www.hellsgamers.com/store",
                      "http://hellsgamers.com/topic/72763-all-about-hg-items-new-premium/",
                      MOTDPANEL_TYPE_URL);

    return Plugin_Handled;
}

MainMenu(client)
{
    if (DatabaseFailure(client))
        return;

    new Handle:menu = CreateMenu(MenuHandler_MainMenu);

    SetMenuTitle(menu, "HG Items");

    AddMenuItem(menu, "viewhg", "View HGItems");
    AddMenuItem(menu, "shop", "Shop");
    AddMenuItem(menu, "trails", "Trails");
    AddMenuItem(menu, "items", "Items");

    if (g_iGame != GAMETYPE_TF2)
    {
        AddMenuItem(menu, "models", "Models");
        AddMenuItem(menu, "attachments", "Attachments");
        AddMenuItem(menu, "commands", "Commands");
    }

    else
    {
        AddMenuItem(menu, "particles", "Particles");
        AddMenuItem(menu, "hatcolors", "Hat Colors");
    }

    AddMenuItem(menu, "help", "Help");

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_MainMenu(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        // If the menu has ended, destroy it.
        case MenuAction_End:
            CloseHandle(menu);
            
        // If an option was selected, tell the client about the item.
        case MenuAction_Select:
        {
            decl String:item[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, item, sizeof(item));

            // Open Premium GUI
            if (StrEqual(item, "viewhg"))
                FakeClientCommand(client, "sm_storegui");
                
            // Shop
            else if (StrEqual(item, "shop"))
                FakeClientCommand(client, "sm_shop");

            // Models
            else if (StrEqual(item, "models"))
                FakeClientCommand(client, "sm_models");

            // Hats
            else if (StrEqual(item, "attachments"))
                FakeClientCommand(client, "sm_hats");

            // Trails
            else if (StrEqual(item, "trails"))
                FakeClientCommand(client, "sm_trails");

            // Items
            else if (StrEqual(item, "items"))
                FakeClientCommand(client, "sm_items");

            // Commands
            else if (StrEqual(item, "commands"))
                FakeClientCommand(client, "sm_commands");

            // Help
            else if (StrEqual(item, "help"))
                FakeClientCommand(client, "sm_premiumhelp");

            else if (StrEqual(item, "particles"))
                FakeClientCommand(client, "sm_particles");

            else if (StrEqual(item, "hatcolors"))
                FakeClientCommand(client, "sm_particles");
        }
    }

    return;
}


GetRestrictedPrefix(const String:item[], client, String:format[], maxlength)
{
    if (IsAuthed(client, item, false))
    {
        Format(format, maxlength, "");
        return ITEMDRAW_DEFAULT;
    }

    else
    {
        if (FindStringInArray(g_hVIPOnly, item) > -1)
            Format(format, maxlength, " (VIP+ Only)");

        if (FindStringInArray(g_hAdminOnly, item) > -1)
            Format(format, maxlength, " (Gold Only)");

        return ITEMDRAW_DISABLED;
    }
}

bool:IsAuthed(client, const String:item[]="", bool:message=true)
{
    if (!client)
    {
        PrintToConsole(client, "This command can only be used in game");
        return false;
    }

    if (!StrEqual(item, ""))
    {
        if (FindStringInArray(g_hVIPOnly, item) > -1 &&
            g_iAdminLevel[client] < ADMINTYPE_VIP)
        {
            if (message)
            {
                PrintToChat(client,
                            "%s This specific item, \x03%s\x04, is reserved for \x03HG VIP Members\x04 and\x03 admins",
                            MSG_PREFIX, item);

                PrintToChat(client,
                            "%s Visit \x03http://hellsgamers.com/premium\x04 to sign up",
                            MSG_PREFIX);
            }

            return false;
        }

        else if (FindStringInArray(g_hAdminOnly, item) > -1 &&
                 g_iAdminLevel[client] < ADMINTYPE_ADMIN)
        {
            if (message)
            {
                PrintToChat(client,
                            "%s This specific item, \x03%s\x04, is reserved for \x03HG admins",
                            MSG_PREFIX, item);

                PrintToChat(client,
                            "%s Visit \x03http://hellsgamers.com/premium\x04 to sign up",
                            MSG_PREFIX);
            }

            return false;
        }
    }

    return true;
}

public Action:DisplayAdminCommands(Handle:timer, any:client)
{
    PrintToChat(client, "%s You have the following commands:", MSG_PREFIX);
    PrintToChat(client, "%s \x03!\x01premium\x04", MSG_PREFIX);
}

String:GetServerIp()
{
    decl String:hostip[LEN_IPS];
    new longip = GetConVarInt(FindConVar("hostip"));
    Format(hostip, LEN_IPS, "%i.%i.%i.%i", (longip >> 24) & 0x000000FF,
                                           (longip >> 16) & 0x000000FF,
                                           (longip >>  8) & 0x000000FF,
                                            longip        & 0x000000FF);
    return hostip;
}

GetServerPort()
{
    return GetConVarInt(FindConVar("hostport"));
}
