// fx7c has 
// fx8 has 1266
// fx8c has 1386 entities

/*
To do:
    reserved slot - connect extension - https://forums.alliedmods.net/showthread.php?t=162489

    put back rep for idling in CS:S and CS:GO once population is steady
    find (two?) new PD options for TF2.
    IP Tlist

    Find a way to get the entity classname in OnPlayerDeath instead of the log name. Maybe cache the last weapon they were hurt with in OnTakeDamaage.
*/

// ###################### GLOBALS ######################

// Includes.
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <regex>
#include <clientprefs>
#include <sdkhooks>
#include <hg_jbaio>
#include <morecolors>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN

#include <cstrike>
#include <tf2>
#include <tf2items>
#include <tf2_stocks>
#include <tf2attributes>
#include <throwingknives>
#include <steamworks>
#include <dhooks>
#include <hg_premium>
#include <sendproxy>

#define REQUIRE_EXTENSIONS
#define REQUIRE_PLUGIN

// Plugin definitions.
#define PLUGIN_NAME "hg_jbaio"
#define PLUGIN_VERSION "3.0.0"
#define SERVER_MOD "css"
#define MSG_PREFIX "\x01[\x04HG JB\x01]\x04"
#define MSG_PREFIX_CONSOLE "[HG JB]"

// Legacy macros
#define GAMETYPE_NONE   JB_GAMETYPE_NONE
#define GAMETYPE_CSS    JB_GAMETYPE_CSS
#define GAMETYPE_CSGO   JB_GAMETYPE_CSGO
#define GAMETYPE_TF2    JB_GAMETYPE_TF2
#define GAMETYPE_ALL    JB_GAMETYPE_ALL

// Common string lengths.
#define LEN_STEAMIDS 24
#define LEN_IPS 17
#define LEN_CONVARS 255
#define LEN_INTSTRING 13 // Max val of signed 32-bit int is 2 billion something (12 places) +1 for null term
#define LEN_ITEMNAMES 48
#define LEN_HEXUUID 42
#define LEN_MAPCOORDS 64
#define LEN_COLOREDNAMES 124
#define LEN_VEC 3
#define LEN_RGBA 4

// Rebel definitions.
#define REBELTYPE_HURT 0
#define REBELTYPE_KILL 1
#define REBELTYPE_SHOOT 2
#define REBELTYPE_TELE 3

// Team definitions.
#define TEAM_UNASSIGNED 0
#define TEAM_SPEC 1
#define TEAM_PRISONERS 2
#define TEAM_GUARDS 3

// Menu definitions.
#define PERM_DURATION -1
#define MENU_TIMEOUT_NORMAL 30
#define MENU_TIMEOUT_QUICK 2

// Protected (from dL+) definitions.
#define MAX_REP_TRANSFER_PER_DAY 25000

// TF2 Shit
#define TF2_BAT 0
#define TF2_BOTTLE 1
#define TF2_KUKRI 3
#define TF2_SHOTGUN 9
#define TF2_SCATTERGUN 13
#define TF2_SNIPER 14
#define TF2_MINIGUN 15
#define TF2_SMG 16
#define TF2_SCOUT_PISTOL 23
#define TF2_SANDMAN 44
#define TF2_HUNTSMAN 56
#define TF2_MACKEREL 221
#define TF2_CABER 307
#define TF2_BRASS_BEAST 312
#define TF2_APOCO_FISTS 587
#define TF2_COZYCAMPER 642
#define TF2_WRAPASSASSIN 648
#define TF2_FLYING_GUILLOTINE 812

// TF2 stuff
new g_iMaxPrimaryClip[MAXPLAYERS + 1];
new g_iMaxPrimaryAmmo[MAXPLAYERS + 1];
new g_iMaxSecondaryClip[MAXPLAYERS + 1];
new g_iMaxSecondaryAmmo[MAXPLAYERS + 1];

new bool:g_bHasUber[MAXPLAYERS + 1];
new bool:g_bHasKritz[MAXPLAYERS + 1];

new Float:g_fPlayerSpeed[MAXPLAYERS + 1] = {300.0, ...};
new Float:g_fDefaultSpeed[10] = {0.0, 400.0, 300.0, 240.0, 280.0, 320.0, 230.0, 300.0, 300.0, 300.0};

new Handle:g_hAmmoPackPercentage = INVALID_HANDLE;
new Handle:g_hAmmoPackType = INVALID_HANDLE;

new String:g_sLastHurtBy[MAXPLAYERS + 1][LEN_ITEMNAMES];

// For passing info into menu CB.
new g_iCmdMenuCategories[MAXPLAYERS + 1];
new g_iCmdMenuDurations[MAXPLAYERS + 1];
new String:g_sCmdMenuReasons[MAXPLAYERS + 1][LEN_CONVARS];

// End-of-round slay timer.
new Handle:g_hRoundEndSlayTimer = INVALID_HANDLE;           // Timer (non-repeating) that delays a certain amount each round before slaying all living players.

// Gameplay type globals.
#define ENDGAME_NONE 0                                      // It's normal play
#define ENDGAME_LR 1                                        // It's LR time
#define ENDGAME_LASTGUARD 2                                 // It's "Last Guard" time
#define ENDGAME_WARDAY 3                                    // It's a War Day
#define ENDGAME_300DAY 4                                    // It's a 300 Day
new g_iEndGame;

// Cell tracking globals.
new bool:g_bAreCellsOpened = false;
new Handle:g_hServerOpenCellsTimer = INVALID_HANDLE;

// Rebel tracking globals.
new bool:g_bIsInvisible[MAXPLAYERS + 1];                    // NOTE: Rebeltracking considers invisible players to be rebels
new bool:g_bIsRebelFromEChair[MAXPLAYERS + 1];
new Handle:g_hMakeNonRebelTimers[MAXPLAYERS + 1];           // Array of timers for making a person not a rebel any more

// Name change spam trackers.
new String:g_sNames[MAXPLAYERS + 1][MAX_NAME_LENGTH];       // Array to store the name of each player when changes their name.
new g_iNameChangeCounts[MAXPLAYERS + 1];                    // Array to hold how many times each player changes their name.

// Sorry if offsets don't follow global formatting rules, it makes more sense to have it like this.
new m_iClip1 = -1;
new m_iAmmo = -1;
new m_hGroundEntity = -1;
new m_CollisionGroup = -1;
new m_iFOV = -1;
new m_bAlive = -1;
new m_bPlayerSpotted = -1;
new m_bBombSpotted = -1;
new m_flFlashMaxAlpha = -1;
new m_flModelScale = -1;
new m_iAirDash = -1;

// Misc.
new bool:g_bReloadOnEndgame = false;
new bool:g_bHasPluginStarted = false;
new bool:g_bHasRoundStarted = true;
new bool:g_bHasRoundKindaStarted = true;
new bool:g_bIsThursday = false;
new bool:g_bGotToLROrLastGuard;
new bool:g_bShouldTrackDisconnect[MAXPLAYERS + 1];
new bool:g_bWasAuthedToJoin[MAXPLAYERS + 1];
new g_iRoundStartTime;
new g_iCommandDelay[MAXPLAYERS + 1];
new g_iDrops[MAXPLAYERS + 1];
new g_iLastDrop[MAXPLAYERS + 1];
new g_iLastPublicCommand[MAXPLAYERS + 1];
new g_iGame;
new g_iTWins;
new g_iCTWins;
new g_iLastFreekillerToJoinCT;
new String:g_sOwnerSteamid[MAXPLAYERS + 1][LEN_STEAMIDS];
new String:g_sMapPrefix[MAX_NAME_LENGTH] = "ba_jail_hellsgamers";
new String:g_sRepTableName[MAX_NAME_LENGTH] = "prisonrep";

// Plugin display info.
public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "HG JailBreak",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

// Task-specific functions.
#include "hg_jbaio/db_connect.sp" // Good idea to keep at top
#include "hg_jbaio/common.sp" // Good idea to keep at top
#include "hg_jbaio/convars.sp" // Good idea to keep at top
#include "hg_jbaio/findtarget.sp" // Good idea to keep at top
#include "hg_jbaio/cookies.sp" // Good idea to keep at top
#include "hg_jbaio/gag.sp" // Good idea to keep at top
#include "hg_jbaio/deathmatch.sp"
#include "hg_jbaio/radar.sp"
#include "hg_jbaio/redie.sp"
#include "hg_jbaio/aimnames.sp"
#include "hg_jbaio/tlock.sp"
#include "hg_jbaio/tlist.sp"
#include "hg_jbaio/chatfilter.sp"
#include "hg_jbaio/leadguard.sp"
#include "hg_jbaio/mapents.sp"
#include "hg_jbaio/mapcoords.sp"
#include "hg_jbaio/gunplant.sp"
#include "hg_jbaio/muting.sp"
#include "hg_jbaio/namecontrol.sp"
#include "hg_jbaio/prisonrep.sp"
#include "hg_jbaio/rebeltracking.sp"
#include "hg_jbaio/prisondice.sp"
#include "hg_jbaio/teamratio.sp"
#include "hg_jbaio/bomb.sp"
#include "hg_jbaio/warday.sp" // Must stay after leadguard
//#include "hg_jbaio/colorednames.sp" // Now part of hg_premium.smx
#include "hg_jbaio/anticamp.sp"
#include "hg_jbaio/buymenu.sp"
#include "hg_jbaio/teamswitch.sp" // Must stay after tlock and tlist
#include "hg_jbaio/respawn.sp" // Must stay after mapcoords
#include "hg_jbaio/stats.sp"
#include "hg_jbaio/lastrequest.sp" // Must stay after rebeltracking
#include "hg_jbaio/weapons.sp"
#include "hg_jbaio/joinspawn.sp"
#include "hg_jbaio/queue.sp"
#include "hg_jbaio/sungod.sp"
#include "hg_jbaio/invis.sp"
#include "hg_jbaio/tele.sp"
#include "hg_jbaio/strip.sp"
#include "hg_jbaio/thrhndrd.sp"
#include "hg_jbaio/tf2.sp"
#include "hg_jbaio/trade.sp"

// ###################### EVENTS ######################

// debug
/*
public Action:OnClientCommand(client, args)
{
    if (!IsBonbon(client))
        return;

    decl String:arg0[64];
    decl String:cmd[128];

    GetCmdArg(0, arg0, sizeof(arg0));
    GetCmdArgString(cmd, sizeof(cmd));

    decl String:fmt[256];
    Format(fmt, sizeof(fmt), "***********%s - %s - %d", arg0, cmd, GetClientTeam(client));

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsBonbon(i))
        {
            PrintToConsole(i, fmt);
        }
    }
}

bool:IsBonbon(client)
{
    decl String:steamid[32];
    GetClientAuthString(client, steamid, sizeof(steamid));

    return StrEqual(steamid, "STEAM_1:0:11089864") || StrEqual(steamid, "STEAM_0:0:11089864");
}*/

public OnLibraryAdded(const String:library[])
{
    if (StrContains(library, "sendproxy", false) > -1)
    {
        HookScoreBoard();
    }
}

public OnPluginStart()
{
    // OnPluginStart() has occured.
    g_bHasPluginStarted = true;

    // Create ConVars.
    Convars_OnPluginStart();
    AutoExecConfig(true);

    // Do common stock functions.
    CompileCommonRegexes();
    PopulateWeaponsAndItems();

    // Monitor commands.
    AddCommandListener(OnJoinTeam, "jointeam");
    AddCommandListener(OnJoinGame, "joingame");
    AddCommandListener(OnWeaponDrop, "drop");

    // Hook events.
    HookEvent("player_death", OnPlayerDeath);
    HookEvent("player_hurt", OnPlayerHurt);
    HookEvent("item_pickup", OnItemPickup);
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_team", OnPlayerTeamPost);

    if (g_iGame == GAMETYPE_TF2)
    {
        HookEvent("teamplay_round_start", OnRoundStart);
        HookEvent("teamplay_round_win", OnRoundEnd);
    }

    else
    {
        HookEvent("round_start", OnRoundStart);
        HookEvent("round_end", OnRoundEnd);
        HookEvent("weapon_fire", OnWeaponFire);
    }

    // Register commands.
    RegServerCmd("hgjb_reload", Command_Reload);

    // Tasks.
    Cookies_OnPluginStart();
    DM_OnPluginStart();
    MapEnts_OnPluginStart();
    MapCoords_OnPluginStart();
    AimNames_OnPluginStart();
    Tlock_OnPluginStart();
    Tlist_OnPluginStart();
    PrisonRep_OnPluginStart();
    NameControl_OnPluginStart();
    Muting_OnPluginStart();
    GunPlant_OnPluginStart();
    ChatFilter_OnPluginStart();
    //ClrNms_OnPluginStart(); // Now part of hg_premium
    AntiCamp_OnPluginStart();
    BuyMenu_OnPluginStart();
    TeamSwitch_OnPluginStart();
    Respawn_OnPluginStart();
    PrisonDice_OnPluginStart();
    LeadGuard_OnPluginStart();
    Warday_OnPluginStart();
    Stats_OnPluginStart();
    JoinSpawn_OnPluginStart();
    Weapons_OnPluginStart();
    Gag_OnPluginStart();
    Queue_OnPluginStart();
    LR_OnPluginStart();
    Sungod_OnPluginStart();
    Invis_OnPluginStart();
    Tele_OnPluginStart();
    Strip_OnPluginStart();
    ThrHndrd_OnPluginStart();
    Redie_OnPluginStart();
    Trade_OnPluginStart();

    if (g_iGame == GAMETYPE_TF2)
        TF2_OnPluginStart();

    // For FindTarget()
    LoadTranslations("common.phrases");

    // Account for late load
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            Cookies_OnClientPutInServer(i);
            BuyMenu_OnClientPutInServer(i);
            Weapons_OnClientPutInServer(i);
            Muting_OnClientPutInServer(i);
            Trade_OnClientPutInServer(i);
            DM_OnClientPutInServer(i);
            g_bWasAuthedToJoin[i] = true;

            SDKHook(i, SDKHook_WeaponSwitch, OnWeaponSwitch);
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);

            // Testing warday in the test server
            if (GetUserFlagBits(i) & ADMFLAG_ROOT)
            {
                g_bSuccessfulRound[i] = true;
            }

            if (g_iGame != GAMETYPE_TF2)
            {
                SDKHook(i, SDKHook_PostThinkPost, Invis_OnPostThinkPost);
                SDKHook(i, SDKHook_WeaponCanUse, OnWeaponCanUse);
            }

            // Invisible doesn't work by setting color in CS:GO, we have to do it this way :(
            if (g_iGame == GAMETYPE_CSGO)
            {
                SDKHook(i, SDKHook_SetTransmit, Invis_Transmit_CSGO);
            }
        }
    }

    // Find entity offsets
    m_iClip1 = FindSendPropInfo(g_iGame == GAMETYPE_TF2 ? "CTFWeaponBase" : "CBaseCombatWeapon", "m_iClip1");
    m_iAmmo = FindSendPropInfo("CCSPlayer", "m_iAmmo");
    m_hGroundEntity = FindSendPropOffs("CBasePlayer", "m_hGroundEntity");
    m_CollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
    m_iFOV = FindSendPropOffs("CBasePlayer", "m_iFOV");
    m_flFlashMaxAlpha = FindSendPropOffs("CCSPlayer", "m_flFlashMaxAlpha");
    m_flModelScale = FindSendPropInfo("CTFPlayer", "m_flModelScale");
    m_iAirDash = FindSendPropInfo("CTFPlayer", "m_iAirDash");
    m_bAlive = FindSendPropOffs("CCSPlayerResource", "m_bAlive");

    if (m_iAmmo == -1)
    {
        m_iAmmo = FindSendPropInfo("CTFPlayer", "m_iAmmo");
    }

    if (g_iGame == GAMETYPE_CSS)
    {
        m_bPlayerSpotted = FindSendPropOffs("CCSPlayerResource", "m_bPlayerSpotted");
        m_bBombSpotted = FindSendPropOffs("CCSPlayerResource", "m_bBombSpotted");
    }

    else
    {
        m_bPlayerSpotted = FindSendPropOffs("CBaseEntity", "m_bSpotted");
    }

    // Block annoying flashlight sounds and ghost footsteps
    AddNormalSoundHook(OnNormalSoundPlayed);

    // debug
    // to test
    // to remove
    CreateTimer(143.456, Timer_SpamShit, _, TIMER_REPEAT);
}

public OnPluginEnd()
{
    PrisonRep_OnPluginEnd();
}

public Action:Timer_SpamShit(Handle:timer, any:data)
{
    if (g_iGame == GAMETYPE_TF2)
        PrintToChatAll("%s For a limited time, receive \x03CS:GO\x04 and \x03CS:S\x04 rep for playing and idling this server!", MSG_PREFIX);

    else
        PrintToChatAll("%s For a limited time, receive \x03CS:GO\x04 and \x03CS:S\x04 rep for playing and idling our new TF2 Jailbreak \x01(\x0364.31.16.212:27015\x01)\x04 server!", MSG_PREFIX);

    return Plugin_Continue;
}


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Register PrisonRep natives to be used by other plugins (gangs).
    CreateNative("PrisonRep_AddPoints", Native_PrisonRep_AddPoints);
    CreateNative("PrisonRep_GetPoints", Native_PrisonRep_GetPoints);
    CreateNative("PrisonRep_AddPoints_Offline", Native_PrisonRep_AddPoints_Offline);
    CreateNative("JB_IsClientGagged", Native_JB_IsClientGagged);
    CreateNative("JB_IsPlayerAlive", Native_JB_IsPlayerAlive);
    CreateNative("JB_RespawnPlayer", Native_JB_RespawnPlayer);
    CreateNative("JB_DontGiveAmmo", Native_JB_DontGiveAmmo);

    MarkNativeAsOptional("GetUserMessageType");
    MarkNativeAsOptional("TF2Items_CreateItem");
    MarkNativeAsOptional("TF2Items_SetClassname");
    MarkNativeAsOptional("TF2Items_SetItemIndex");
    MarkNativeAsOptional("TF2Items_SetLevel");
    MarkNativeAsOptional("TF2Items_SetQuality");
    MarkNativeAsOptional("TF2Items_SetNumAttributes");
    MarkNativeAsOptional("TF2Items_GiveNamedItem");
    MarkNativeAsOptional("GetClientThrowingKnives");
    MarkNativeAsOptional("SetClientThrowingKnives");
    MarkNativeAsOptional("IsEntityThrowingKnife");

    decl String:game[PLATFORM_MAX_PATH];
    GetGameFolderName(game, sizeof(game));

    if (StrEqual(game, "cstrike"))
    {
        g_iGame = GAMETYPE_CSS;
        Format(g_sRepTableName, sizeof(g_sRepTableName), "prisonrep");
        Format(g_sMapPrefix, sizeof(g_sMapPrefix), "ba_jail_hellsgamers_fx");
    }

    else if (StrEqual(game, "csgo"))
    {
        g_iGame = GAMETYPE_CSGO;
        Format(g_sRepTableName, sizeof(g_sRepTableName), "prisonrep_csgo");
        Format(g_sMapPrefix, sizeof(g_sMapPrefix), "ba_jail_hellsgamers_go");
    }

    else
    {
        g_iGame = GAMETYPE_TF2;
        Format(g_sRepTableName, sizeof(g_sRepTableName), "prisonrep_tf2");
        Format(g_sMapPrefix, sizeof(g_sMapPrefix), "ba_jail_hellsgamers_tf2");
    }

    RegPluginLibrary("hg_jbaio");
    return APLRes_Success;
}

public OnConfigsExecuted()
{
    // Map changes execute OnConfigsExecuted() but not OnPluginStart().  That's not good for this plugin.
    if (!g_bHasPluginStarted)
    {
        LogMessage("Plugin going to reload due to map change...");
        CreateTimer(10.0, Timer_ReloadPlugin);
        return;
    }
    g_bHasPluginStarted = false; // Reset to be ready for next time OnConfigsExecuted() is called.

    // Log plugin startup info.
    LogMessage("Plugin loaded. Version %s", PLUGIN_VERSION);

    // Initial connect to database.
    CreateTimer(0.5, DB_Connect);

    // Monitor name changes, so we can ban people who have a namechange script.
    CreateTimer(GetConVarFloat(g_hCvNameChangeSeconds), DecNameChangeCount, _, TIMER_REPEAT);

    // Read & hook various ConVars.
    RebelTrk_OnConfigsExecuted();
    AntiCamp_OnConfigsExecuted();
    NameControl_OnConfigsExecuted();
    Warday_OnConfigsExecuted();
    LeadGuard_OnConfigsExecuted();
    Muting_OnConfigsExecuted();
    PrisonRep_OnConfigsExecuted();
    PrisonDice_OnConfigsExecuted();
    ConVars_OnConfigsExecuted();
    //MapEnts_OnConfigsExecuted();

    // Set proper endgame state.
    g_iEndGame = ENDGAME_NONE;
    CheckEndGame();
}

public OnAllPluginsLoaded()
{
    Timer_ApplyOverrides(INVALID_HANDLE);
    CreateTimer(3600.0, Timer_ApplyOverrides, _, TIMER_REPEAT);
}

public OnMapStart()
{
    // This is the time to cache models, sprites, and sounds.
    CacheModelsAndSounds();

    // Hook the scoreboard for DM
    g_bScoreBoardHooked = false;
    HookScoreBoard();

    // Add more spawn points.
    if (g_iGame == GAMETYPE_CSS)
    {
        CreateSpawns("info_player_terrorist", 34);
        CreateSpawns("info_player_counterterrorist", 16);
    }

    else if (g_iGame == GAMETYPE_TF2)
        TF2_OnMapStart();

    Radar_OnMapStart();
    MapEnts_OnRoundStart();

    if (g_iGame != GAMETYPE_TF2)
    {
        Redie_OnRoundStart();
    }

    // Debug for april fools.
    //AprilFools_OnMapStart();
}

public Action:OnNormalSoundPlayed(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    if (StrEqual(sample, "items/flashlight1.wav", false))
        return Plugin_Stop;

    if (entity > 0 && entity <= MAXPLAYERS)
    {
        if (g_bIsGhost[entity])
            return Plugin_Stop;

        if (IsPlayerInDM(entity) && StrContains(sample, "itempickup") > -1)
            return Plugin_Stop;
    }

    return Plugin_Continue;
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    ServerCommand("mp_limitteams 0");

    g_iEndGame = ENDGAME_NONE;
    g_bAreCellsOpened = false;
    g_bIsThursday = IsThursday();
    g_iRoundStartTime = GetTime();

    // Set the cells opened by server
    if (g_hServerOpenCellsTimer != INVALID_HANDLE)
        CloseHandle(g_hServerOpenCellsTimer);
    g_hServerOpenCellsTimer = CreateTimer(60.0, ServerOpenCells);

    // Perform applicable tasks.
    DM_OnRoundStart();
    Redie_OnRoundStart();
    Muting_OnRndStrt_General();
    RebelTrk_OnRndStrt_General();
    PrisonDice_OnRoundStart();
    LeadGuard_OnRndStrt_General();
    AntiCamp_OnRndStrt_General();
    Bomb_OnRndStrt_General(); // Yes, bomb SHOULD be given both on round start and !pd
    BuyMenu_OnRndStrt_General();
    DB_OnRndStrt_General();
    GunPlant_OnRndStart_General();
    Warday_OnRndStrt_General();
    Weapons_OnRndStrt_General();
    JoinSpawn_OnRndStrt_General();
    Gag_OnRndStart_General();
    Tlock_OnRndStart_General();
    Tlist_OnRndStart_General();
    MapEnts_OnRoundStart();
    Sungod_OnRoundStart();
    Invis_OnRoundStart();
    Radar_OnRoundStart();
    BuyMenu_OnRoundStart();

    if (g_iGame == GAMETYPE_TF2)
        TF2_OnRoundStart();

    // Let OnPlayerSpawn know the round has started.
    // This way, it can track whether or not to unmute players, who have been respawned by gangs
    // This is set in TF2_ArenaRoundStart in tf2.sp for TF2.

    if (g_iGame != GAMETYPE_TF2)
        g_bHasRoundStarted = true;

    else
        g_bHasRoundKindaStarted = true;

    // Slay all players in 6 minutes (round end) (first cancel possible pending timer).
    if (g_iGame != GAMETYPE_TF2)
    {
        if (g_hRoundEndSlayTimer != INVALID_HANDLE)
            CloseHandle(g_hRoundEndSlayTimer);

        g_hRoundEndSlayTimer = CreateTimer(60.0 * float(GetConVarInt(FindConVar("mp_roundtime"))), Timer_EndRound);
    }

    // Iterate all players.
    new thisTeam;
    for (new i = 1; i <= MaxClients; i++)
    {
        // Perform applicable tasks.
        Bomb_OnRndStrt_EachClient(i);
        RebelTrk_OnRndStrt_EachClient(i);

        g_iCommandDelay[i] -= 2;

        // If player is valid...
        if (IsClientInGame(i))
        {
            // Get client team.
            thisTeam = GetClientTeam(i);

            // Strip weapons.
            if (g_iGame != GAMETYPE_TF2)
                StripWeps(i);

            // Give them armor and a round tart weapons if they're a CT
            if (thisTeam == TEAM_GUARDS && g_iGame != GAMETYPE_TF2 && JB_IsPlayerAlive(i))
            {
                SetEntProp(i, Prop_Send, "m_ArmorValue", 100);
                Weapons_GiveStartWeapons(i);
            }

            // Perform applicable tasks.
            RebelTrk_OnRndStrt_EachValid(i);
            LeadGuard_OnRndStrt_EachValid(i, thisTeam);
        }
    }

    // debug
    //SetTeamScore(TEAM_PRISONERS, g_iTWins);
    //SetTeamScore(TEAM_GUARDS, g_iCTWins);
}

public CellsOpened()
{
    Warday_CellsOpened();
    Redie_CellsOpened();
}

public OnRoundEnd(Handle:event, const String:name[], bool:db)
{
    if (g_iEndGame == ENDGAME_WARDAY)
        Warday_OnRoundEnd();

    if (!g_bGotToLROrLastGuard)
    {
        if (GetEventInt(event, g_iGame == GAMETYPE_TF2 ? "team" : "winner") == TEAM_PRISONERS)
            g_iTWins++;

        else
            g_iCTWins++;
    }

    // Slay all players in 6 minutes (round end) (first cancel possible pending timer).
    if (g_hRoundEndSlayTimer != INVALID_HANDLE)
        CloseHandle(g_hRoundEndSlayTimer);

    g_hRoundEndSlayTimer = INVALID_HANDLE;

    g_bGotToLROrLastGuard = false;
    g_bHasRoundStarted = false;
    g_bHasRoundKindaStarted = false;

    LR_OnRoundEnd();
    ClearArray(g_hGiveAmmo);

    ThrHndrd_OnRoundEnd();
    JoinSpawn_OnRoundEnd();

    if (g_iGame == GAMETYPE_TF2)
        TF2_OnRoundEnd();

    // debug
    //SetTeamScore(TEAM_PRISONERS, g_iTWins);
    //SetTeamScore(TEAM_GUARDS, g_iCTWins);
}

OnClientCookiesLegitCached(client)
{
    Weapons_OnClientCookiesCached(client);
    Redie_OnClientCookiesCached(client);
}

OnDbConnect_Main(Handle:conn)
{
    // Some of these pull their respective DB info using threaded queries.
    // Therefore, keep this in mind that these are not necessarially blocking.
    // What I mean is that, for example, don't put a function that relies on
    // map coordinates being loaded right after MapCoords_OnDbConnect() because
    // it will execute before the maps are finished loading.

    MapCoords_OnDbConnect(conn);
    PrisonRep_OnDbConnect(conn);
    Stats_OnDBConnect(conn);

    //ResetCSSRep();
}

/*
// debug
// to remove
// to test
// for resetting CS:S rep

new Handle:hDrugDB = INVALID_HANDLE;

stock ResetCSSRep()
{
    decl String:sError[255];
    hDrugDB = SQLite_UseDatabase("gangs", sError, sizeof(sError));

    //SQL_TQuery(g_hDbConn_Main, EmptyCallback, "UPDATE prisonrep SET points = 20000 WHERE points > 20000");
    //SQL_TQuery(hDrugDB, EmptyCallback, "UPDATE gangs SET rep = 0, level = 0, totalspent = 0");
    //SQL_TQuery(hDrugDB, EmptyCallback, "UPDATE playerdata SET contributed = 0, totalspent = 0");
    SQL_TQuery(hDrugDB, Grab_ErrBody, "SELECT (totaldrugs * 9), steamid FROM playerdata WHERE points > 20000 AND (totaldrugs * 9) > 20000");
}

public Grab_ErrBody(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!StrEqual(error, ""))
    {
        LogError(error);
        return;
    }

    new points;

    decl String:steamid[32];
    decl String:query[256];

    while (SQL_FetchRow(hndl))
    {
        points = SQL_FetchInt(hndl, 0);
        SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

        ReplaceString(steamid, sizeof(steamid), "STEAM_0:", "");

        Format(query, sizeof(query),
               "UPDATE prisonrep SET points = %d WHERE steamid = '%s'",
               points, steamid);

        SQL_TQuery(g_hDbConn_Main, EmptyCallback, query);
    }
}

// end debug
// end to remove
// end to test
// end for making rep local to CS:GO
*/

OnDbConnect_Bans(Handle:conn)
{
    Tlist_OnDbConnect(conn);
}

OnDbConnect_NC(Handle:conn)
{
    NameControl_OnDbConnect(conn);
    ChatFilter_OnDbConnect(conn);
}

public OnGameFrame()
{
    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_OnGameFrame();
    }

    else
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (g_bIsGhost[i] && IsClientInGame(i))
            {
                SetEntPropFloat(i, Prop_Send, "m_flMaxspeed", 250.0);
            }
        }
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

    if (g_iGame != GAMETYPE_TF2)
    {
        SDKHook(client, SDKHook_PostThinkPost, Invis_OnPostThinkPost);
        SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    }

    if (g_iGame == GAMETYPE_CSGO)
        SDKHook(client, SDKHook_SetTransmit, Invis_Transmit_CSGO);

    g_bWasAuthedToJoin[client] = false;

    // Reset name spam tracking.
    g_sNames[client][0] = '\0';
    g_iNameChangeCounts[client] = 0;

    // Perform applicable tasks
    Cookies_OnClientPutInServer(client);
    Muting_OnClientPutInServer(client);
    Tlock_OnClientPutInServer(client);
    Tlist_OnClientPutInServer(client);
    RebelTrk_OnClientPutInServer(client);
    LeadGuard_OnClientPutInServer(client);
    NameControl_OnClientPutInServer(client);
    BuyMenu_OnClientPutInServer(client);
    Weapons_OnClientPutInServer(client);
    Trade_OnClientPutInServer(client);
    DM_OnClientPutInServer(client);
}

public OnClientAuthorized(client, const String:auth[])
{
    // Exit if the joining player is a bot.
    if (IsFakeClient(client))
        return;

    // We use short Steam IDs whenever possible.
    decl String:steam[LEN_STEAMIDS];
    CopyStringFrom(steam, sizeof(steam), auth, 32, 8);

    // Perform applicable tasks.
    PrisonRep_OnClientAuthorized(client, steam);
    //ClrNms_OnClientAuthorized(client); // Make sure this stays after PrisonRep_OnClientAuthorized() // Now part of hg_premium
    Gag_OnClientAuthorized(client, steam);
    Muting_OnClientPutInServer(client, true);
}

public SW_OnValidateClient(ownerSteam, clientSteam)
{
    decl String:oSteamid[LEN_STEAMIDS];
    decl String:cSteamid[LEN_STEAMIDS];

    Format(oSteamid, sizeof(oSteamid), "%d:%d", ownerSteam & 1, ownerSteam >> 1);
    Format(cSteamid, sizeof(cSteamid), "%d:%d", clientSteam & 1, clientSteam >> 1);

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
            Format(g_sOwnerSteamid[client], 1, "");
        }
    }
}

public OnClientDisconnect(client)
{
    // Tasks.
    PrisonRep_OnClientDisconnect(client);
    LeadGuard_OnClientDisconnect(client);
    //ClrNms_OnClientDisconnect(client); // Now part of hg_premium
    RebelTrk_OnClientDisconnect(client);
    JoinSpawn_OnClientDisconnect(client);
    Warday_OnClientDisconnect();
    Queue_OnClientDisconnect(client);
    LR_OnClientDisconnect(client);
    Muting_OnClientDisconnect(client);
    BuyMenu_OnClientDisconnect(client);
    Trade_OnClientDisconnect(client);
    DM_OnClientDisconnect(client);

    // Just in case.
    CheckEndGame();
}

public Action:OnJoinGame(client, const String:command[], argc)
{
    return Plugin_Handled;
}

public Action:OnJoinTeam(client, const String:command[], argc)
{
    // Ensure client is valid player.
    new team;

    if (!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    // What team did the client join?
    decl String:info[12];
    GetCmdArg(1, info, sizeof(info));

    if (g_iGame == GAMETYPE_TF2)
    {
        if (StrEqual(info, "auto", false))
            team = 0;

        else if (StrEqual(info, "spectate", false))
            team = TEAM_SPEC;

        else if (StrEqual(info, "red", false))
            team = TEAM_PRISONERS;

        else if (StrEqual(info, "blue", false))
            team = TEAM_GUARDS;

        else
            team = TEAM_PRISONERS;
    }

    else
    {
        // 0=autoassign, 1=spec, 2=prisoner, 3=guard
        team = StringToInt(info);
    }

    if (team > TEAM_GUARDS || team < 0)
        return Plugin_Handled;

    if (GetClientTeam(client) == team && team)
        return Plugin_Continue;

    if (team == TEAM_PRISONERS &&
        GetTeamClientCount(TEAM_PRISONERS) >= 16 &&
        g_iGame == GAMETYPE_CSGO)
    {
        new old_team = GetClientTeam(client);

        SwitchTeam(client, TEAM_PRISONERS);
        SetEntProp(client, Prop_Send, "m_iTeamNum", TEAM_PRISONERS);

        if (old_team <= TEAM_SPEC)
            RespawnPlayer(client);

        CreateTimer(0.1, DelaySlay, client);
        CreateTimer(0.5, DelaySlay, client);
        CreateTimer(1.5, DelaySlay_Slap, client);

        return Plugin_Handled;
    }

    new Action:result = CanJoinTeam(client, team);

    if (result == Plugin_Continue)
        g_bWasAuthedToJoin[client] = true;

    else
        g_bWasAuthedToJoin[client] = false;

    return result;
}

Action:CanJoinTeam(client, team)
{
    // Allow if joining spec.
    if (team == TEAM_SPEC)
        return Plugin_Continue;

    if (!NameControl_OnJoinTeam(client))
        return Plugin_Handled;

    // The chose auto assign, deny and re-direct them to join Prisoner team.
    if (team < TEAM_SPEC)
    {
        // Force them to join terrorist.
        if (g_iGame == GAMETYPE_TF2)
            FakeClientCommandEx(client, "jointeam red");

        else if (g_iGame == GAMETYPE_CSS)
            FakeClientCommandEx(client, "jointeam %i", TEAM_PRISONERS);

        else
            FakeClientCommandEx(client, "jointeam %i 1", TEAM_PRISONERS);

        // Don't let the server auto assign them to CT.
        return Plugin_Handled;
    }

    // Applicable tasks.
    Muting_OnJoinTeam(client, team);
    if (g_iGame != GAMETYPE_TF2 && !JoinSpawn_OnJoinTeam(client))
        return Plugin_Handled;

    if (!TeamRatio_OnJoinTeam(client, team))
    {
        if (g_iGame == GAMETYPE_TF2)
            FakeClientCommandEx(client, "jointeam red");

        return Plugin_Handled;
    }

    if (team == TEAM_GUARDS)
    {
        if (!Tlock_AllowedToJoinGuards(client) || !Tlist_AllowedToJoinGuards(client))
        {
            if (IsClientInGame(client))
            {
                EmitSoundToClient(client, g_sSoundDeny);

                if (g_iLastFreekillerToJoinCT == client)
                    PrintToChat(client, "%s Freekiller \x03%N\x04 was blocked from joining Guards", MSG_PREFIX, client);

                else
                    PrintToChatAll("%s Freekiller \x03%N\x04 was blocked from joining Guards", MSG_PREFIX, client);

                g_iLastFreekillerToJoinCT = client;
            }

            if (g_iGame == GAMETYPE_TF2 && IsClientInGame(client))
                FakeClientCommandEx(client, "jointeam red");

            return Plugin_Handled;
        }
    }

    // Strip weapons.
    if (JB_IsPlayerAlive(client))
    {
        new Handle:data = CreateDataPack();
        WritePackCell(data, client);
        WritePackCell(data, 1);
        CreateTimer(2.0, StripWeapsDelay, any:data);
    }

    // Show player what his available commands are.
    CreateTimer(3.0, DisplayPlayerCommands, client);

    // Allow the client to join the team.
    return Plugin_Continue;
}

public OnPlayerTeamPost(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new team = GetEventInt(event, "team");

    if (client <= 0)
        return;

    if (g_iGame == GAMETYPE_CSGO &&
        team == TEAM_GUARDS &&
        !g_bWasAuthedToJoin[client] &&
        CanJoinTeam(client, TEAM_GUARDS) == Plugin_Handled)
        SwitchTeam(client, TEAM_PRISONERS);

    JoinSpawn_OnPlayerTeamPost(client, team);
    Bomb_OnPlayerTeamPost(client);
    Redie_OnPlayerTeamPost(client);
    DM_OnPlayerTeamPost(client);
}


public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    g_iNonRebelAt[client] = 0;
    g_bIsRebelFromEChair[client] = false;

    // Player spawn fires once a player joins, and before they're activated.
    // So make sure we don't unmute them!
    // http://www.eventscripts.com/pages/Event_sequences
    if (!IsClientInGame(client) || !IsPlayerAlive(client))   // Don't use JB_IsPlayerAlive
        return;

    SetEntityGravity(client, 1.0);

    // Noblock
    if (g_iGame != GAMETYPE_TF2)
        SetEntData(client, m_CollisionGroup, 2, 4, true);

    if (IsPlayerInDM(client) && g_bHasRoundStarted)
    {
        StripWeps(client);
        Weapons_GiveStartWeapons(client);
        DM_OnPlayerSpawn(client);

        return;
    }

    else if (g_iGame == GAMETYPE_CSGO)
    {
        CS_SetClientClanTag(client, "");
    }

    if (Redie_OnPlayerSpawn(client))
        return;

    // Tasks.
    Muting_OnPlayerSpawn(client);
    Invis_OnPlayerSpawn(client);
    BuyMenu_OnPlayerSpawn(client);

    JoinSpawn_OnPlayerSpawn(client);

    if (g_iGame == GAMETYPE_TF2)
        CreateTimer(0.1, TF2_OnPlayerSpawn, GetClientUserId(client));

    // Give them a health bonus to even out the game if they're a CT.
    // Dependent on how many Ts there are, because of the recent growth in server population.
    // It is impossible to lead with 20+ Ts.

    if (!g_bIsThursday)
    {
        if (GetClientTeam(client) == TEAM_GUARDS)
        {
            new health_amount = RoundToNearest(GetTeamClientCount(TEAM_PRISONERS) * GetConVarFloat(g_hCvCtHealthBonusPerT));

            if (g_iGame == GAMETYPE_TF2)
                TF2_SetHealthBonus(client, health_amount);

            SetEntityHealth(client, GetClientHealth(client) + health_amount);
        }
    }
}

public OnClientSettingsChanged(client)
{
    // Ensure client is valid player.
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    // Was the name changed?
    decl String:oldName[MAX_NAME_LENGTH];
    decl String:newName[MAX_NAME_LENGTH];
    Format(oldName, MAX_NAME_LENGTH, g_sNames[client]);
    GetClientName(client, newName, MAX_NAME_LENGTH);

    // The name did not change.  It must have been another setting that changed.
    if (strcmp(newName, oldName) == 0)
        return;

    // The name changed.  Keep track of the new name, so we know next time whether a name changed or not.
    Format(g_sNames[client], MAX_NAME_LENGTH, newName);

    // Track number of name changes.
    new numChanges = g_iNameChangeCounts[client] + 1;
    new nameChangeLimit = GetConVarInt(g_hCvNameChangeLimit);

    if (nameChangeLimit > 1)
    {
        if (numChanges > nameChangeLimit)
        {
            // Too many name changes.  Reset tracker and take action.
            g_iNameChangeCounts[client] = 0;

            // Put together reason.
            new Float:nameChangeTimespan = GetConVarFloat(g_hCvNameChangeSeconds);
            if (nameChangeTimespan > 10.0)
            {
                decl String:reason[LEN_CONVARS];
                Format(reason, LEN_CONVARS, "%i name changes in %i seconds", numChanges - 1, RoundToNearest(nameChangeTimespan));

                // Ban.
                ServerCommand("sm_ban #%d %f \"%s\"", GetClientUserId(client), 0.0, reason);
            }
            else
            {
                LogMessage("ERROR: nameChangeTimespan was %f", nameChangeTimespan);
            }
        }
        else
        {
            // Not too many changes yet, but keep tracking the number of changes.
            g_iNameChangeCounts[client] = numChanges;

            /******** SINCE HIS NAME CHANGED, CHECK IT ********/

            NameControl_OnNameChange(client);
        }
    }
    else
    {
        LogMessage("ERROR: nameChangeLimit was %i", nameChangeLimit);
    }
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    TF2_OnPlayerRunCmd(client, buttons);
    Redie_OnPlayerRunCmd(client, buttons);

    return Plugin_Continue;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    new Action:to_return = Plugin_Continue;

    if (damagetype & DMG_FALL)
        return Plugin_Handled;

    // The victim should definitely be in-game anyway if this event is being called.
    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim))
        return Plugin_Continue;

    new String:classname[LEN_ITEMNAMES];
    new Action:dmret = DM_OnTakeDamage(victim, attacker, damage);

    if (dmret != Plugin_Continue)
        return dmret;

    // If bomb does extra damage with more rep, why shouldn't you take less damage the more you have?
    if (IsValidEntity(inflictor))
    {
        GetEntityClassname(inflictor, classname, sizeof(classname));

        if (StrEqual(classname, "env_explosion"))
        {
            // Basically, what this does is it makes it if a player's bomb does 3 times as much damage,
            //  then when they're hit by a bomb they only take (1 / 3) times as much damage.

            new Float:rep = float(PrisonRep_GetPoints(victim) + 2); // Make sure they have at least 1 rep (log(x) where x <= 0 is infinity)
            if (g_bIsThursday)
                rep = 0.0;

            new Float:multiplier = Logarithm(1000.0 + rep, 3.33) - Logarithm(1000.0, 3.33);

            new magnitudeadd = RoundToNearest(multiplier * GetConVarFloat(g_hCvBombDamageMultiplier));
            new defaultmagnitude = GetConVarInt(g_hCvBombMagnitude);
    
            new Float:damage_multiplier = 1.0 / (float(defaultmagnitude + magnitudeadd) / float(defaultmagnitude));
            damage *= damage_multiplier;

            to_return = Plugin_Changed;

            // New thing in the CT buy menu. "C4 Resistance"
            damage *= g_fC4Resistance[victim];
        }

        else if (StrEqual(classname, "weapon_hegrenade") || damagetype & DMG_BLAST)
            damage *= g_fC4Resistance[victim];
    }

    if (StrEqual(classname, "player"))
        GetClientWeapon(attacker, classname, sizeof(classname));

    Format(g_sLastHurtBy[victim], LEN_ITEMNAMES, classname);

    // What endgame state is it?
    switch(g_iEndGame)
    {
        case ENDGAME_NONE:
        {
            // Ensure attacker is in-game and not on the same team as the victim.
            if (attacker != victim && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
            {
                new attackerTeam = GetClientTeam(attacker);
                new victimTeam = GetClientTeam(victim);

                if (attackerTeam != victimTeam)
                {
                    // Tasks for a Guard injuring a Prisoner.
                    if (attackerTeam == TEAM_GUARDS)
                    {
                        // Block this Guard's damage if he is trying to shoot people from inside the Admin Room.
                        if (!BuyMenu_PlayerHurt(attacker))
                            return Plugin_Handled;

                        // If the weapon is a glock, modify the damage.
                        // In this game, glocks only do 1 HP of damage -- they are only for "warnings".
                        if (!Weapons_PlayerHurt(attacker, victim))
                            return Plugin_Handled;
                    }
                }

                // Team agnostic tasks.
                if (g_bSuperKnife[attacker])
                {
                    decl String:weapon[LEN_ITEMNAMES];
                    GetClientWeapon(attacker, weapon, sizeof(weapon));

                    new slot;
                    GetTrieValue(g_hWepsAndItems, weapon, slot);

                    if (slot == WEPSLOT_KNIFE)
                    {
                        g_bSuperKnife[attacker] = false;
                        damage += float(GetClientHealth(victim)) + 101.0;
                        return Plugin_Changed;
                    }
                }
            }
        }

        case ENDGAME_LR:
        {
            // If they are doing a back-stab-only knife fight...
            // only allow the damage to continue if it really was a back-stab.
            if (!KF_OnTakeDamage(victim, attacker, damage))
                return Plugin_Stop;

            // Flashbangs don't always kill in one hit.
            if (IsInLR(attacker, "Dodgeball") &&
                IsInLR(victim, "Dodgeball") &&
                (StrEqual(classname, "flashbang_projectile") || StrEqual(classname, "weapon_flashbang")))
            {
                damage += float(GetClientHealth(victim)) + 1.0;
                return Plugin_Changed;
            }
        }

        case ENDGAME_LASTGUARD:
        {
            //pass
        }

        case ENDGAME_WARDAY:
        {
            if (attacker != victim && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
            {
                if (!JB_IsPlayerAlive(attacker) || !JB_IsPlayerAlive(victim))
                    return Plugin_Continue;

                // Tasks for a Guard injuring a Prisoner.
                if (GetClientTeam(attacker) == TEAM_GUARDS &&
                    GetClientTeam(victim) == TEAM_PRISONERS)
                {
                    if (!Warday_PlayerHurt(attacker))
                        return Plugin_Handled;
                }

                // Team agnostic tasks.
                if (Warday_ModifyDamage(victim, attacker, damage, damagetype))
                    return Plugin_Changed;
            }
        }

        case ENDGAME_300DAY:
        {
            //pass
        }
    }

    return to_return;
}

// Do NOT move this back to OnTakeDamage!!!
// This is separate for a reason! If you touch, LR will break again!
// We can't use OnTakeDamage for LR because you can't get the weapon a player attacked with.

public OnPlayerHurt(Handle:event, const String:eventname[], bool:db)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if (g_iGame == GAMETYPE_TF2 &&
        victim && victim == attacker &&
        GetEventInt(event, "custom") == TF_CUSTOM_STICKBOMB_EXPLOSION &&
        HasBomb(victim))
        ExplodePlayer(victim);

    if (GetEventInt(event, "health") <= 0 ||
        !JB_IsPlayerAlive(victim))
        return;

    if (victim <= 0 ||
        attacker <= 0 ||
        !IsClientInGame(victim) ||
        !IsClientInGame(attacker))
        return;

    new String:weapon[LEN_ITEMNAMES];
    new damage;

    if (g_iGame == GAMETYPE_TF2)
        damage = GetEventInt(event, "damageamount");

    else
        damage = GetEventInt(event, "dmg_health");

    // NOTE: This will NOT work in TF2.
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    new attackerTeam = GetClientTeam(attacker);
    new victimTeam = GetClientTeam(victim);

    switch (g_iEndGame)
    {
        case ENDGAME_NONE:
        {
            if (attacker != victim &&
                attacker > 0 &&
                attacker <= MaxClients
                && IsClientInGame(attacker) &&
                attackerTeam != victimTeam)
            {
                // Tasks for a Prisoner injuring a Guard.
                if (attackerTeam == TEAM_PRISONERS)
                {
                    // Reward the Prisoner for killing or injuring a Guard.
                    PrisonRep_OnPrisonerHurtGuard(attacker, victim);

                    // Make the Prisoner a rebel because he injured a Guard.
                    if (damage > 1)
                        MakeRebel(attacker, false);
                }

                // Tasks for a Guard injuring a Prisoner.
                else if(attackerTeam == TEAM_GUARDS)
                    RebelTrk_OnGuardHurtPrisoner(attacker, victim);
            }
        }

        // Do LR checks.
        case ENDGAME_LR:
        {
            // Because we can't get the weapon name
            // we have to pass true here for the last parameter
            LR_OnPlayerDamagedOrDied(victim, attacker, false, weapon, g_iGame == GAMETYPE_TF2);
        }
    }
}

stock OnLeadDeath(client)
{
    Muting_OnLeadDeath();
}

stock OnPlayerRespawned(client)
{
    DM_OnPlayerRespawned(client);
}

public OnPlayerDeath(Handle:event, const String:eventname[], bool:dontBroadcast)
{
    if (g_iGame == GAMETYPE_TF2 && !g_bHasRoundStarted)
        return;

    new attacker = GetEventInt(event, "attacker");
    new victim = GetEventInt(event, "userid");

    // debug dm
    // debug
    if (g_iGame != GAMETYPE_TF2)
    {
        new victim_client = GetClientOfUserId(victim);

        if (victim_client > 0)
        {
            if (IsPlayerInDM(victim_client))
            {
                DM_OnPlayerDeath_Post(victim_client, true);
                return;
            }

            else
            {
                DM_OnPlayerDeath_Post(victim_client, attacker != victim && attacker > 0);
            }
        }
    }

    decl String:weapon[LEN_ITEMNAMES];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    if (g_iGame == GAMETYPE_TF2)
    {
        new victim_client = GetClientOfUserId(victim);
        Format(weapon, sizeof(weapon), g_sLastHurtBy[victim_client]);
    }

    new Handle:hData = CreateDataPack();

    WritePackCell(hData, attacker);
    WritePackCell(hData, victim);
    WritePackString(hData, weapon);

    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_OnPlayerDeathPre(GetClientOfUserId(victim));
        CreateTimer(0.01, Timer_OnPlayerDeath, hData);
    }

    else
    {
        Timer_OnPlayerDeath(INVALID_HANDLE, hData);
    }
}

public Action:Timer_OnPlayerDeath(Handle:timer, any:hData)
{
    ResetPack(hData);

    // Get event args.
    new attacker = GetClientOfUserId(ReadPackCell(hData));
    new victim = GetClientOfUserId(ReadPackCell(hData));

    decl String:weapon[LEN_ITEMNAMES];
    ReadPackString(hData, weapon, sizeof(weapon));

    CloseHandle(hData);

    // Deaths don't get logged to CS:GO's console.
    if (g_iGame == GAMETYPE_CSGO)
        PrintToConsoleAll("%N killed %N with %s", attacker, victim, weapon);

    if (g_iGame != GAMETYPE_TF2)
    {
        Redie_OnPlayerDeath(victim);
    }

    if (g_iEndGame == ENDGAME_NONE &&
        attacker > 0 &&
        IsClientInGame(attacker) &&
        attacker != victim &&
        GetClientTeam(attacker) != GetClientTeam(victim))
    {
        if (GetClientTeam(attacker) == TEAM_GUARDS)
            RebelTrk_OnGuardKilledPrisoner(attacker, victim);

        else
        {
            PrisonRep_OnPrisonerKilledGuard(attacker, victim);
            MakeRebel(attacker, true);
        }
    }

    // Is it LR time?
    else if (g_iEndGame == ENDGAME_LR)
    {
        LR_OnPlayerDamagedOrDied(victim, attacker, true, weapon, false);
    }

    // Give the attacker more health if they used a knife.
    if (attacker > 0)
        Weapons_OnPlayerDeath(attacker, weapon);

    if (victim > 0)
    {
        // Track them so they can't rejoin to respawn.
        JoinSpawn_OnPlayerDeath(victim);

        // Mute players that die.
        Muting_OnPlayerDeath(victim);

        // If the Lead Guard dies, reset the lead.
        LeadGuard_OnPlayerDeath(victim);

        // The dead player should no longer be invisible.
        Invis_OnPlayerDeath(victim);

        // Explode them if they have the bomb.
        Bomb_OnPlayerDeath(victim);

        // Reset dead player trackers.
        RebelTrk_ResetTrackers(victim);
    }

    // Should we start the search and destroy early?
    Warday_OnPlayerDeath();

    // Count living Guards and Prisoners and see if we need to go into LR mode.
    CheckEndGame();
    return Plugin_Handled;
}

public OnEntityCreated(entity, const String:classname[])
{
    if (entity <= MaxClients)
        return;

    if (g_iEndGame != ENDGAME_LR &&
        (StrEqual(classname, "flashbang_projectile") ||
        StrEqual(classname, "smokegrenade_projectile")))
    {
        SDKHook(entity, SDKHook_Spawn, OnProjectileSpawn);
    }

    if (g_iGame == GAMETYPE_TF2)
        TF2_OnEntityCreated(entity, classname);

    else
    {
        // Should we give it ammo?
        Weapons_OnEntityCreated(entity, classname);

        // LR Stuff
        DB_OnEntityCreated(entity, classname);

        // Buymenu Stuff
        BuyMenu_OnEntityCreated(entity, classname);

        if (StrEqual(classname, "env_particlesmokegrenade"))
        {
            // There's no need to loop through all smokegrenade_projectile.
            // Because this event will fire every time a smoke grenade is exploded.

            new ent = -1;
            new prev = 0;

            while ((ent = FindEntityByClassname(ent, "smokegrenade_projectile")) != -1)
            {
                if (prev && IsValidEdict(prev))
                    RemoveEdict(prev);
                prev = ent;
            }

            if (prev) RemoveEdict(prev);
        }

        // In CS:GO, if you walk on a bomb if you already have one it'll just dissapear
        else if (g_iGame == GAMETYPE_CSGO && StrEqual(classname, "weapon_c4"))
            SDKHook(entity, SDKHook_Spawn, CSGO_OnC4Spawn);
    }
}

public OnProjectileSpawn(entity)
{
    if (GetFeatureStatus(FeatureType_Native, "IsEntityThrowingKnife") != FeatureStatus_Available ||
        !IsEntityThrowingKnife(entity))
    {
        SetEntData(entity, m_CollisionGroup, 2, 4, true);
    }

    else
    {
        SetEntProp(entity, Prop_Send, "m_usSolidFlags", (GetEntProp(entity, Prop_Send, "m_usSolidFlags") & ~(1 << 2)));
        SetEntData(entity, m_CollisionGroup, 5, 1, true);
    }
}

public CSGO_OnC4Spawn(entity)
{
    SDKHook(entity, SDKHook_Touch, CSGO_OnC4Touch);
    SDKHook(entity, SDKHook_StartTouch, CSGO_OnC4Touch);
}

public Action:CSGO_OnC4Touch(c4, client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Continue;

    if (GetPlayerWeaponSlot(client, 4) > 0)
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action:OnWeaponDrop(client, const String:command[], args)
{
    if (g_iGame == GAMETYPE_TF2)
        return Plugin_Continue;

    // You can lag the server REALLY badly by gathering all the guns from armory, and putting them in one location (armory vents)
    // This SHOULD prevent that.

    if (GetTime() - g_iLastDrop[client] < 4)
    {
        if (g_iDrops[client] > 3)
        {
            PrintToChat(client,
                        "%s Slow down. To prevent people from lagging the server, you can't drop your weapons that fast",
                        MSG_PREFIX);

            return Plugin_Handled;
        }

        g_iDrops[client]++;
    }

    else
        g_iDrops[client] = 1;

    g_iLastDrop[client] = GetTime();

    // Get weapon ID.
    new wepid = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEdict(wepid))
        return Plugin_Continue;

    // Get weapon name.
    decl String:wepname[LEN_ITEMNAMES];
    GetEdictClassname(wepid, wepname, sizeof(wepname)); // OR:  GetClientWeapon(client, wepname, sizeof(wepname));

    // Get weapon type (slot)
    //     It's not actually in a slot cuz it's on the ground, but we still need to know what type it is.
    /*
        0 = primary
        1 = secondary
        2 = knife
        3 = nade(s)
        4 = c4
        5 = other items
    */
    new slot;

    /*** Now, since we know the wepid, wepname, and slot num, we can do whatever we want with this info. ***/

    // Check if he dropped the bomb.
    Bomb_OnWeaponDrop(client, wepname);

    // Ensure dropped weapon is no longer invisible.
    Invis_OnWeaponDrop(wepid);

    // We want to check the clients current weapon AFTER they've dropped this weapon.
    // This way we can check if we should make them not a rebel anymore.
    CreateTimer(0.1, RebelTrk_CheckNonRebel, GetClientUserId(client));

    // Only track gunplants during normal play (not end-game).
    if (g_iEndGame == ENDGAME_NONE)
    {
        if (GetClientTeam(client) == TEAM_GUARDS) GunPlant_OnDropWeapon(client, wepid, slot);
    }

    return Plugin_Continue;
}

public OnWeaponFire(Handle:event, const String:eventname[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_iEndGame == ENDGAME_NONE &&
        GetClientTeam(client) == TEAM_PRISONERS &&
        JB_IsPlayerAlive(client))
    {
        decl String:wep[MAX_NAME_LENGTH];
        GetEventString(event, "weapon", wep, sizeof(wep));

        if (StrContains(wep, "grenade") == -1 &&
            StrContains(wep, "knife") == -1 &&
            StrContains(wep, "flash") == -1)
            MakeRebel(client, REBELTYPE_SHOOT);
    }
}

// TF2's OnWeaponFire pretty much.
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
    new slot;

    if (!GetTrieValue(g_hWepsAndItems, weaponname, slot))
        LogError("TF2: NEW WEAPON (TF2_CalcIsAttackCritical)? %s", weaponname);

    if (g_iEndGame == ENDGAME_NONE)
    {
        if (GetClientTeam(client) == TEAM_PRISONERS)
        {
            if (slot != WEPSLOT_KNIFE)
                MakeRebel(client, REBELTYPE_SHOOT);

            if (!g_bHasKritz[client])
            {
                result = false;
                return Plugin_Handled;
            }
        }

        else if (slot == WEPSLOT_KNIFE)
        {
            if (GetRandomInt(0, 7) == 1)
            {
                result = true;
                return Plugin_Handled;
            }
        }

        else if (GetRandomInt(0, 1))
        {
            result = true;
            return Plugin_Handled;
        }
    }

    else if (g_iEndGame == ENDGAME_LR)
        S4S_TF2_OnWeaponFire(client, weapon);

    else if (g_iEndGame == ENDGAME_LASTGUARD &&
             GetClientTeam(client) == TEAM_GUARDS &&
             GetRandomFloat() <= 0.51)
    {
        result = true;
        return Plugin_Handled;
    }

    else if (g_iEndGame == ENDGAME_300DAY)
    {
        if (GetClientTeam(client) == TEAM_GUARDS &&
            slot == WEPSLOT_KNIFE &&
            GetRandomInt(0, 7) == 1)
        {
            result = true;
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public OnItemPickup(Handle:event, const String:eventname[], bool:dontBroadcast)
{
    // Get client from event args.
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // Exit if client is dead.
    if (!JB_IsPlayerAlive(client))
        return;

    // Get which item was picked up from event args.
    new String:itemname[LEN_ITEMNAMES];
    GetEventString(event, "item", itemname, sizeof(itemname));

    // Get type (slot) of weapon,
    /*
        0 = primary
        1 = secondary
        2 = knife
        3 = nade(s)
        4 = c4
        5 = other items
    */
    new slot;
    if (!GetTrieValue(g_hWepsAndItems, itemname, slot))
        return;

    // Find out ID of weapon.  Its not an event arg that we can just extract.
    // We need to check the client's weapon slot.
    // If he has it, then we can get the ID from the weapon in his slot.
    new wepid = GetPlayerWeaponSlot(client, slot);
    if (wepid != -1)
    {
        /*** Now, since we know the wepid, wepname (itemname), and slot num, we can do whatever we want with this info. ***/

        // See if he picked up the bomb.
        Bomb_OnItemPickup(client, itemname);

        // If this gun is being picked up by an invisible person, we should make it invisible too.
        Invis_OnItemPickup(client, wepid);

        // See if he picked up the glock, or we should give him ammo.
        Weapons_OnItemPickup(client, wepid, itemname, slot);

        // See if this was a planted gun (only check during normal play; not end-game).
        if (g_iEndGame == ENDGAME_NONE)
            GunPlant_OnItemPickup(client, wepid, slot);
    }
    return;
}

public Action:OnWeaponSwitch(client, weapon)
{
    if (weapon > 0)
    {
        Invis_OnWeaponSwitch(client, weapon);
        RebelTrk_OnWeaponSwitch(client, weapon);
    }
}

public Action:OnWeaponCanUse(client, weapon)
{
    if (!Redie_OnWeaponCanUse(client))
        return Plugin_Handled;

    if (!LR_OnWeaponCanUse(client, weapon))
        return Plugin_Handled;

    return Plugin_Continue;
}

// ###################### COMMANDS ######################

public Action:OnSay(client, const String:text[], maxlength)
{
    return OnSayEx(client, text, false);
}

public Action:OnSayTeam(client, const String:text[], maxlength)
{
    return OnSayEx(client, text, true);
}

Action:OnSayEx(client, const String:text[], bool:teamonly)
{
    // Is it a real client?
    if ((client <= 0) || (!IsClientInGame(client)))
        return Plugin_Continue;

    if (!Trade_OnSay(client))
        return Plugin_Stop;

    // Did the player type a command, such as !pd or /pd
    if (IsChatTrigger())
    {
        // Stop, if the command was meant to be silent
        if (text[0] == '/')
            return Plugin_Stop;

        // Stop the command if they're using trade chat in verbose mode
        else if (text[0] == '!' && text[1] == 't' && text[2] == ' ')
            return Plugin_Stop;

        // Prevent command spam on round start
        if (!g_bHasRoundStarted || (GetTime() - g_iRoundStartTime) < 5)
            return Plugin_Stop;

        if (StrContains(text, "!fire", false) == 0 && g_bAlreadyVoted[client])
            return Plugin_Stop;
    }

    // Command wasn't a chat trigger, so check if the player wanted to leads
    else
    {
        LeadGuard_CheckLead(client);

        if (text[0] == '!' && !(StrContains(text, "!!!!") == 0 && teamonly))
        {
            if (GetTime() - g_iLastPublicCommand[client] < 60)
                return Plugin_Stop;
    
            g_iLastPublicCommand[client] = GetTime();
        }

        else if (StrEqual(text, "guns") && g_iGame != GAMETYPE_TF2)
        {
            Command_SelectGuns(client, 0);
            return Plugin_Stop;
        }
    }

    // Perform applicable tasks.
    if (!Gag_AllowedToUseChat(client))
        return Plugin_Stop;
    /*if (ClrNms_ApplyColor(client))
        return Plugin_Handled;*/ // now part of hg_premium

    // Else.
    return Plugin_Continue;
}

public Action:Command_Reload(args)
{
    g_bReloadOnEndgame = true;
    PrintToServer("Reloading hg_jbaio on end game...");

    return Plugin_Handled;
}

// ###################### FUNCTIONS ######################


bool:IsPlayerInDM(client)
{
    return g_bDeadDM[client];
}
bool:IsHoldingNonGun(client)
{
    new slot;
    decl String:weapon[MAX_NAME_LENGTH];

    GetClientWeapon(client, weapon, sizeof(weapon));
    GetTrieValue(g_hWepsAndItems, weapon, slot);

    return !(slot == WEPSLOT_PRIMARY || slot == WEPSLOT_SECONDARY);
}

bool:IsThursday()
{
    /*
    decl String:day[MAX_NAME_LENGTH];
    FormatTime(day, sizeof(day), "%A");

    return g_iGame == GAMETYPE_CSS ? StrEqual(day, "Thursday") : false;
    */

    return false;
}

SetWeaponAmmo(weapon, owner, clip=0, ammo=-1)
{
    if (weapon <= 0 || owner > MaxClients || owner <= 0 || !IsClientInGame(owner))
        return;

    if (clip > -1)
        SetEntData(weapon, m_iClip1, clip);

    if (ammo > -1)
        SetEntData(owner, m_iAmmo +
                   GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") * 4,
                   ammo, _, true);
}

GetWeaponClip(weapon)
{
    return GetEntData(weapon, m_iClip1);
}

GetWeaponAmmo(weapon, owner)
{
    return GetEntData(owner, m_iAmmo +
                      GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") * 4);
}

CheckEndGame()
{
    if (g_iEndGame != ENDGAME_LASTGUARD && g_iEndGame != ENDGAME_LR)
    {
        new total_prisoners;
        new total_guards;
        new this_team;
        new last_guard;

        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                if (JB_IsPlayerAlive(i))
                {
                    this_team = GetClientTeam(i);
                    switch(this_team)
                    {
                        case TEAM_PRISONERS:
                        {
                            total_prisoners += 1;
                        }
                        case TEAM_GUARDS:
                        {
                            total_guards += 1;
                            last_guard = i;
                        }
                    }
                }
            }
        }

        Radar_OnPlayerDeath(total_prisoners);

        // If there is 1 Guard left.
        if (total_guards == 1)
        {
            if (g_iEndGame == ENDGAME_WARDAY)
                Warday_OnRoundEnd();

            // Last guard counts as a T win, 'cause the lead failed.
            g_iTWins++;
            g_bGotToLROrLastGuard = true;

            g_iEndGame = ENDGAME_LASTGUARD;
            EmitSoundToAll(g_sSoundAlarm);
            PrintCenterTextAll("LAST GUARD");
            PrintHintTextToAll("LAST GUARD");
            PrintToChatAll("%s LAST GUARD came before LR.", MSG_PREFIX);
            PrintToChatAll("%s \x03%N\x04 can kill \x03ANY\x04 remaining terrorist that is not trapped", MSG_PREFIX, last_guard);

            // Reset rebel status and colors.
            RebelTrk_EndGameTime();

            // Let 300 know to remove the walls
            ThrHndrd_EndGameTime();

            /*
                Reconnect to database.
                Why on LR?  Because the perfect time to do a "sm plugins reload hg_jbaio" is after LR.
                    (stuff like Lead CT wont get messed up)
                    So we need to do a DB_Connect here (after LR, BUT hopefully BEFORE someone reloads the plugin).
                        That way, people's Rep for the round will get saved.
            */

            if (g_iGame == GAMETYPE_TF2)
            {
                for (new i = 1; i <= MaxClients; i++)
                {
                    if (IsClientInGame(i) &&
                        GetClientTeam(i) == TEAM_GUARDS &&
                        JB_IsPlayerAlive(i))
                    {
                        g_fPlayerSpeed[i] = 450.0;
                        break;
                    }
                }
            }

            CreateTimer(0.1, DB_Connect);
        }

        // If there are 1 or 2 Prisoners.
        else if (total_prisoners <= 2)
        {
            if (g_iEndGame == ENDGAME_WARDAY)
                Warday_OnRoundEnd();

            g_iCTWins++;
            g_bGotToLROrLastGuard = true;

            g_iEndGame = ENDGAME_LR;
            EmitSoundToAll(g_sSoundAlarm);
            PrintCenterTextAll("LR TIME");
            PrintHintTextToAll("LR TIME");
            PrintToChatAll("%s LR TIME", MSG_PREFIX);

            for (new i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && 
                    JB_IsPlayerAlive(i) &&
                    GetClientTeam(i) == TEAM_PRISONERS)
                {
                    Tele_DoClient(0, i, "Top of Electric Chair", false);
                    FakeClientCommand(i, "sm_lr");
                }
            }

            // Reset rebel status and colors.
            RebelTrk_EndGameTime();

            // Give lead credit for reaching LR.
            LeadGuard_EndGameTime();

            // Let 300 know to remove the walls
            ThrHndrd_EndGameTime();

            /*
                Reconnect to database.
                Why on LR?  Because the perfect time to do a "sm plugins reload hg_jbaio" is after LR.
                    (stuff like Lead CT wont get messed up)
                    So we need to do a DB_Connect here (after LR, BUT hopefully BEFORE someone reloads the plugin).
                        That way, people's Rep for the round will get saved.
            */
            CreateTimer(0.1, DB_Connect);
        }

        if ((g_iEndGame == ENDGAME_LR || g_iEndGame == ENDGAME_LASTGUARD) && 
            g_bReloadOnEndgame)
        {
            PrintToChatAll("%s Reloading plugin... Ignore any glitches until end of next round", MSG_PREFIX);
            PrintToChatAll("%s Reloading plugin... Ignore any glitches until end of next round", MSG_PREFIX);
            PrintToChatAll("%s Reloading plugin... Ignore any glitches until end of next round", MSG_PREFIX);
            DisplayMSayAll("Reloading Plugin", 60, "Ignore any glitches\nuntil end of next round");

            DM_Cleanup();
            ServerCommand("sm plugins reload hg_jbaio");
        }
    }
}

public Action:ServerOpenCells(Handle:timer)
{
    if (!g_bAreCellsOpened)
    {
        g_bAreCellsOpened = true;
        CellsOpened();
    }

    g_hServerOpenCellsTimer = INVALID_HANDLE;
}

public Action:DisplayPlayerCommands(Handle:timer, any:client)
{
    if (!IsClientInGame(client))
        return Plugin_Continue;

    // Is admin?
    new bits = GetUserFlagBits(client);

    if (bits)
    {
        PrintToChat(client, "%s \x01sm_coloredname\x04 (type in console)", MSG_PREFIX);

        if (bits & ADMFLAG_KICK || bits & ADMFLAG_ROOT)
        {
            PrintToChat(client, "%s The following commands take \x03partial name", MSG_PREFIX);
            PrintToChat(client, "%s \x01or \x03part of name with spaces \x04(\x01in quotes\x04)", MSG_PREFIX);
            PrintToChat(client, "%s \x01or \x03Steam ID \x04(STEAM_0:X:XXXXXXXX)", MSG_PREFIX);
            PrintToChat(client, "%s \x01or \x03userid number \x04(from status)", MSG_PREFIX);
            PrintToChat(client, "%s \x03!\x01movet\x04, \x03!\x01movect\x04, \x03!\x01movespec\x04, \x03!\x01mute\x04, \x03!\x01unmute", MSG_PREFIX);
            PrintToChat(client, "%s \x03!\x01tlist\x04, \x03!\x01untlist\x04, \x03!\x01lock\x04, \x03!\x01unlock", MSG_PREFIX);
        }
    }
    else
    {
        // Enough rep to use colored name?
        new rep_needed = GetConVarInt(g_hCvRepLevelColoredName);
        new rep = PrisonRep_GetPoints(client);
        if (rep >= rep_needed)
            PrintToChat(client, "%s \x01sm_coloredname\x04 (type in console)", MSG_PREFIX);
    }

    // Regular commands.
    PrintToChat(client, "%s \x03!\x01rep\x04, \x03!\x01toprep\x04, \x03!\x01playerrep\x04, \x03!\x01repstats", MSG_PREFIX);
    PrintToChat(client, "%s \x03!\x01queue\x04, \x03!\x01leavequeue\x04", MSG_PREFIX);
    return Plugin_Continue;
}

public Action:StripWeapsDelay(Handle:timer, any:data)
{
    ResetPack(Handle:data);
    new client = ReadPackCell(Handle:data);
    new bool:giveknife = bool:ReadPackCell(Handle:data);
    CloseHandle(data);

    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        StripWeps(client, giveknife);
    }
}

public Action:Timer_StripWeps(Handle:timer, any:client)
{
    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        Strip_DoClient(0, client, true, false);
    }
}

public Action:Timer_StripWeps_NoKnife(Handle:timer, any:client)
{
    Strip_DoClient(0, client, false, false);
}

stock StripWeps(client, bool:giveKnife=true)
{
    Strip_DoClient(0, client, giveKnife, false);
}

stock CreateSpawns(const String:spawn[], tocreate)
{
    new ent = -1;
    new count = 0;

    while ((ent = FindEntityByClassname(ent, spawn)) != -1)
    {
        count++;
    }

    if (tocreate + count > MaxClients)
    {
        tocreate = MaxClients - count;
    }

    if (tocreate <= 0)
        return;

    // creates "tocreate" amount of spawns.
    for (new i = 0; i < tocreate; i++)
    {
        // If there isn't another spawn that we can copy, end the loop.
        if ((ent = FindEntityByClassname(ent, spawn)) == -1)
            break;

        // Create, and spawn our spawn point.
        new index = CreateEntityByName(spawn);
        DispatchSpawn(index);

        // Get the location of the other spawn point we're copying.
        decl Float:origin[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);

        // Teleport our new spawn point on top of another existing spawn.
        TeleportEntity(index, origin, NULL_VECTOR, NULL_VECTOR);
    }
}

// ###################### CALLBACKS ######################

public Action:Timer_ApplyOverrides(Handle:timer)
{
    AddCommandOverride("sm_mute", Override_Command, ADMFLAG_ROOT);
    AddCommandOverride("sm_unmute", Override_Command, ADMFLAG_ROOT);
    AddCommandOverride("sm_silence", Override_Command, ADMFLAG_ROOT);
    AddCommandOverride("sm_unsilence", Override_Command, ADMFLAG_ROOT);

    return Plugin_Stop;
}

public Action:Timer_EndRound(Handle:timer)
{
    g_hRoundEndSlayTimer = INVALID_HANDLE;
    CS_TerminateRound(3.0, CSRoundEnd_CTWin);

    return Plugin_Stop;
}

public Action:Timer_ReloadPlugin(Handle:timer)
{
    LogMessage("Reloading now...");
    ServerCommand("sm plugins reload %s", PLUGIN_NAME);
    return Plugin_Stop;
}

public Action:DecNameChangeCount(Handle:timer, any:data)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_iNameChangeCounts[i] > 0)
            g_iNameChangeCounts[i] -= 1;
    }
    return Plugin_Continue;
}
