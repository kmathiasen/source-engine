
/* To do:
    make sure that on warday, once it's LR, g_iEndGame is set to ENDGAME_LR
*/

// ###################### GLOBALS ######################

// Includes.
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <regex>
#include <clientprefs>
#include <sdkhooks>
#include <hg_jbaio>

// Plugin definitions.
#define PLUGIN_NAME "hg_jbaio"
#define PLUGIN_VERSION "0.07"
#define SERVER_MOD "css"
#define MSG_PREFIX "\x01[\x04HG JB\x01]\x04"
#define MSG_PREFIX_CONSOLE "[HG JB]"

// Common string lengths.
#define LEN_STEAMIDS 24
#define LEN_IPS 17
#define LEN_CONVARS 255
#define LEN_INTSTRING 13 // Max val of signed 32-bit int is 2 billion something (12 places) +1 for null term
#define LEN_ITEMNAMES 32
#define LEN_HEXUUID 42
#define LEN_MAPCOORDS 64
#define LEN_COLOREDNAMES 96
#define LEN_VEC 3
#define LEN_RGBA 4

// Team definitions.
#define TEAM_UNASSIGNED 0
#define TEAM_SPEC 1
#define TEAM_PRISONERS 2
#define TEAM_GUARDS 3

// Menu definitions.
#define PERM_DURATION -1
#define MENU_TIMEOUT_NORMAL 30
#define MENU_TIMEOUT_QUICK 2

// Game definitions.
#define GAMETYPE_CSS 0
#define GAMETYPE_CSGO 1

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

new g_iEndGame = ENDGAME_LR;

// Cell tracking globals.
new bool:g_bAreCellsOpened = false;
new Handle:g_hServerOpenCellsTimer = INVALID_HANDLE;

// Rebel tracking globals.
new bool:g_bIsInvisible[MAXPLAYERS + 1];                    // NOTE: Rebeltracking considers invisible players to be rebels
new Handle:g_hMakeNonRebelTimers[MAXPLAYERS + 1];           // Array of timers for making a person not a rebel any more

// Sorry if offsets don't follow global formatting rules, it makes more sense to have it like this.
new m_iClip1 = -1;
new m_iAmmo = -1;
new m_hGroundEntity = -1;
new m_CollisionGroup = -1;
new m_iFOV = -1;

// Misc.
new bool:g_bHasPluginStarted = false;
new bool:g_bHasRoundStarted = true;
new bool:g_bGotToLR;
new bool:g_bShouldTrackDisconnect[MAXPLAYERS + 1];
new bool:g_bWasAuthedToJoin[MAXPLAYERS + 1];
new g_iRoundStartTime;
new g_iCommandDelay[MAXPLAYERS + 1];
new g_iGame;

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
#include "hg_jbaio_revertbranch/common.sp" // Good idea to keep at top
#include "hg_jbaio_revertbranch/convars.sp" // Good idea to keep at top
#include "hg_jbaio_revertbranch/findtarget.sp" // Good idea to keep at top
#include "hg_jbaio_revertbranch/db_connect.sp" // Good idea to keep at top
#include "hg_jbaio_revertbranch/tlock.sp"
#include "hg_jbaio_revertbranch/tlist.sp"
#include "hg_jbaio_revertbranch/chatfilter.sp"
#include "hg_jbaio_revertbranch/leadguard.sp"
#include "hg_jbaio_revertbranch/mapents.sp"
#include "hg_jbaio_revertbranch/mapcoords.sp"
#include "hg_jbaio_revertbranch/gunplant.sp"
#include "hg_jbaio_revertbranch/muting.sp"
#include "hg_jbaio_revertbranch/namecontrol.sp"
#include "hg_jbaio_revertbranch/prisonrep.sp"
#include "hg_jbaio_revertbranch/rebeltracking.sp"
#include "hg_jbaio_revertbranch/prisondice.sp"
#include "hg_jbaio_revertbranch/teamratio.sp"
#include "hg_jbaio_revertbranch/bomb.sp"
#include "hg_jbaio_revertbranch/warday.sp" // Must stay after leadguard
#include "hg_jbaio_revertbranch/colorednames.sp"
#include "hg_jbaio_revertbranch/anticamp.sp"
#include "hg_jbaio_revertbranch/buymenu.sp"
#include "hg_jbaio_revertbranch/teamswitch.sp" // Must stay after tlock and tlist
#include "hg_jbaio_revertbranch/respawn.sp" // Must stay after mapcoords
#include "hg_jbaio_revertbranch/stats.sp"
#include "hg_jbaio_revertbranch/lastrequest.sp" // Must stay after rebeltracking
#include "hg_jbaio_revertbranch/weapons.sp"
#include "hg_jbaio_revertbranch/joinspawn.sp"
#include "hg_jbaio_revertbranch/gag.sp"
#include "hg_jbaio_revertbranch/queue.sp"
#include "hg_jbaio_revertbranch/sungod.sp"
#include "hg_jbaio_revertbranch/invis.sp"
#include "hg_jbaio_revertbranch/tele.sp"
#include "hg_jbaio_revertbranch/strip.sp"
#include "hg_jbaio_revertbranch/thrhndrd.sp"

// ###################### EVENTS ######################

/* Bonbon's DEBUG thingy
public Action:OnClientCommand(client, args)
{
    new String:cmd[128];
    new String:first[28];

    GetCmdArg(0, first, sizeof(first));
    GetCmdArgString(cmd, sizeof(cmd));

    PrintToChatAll("%s - %s", first, cmd);
    return Plugin_Continue;
}
*/

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
    AddCommandListener(OnWeaponDrop, "drop");

    // Hook events.
    HookEvent("player_death", OnPlayerDeath); //EventHookMode_Pre
    HookEvent("player_hurt", OnPlayerHurt);
    HookEvent("round_start", OnRoundStart);
    HookEvent("round_end", OnRoundEnd);
    HookEvent("item_pickup", OnItemPickup);
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_team", OnPlayerTeamPost);

    // Register commands.
    RegConsoleCmd("say", Command_Say);
    RegConsoleCmd("say_team", Command_SayTeam);

    // Tasks.
    MapEnts_OnPluginStart();
    MapCoords_OnPluginStart();
    Tlock_OnPluginStart();
    Tlist_OnPluginStart();
    PrisonRep_OnPluginStart();
    NameControl_OnPluginStart();
    Muting_OnPluginStart();
    GunPlant_OnPluginStart();
    ChatFilter_OnPluginStart();
    ClrNms_OnPluginStart();
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

    // Hook SDKHook events for each client.
    for(new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_WeaponSwitch, OnWeaponSwitch);
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            SDKHook(i, SDKHook_PostThinkPost, Invis_OnPostThinkPost);
        }
    }

    // Find entity offsets
    m_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
    m_iAmmo = FindSendPropInfo("CCSPlayer", "m_iAmmo");
    m_hGroundEntity = FindSendPropOffs("CBasePlayer", "m_hGroundEntity");
    m_CollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
    m_iFOV = FindSendPropOffs("CBasePlayer", "m_iFOV");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Register PrisonRep natives to be used by other plugins (gangs).
    CreateNative("PrisonRep_AddPoints", Native_PrisonRep_AddPoints);
    CreateNative("PrisonRep_GetPoints", Native_PrisonRep_GetPoints);
    CreateNative("PrisonRep_AddPoints_Offline", Native_PrisonRep_AddPoints_Offline);

    decl String:game[PLATFORM_MAX_PATH];
    GetGameFolderName(game, sizeof(game));

    if (StrEqual(game, "cstrike"))
        g_iGame = GAMETYPE_CSS;

    else
        g_iGame = GAMETYPE_CSGO;

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

    // Read & hook various ConVars.
    RebelTrk_OnConfigsExecuted();
    AntiCamp_OnConfigsExecuted();
    NameControl_OnConfigsExecuted();
    Warday_OnConfigsExecuted();
    LeadGuard_OnConfigsExecuted();
    Muting_OnConfigsExecuted();
    PrisonRep_OnConfigsExecuted();
    PrisonDice_OnConfigsExecuted();
    //MapEnts_OnConfigsExecuted();
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

    // Add more spawn points.
    if (g_iGame == GAMETYPE_CSS)
    {
        CreateSpawns("info_player_terrorist", 34);
        CreateSpawns("info_player_counterterrorist", 16);
    }

    // Debug for april fools.
    //AprilFools_OnMapStart();
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    ServerCommand("mp_limitteams 0");

    g_iEndGame = ENDGAME_NONE;
    g_bAreCellsOpened = false;
    g_iRoundStartTime = GetTime();

    // Set the cells opened by server
    if (g_hServerOpenCellsTimer != INVALID_HANDLE)
        CloseHandle(g_hServerOpenCellsTimer);
    g_hServerOpenCellsTimer = CreateTimer(60.0, ServerOpenCells);

    // Perform applicable tasks.
    Muting_OnRndStrt_General();
    RebelTrk_OnRndStrt_General();
    PrisonDice_OnRndStrt_General();
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

    // Let OnPlayerSpawn know the round has started.
    // This way, it can track whether or not to unmute players, who have been respawned by gangs
    g_bHasRoundStarted = true;

    // Slay all players in 6 minutes (round end) (first cancel possible pending timer).
    if (g_hRoundEndSlayTimer != INVALID_HANDLE)
        CloseHandle(g_hRoundEndSlayTimer);
    g_hRoundEndSlayTimer = CreateTimer(60.0 * float(GetConVarInt(FindConVar("mp_roundtime"))), Timer_EndRound);

    // Iterate all players.
    for(new i = 1; i <= MaxClients; i++)
    {
        // Perform applicable tasks.
        Bomb_OnRndStrt_EachClient(i);
        RebelTrk_OnRndStrt_EachClient(i);
        PrisonDice_OnRndStrt_EachClient(i);

        g_iCommandDelay[i] -= 2;

        // If player is valid...
        if (IsClientInGame(i))
        {
            // Get client team.
            new team = GetClientTeam(i);

            // Strip weapons.
            StripWeps(i);

            // Give them armor and a deagle if they're a CT
            if (GetClientTeam(i) == TEAM_GUARDS)
            {
                SetEntProp(i, Prop_Send, "m_ArmorValue", 100);
                GivePlayerItem(i, "weapon_deagle");
            }

            // Perform applicable tasks.
            RebelTrk_OnRndStrt_EachValid(i);
            PrisonDice_OnRndStrt_EachValid(i, team);
            LeadGuard_OnRndStrt_EachValid(i, team);
        }
    }
}

public OnRoundEnd(Handle:event, const String:name[], bool:db)
{
    if (GetEventInt(event, "winner") == TEAM_PRISONERS && g_bGotToLR)
        SetTeamScore(TEAM_PRISONERS, GetTeamScore(TEAM_PRISONERS) - 1);

    g_bGotToLR = false;
    g_bHasRoundStarted = false;

    LR_OnRoundEnd();
    ClearArray(g_hGiveAmmo);
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
}
OnDbConnect_Bans(Handle:conn)
{
    Tlist_OnDbConnect(conn);
}
OnDbConnect_NC(Handle:conn)
{
    NameControl_OnDbConnect(conn);
    ChatFilter_OnDbConnect(conn);
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_PostThinkPost, Invis_OnPostThinkPost);

    g_bWasAuthedToJoin[client] = false;

    // Perform applicable tasks.
    Muting_OnClientPutInServer(client);
    Tlock_OnClientPutInServer(client);
    Tlist_OnClientPutInServer(client);
    RebelTrk_OnClientPutInServer(client);
    LeadGuard_OnClientPutInServer(client);
}

public OnClientAuthorized(client, const String:auth[])
{
    // CS:GO Compatibility.
    decl String:steamid[32];
    Format(steamid, sizeof(steamid), auth);
    ReplaceString(steamid, sizeof(steamid), "STEAM_1", "STEAM_0");

    // Exit if the joining player is a bot.
    if (IsFakeClient(client) || strcmp(steamid, "BOT", true) == 0)
        return;

    // Perform applicable tasks.
    PrisonRep_OnClientAuthorized(client, steamid);
    ClrNms_OnClientAuthorized(client); // Make sure this stays after PrisonRep_OnClientAuthorized()
    Gag_OnClientAuthorized(client, steamid);
}

public OnClientDisconnect(client)
{
    // Tasks.
    LeadGuard_OnClientDisconnect(client);
    NameControl_OnClientDisconnect(client);
    ClrNms_OnClientDisconnect(client);
    RebelTrk_OnClientDisconnect(client);
    JoinSpawn_OnClientDisconnect(client);
    Warday_OnClientDisconnect();
    Queue_OnClientDisconnect(client);
    LR_OnClientDisconnect(client);
    Muting_OnClientDisconnect(client);

    // Just in case.
    CheckEndGame();
}

public Action:OnJoinTeam(client, const String:command[], argc)
{
    // Ensure client is valid player.
    if (!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    // What team did the client join?
    decl String:info[7];
    GetCmdArg(1, info, sizeof(info));
    new team = StringToInt(info); // 0=autoassign, 1=spec, 2=prisoner, 3=guard

    if (g_iGame == GAMETYPE_CSGO && (team < TEAM_SPEC || team > TEAM_GUARDS))
        return Plugin_Handled;

    if (GetClientTeam(client) == team && team)
    {
      //PrintCenterText(lient, "Lol, you're already on that team.");
        return Plugin_Handled;
    }

    if (team == TEAM_PRISONERS &&
        GetTeamClientCount(TEAM_PRISONERS) >= 16 &&
        g_iGame == GAMETYPE_CSGO)
    {
        new old_team = GetClientTeam(client);

        CS_SwitchTeam(client, TEAM_PRISONERS);
        SetEntProp(client, Prop_Send, "m_iTeamNum", TEAM_PRISONERS);

        if (old_team <= TEAM_SPEC)
            CS_RespawnPlayer(client);

        if (IsPlayerAlive(client))
            CreateTimer(0.1, DelaySlay, client);
        return Plugin_Handled;
    }

    new Action:result = CanJoinTeam(client, team);
    if (result == Plugin_Continue)
        g_bWasAuthedToJoin[client] = true;

    return CanJoinTeam(client, team);
}

Action:CanJoinTeam(client, team)
{
    // Allow if joining spec.
    if (team == TEAM_SPEC)
        return Plugin_Continue;

    // The chose auto assign, deny and re-direct them to join Prisoner team.
    if (team == TEAM_UNASSIGNED)
    {
        // Force them to join terrorist.
        FakeClientCommandEx(client, "jointeam %i", TEAM_PRISONERS);

        // Don't let the server auto assign them to CT.
        return Plugin_Handled;
    }

    // Applicable tasks.
    Muting_OnJoinTeam(client, team);
    if (!JoinSpawn_OnJoinTeam(client))
        return Plugin_Handled;
    if (!TeamRatio_OnJoinTeam(client, team))
        return Plugin_Handled;
    if (team == TEAM_GUARDS)
    {
        if (!Tlock_AllowedToJoinGuards(client) || !Tlist_AllowedToJoinGuards(client))
        {
            if (IsClientInGame(client))
            {
                EmitSoundToClient(client, g_sSoundDeny);
                PrintToChatAll("%s Freekiller \x03%N\x04 was blocked from joining Guards", MSG_PREFIX, client);
            }

            return Plugin_Handled;
        }
    }
    if (!NameControl_OnJoinTeam(client))
        return Plugin_Handled;

    // Strip weapons.
    if (IsPlayerAlive(client))
    {
        new Handle:data = CreateDataPack();
        WritePackCell(data, client);
        WritePackCell(data, 1);
        CreateTimer(2.0, StripWeapsDelay, data);
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

    if (g_iGame == GAMETYPE_CSGO &&
        team == TEAM_GUARDS &&
        !g_bWasAuthedToJoin[client] &&
        !CanJoinTeam(client, TEAM_GUARDS))
        ChangeClientTeam(client, TEAM_PRISONERS);

    g_bWasAuthedToJoin[client] = false;
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_iNonRebelAt[client] = 0;

    // Player spawn fires once a player joins, and before they're activated.
    // So make sure we don't unmute them!
    // http://www.eventscripts.com/pages/Event_sequences

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    // Because of gangs, it's possible for people to respawn, and they will still be red
    // If they were red before they died.
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, 255, 255, 255, 255);

    // Noblock
    SetEntData(client, m_CollisionGroup, 2, 4, true);

    // Tasks.
    Muting_OnPlayerSpawn(client);
    Invis_OnPlayerSpawn(client);

    // Give them a health bonus to even out the game if they're a CT.
    // Dependent on how many Ts there are, because of the recent growth in server population.
    // It is impossible to lead with 20+ Ts.
    if (GetClientTeam(client) == TEAM_GUARDS)
    {
        new health_amount = RoundToNearest(GetTeamClientCount(TEAM_PRISONERS) * GetConVarFloat(g_hCvCtHealthBonusPerT));
        SetEntityHealth(client, GetClientHealth(client) + health_amount);
    }
}

public OnClientSettingsChanged(client)
{
    // Ensure client is valid player.
    if (!IsClientInGame(client))
        return;

    // Exit if the joining player is a bot.
    if (IsFakeClient(client))
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

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    // Exit if end-game time.
    if (g_iEndGame != ENDGAME_NONE && g_iEndGame != ENDGAME_WARDAY)
    {
        if (g_iEndGame == ENDGAME_LR)
            return KF_OnTakeDamage(victim, attacker, damage);

        return Plugin_Continue;
    }

    // Exit if the damage was self inflicted or caused by the world.
    if ((attacker == victim) || (attacker == 0))
        return Plugin_Continue;

    // Damage was caused by an entity, such as obstacle water
    if (attacker > MAXPLAYERS)
        return Plugin_Continue;

    // Ensure clients are valid players.
    if ((!IsClientInGame(attacker)) || (!IsClientInGame(victim)))
        return Plugin_Continue;

    // Get teams.
    new attacker_team = GetClientTeam(attacker);
    new victim_team = GetClientTeam(victim);

    // Exit if the damage was friendly-fire (which should be off anyway).
    if (attacker_team == victim_team)
        return Plugin_Continue;

    // Exit if bot.
  //if (IsFakeClient(attacker) || IsFakeClient(victim)) return Plugin_Continuel

    // Perform applicable tasks.
    switch(attacker_team)
    {
        case TEAM_PRISONERS:
        {
            PrisonRep_OnPrisonerHurtGuard(attacker, victim);

            if (g_bSuperKnife[attacker])
            {
                decl String:weapon[LEN_ITEMNAMES];
                GetClientWeapon(attacker, weapon, sizeof(weapon));

                if (StrEqual(weapon, "weapon_knife"))
                {
                    g_bSuperKnife[attacker] = false;
                    damage += float(GetClientHealth(victim)) + 101.0;
                    return Plugin_Changed;
                }
            }

            if (Warday_ModifyDamage(victim, attacker, damage, damagetype))
                return Plugin_Changed;
        }
        case TEAM_GUARDS:
        {
            if (!BuyMenu_PlayerHurt(attacker))
                return Plugin_Handled;
            if (!Warday_PlayerHurt(attacker))
                return Plugin_Handled;
            if (!Weapons_PlayerHurt(attacker, victim))
                return Plugin_Handled;
            if (Warday_ModifyDamage(victim, attacker, damage, damagetype))
                return Plugin_Changed;
            if (g_iEndGame == ENDGAME_NONE)
                RebelTrk_OnGuardHurtPrisoner(attacker, victim);
        }
    }

    return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
    // csgo
    // GetEntPropString(entity, Prop_Data, "m_iName", buffer, size);

    if (entity <= MaxClients)
        return;

    // Should we give it ammo?
    Weapons_OnEntityCreated(entity, classname);

    // LR Stuff
    DB_OnEntityCreated(entity, classname);

    if (StrEqual(classname, "env_particlesmokegrenade"))
    {
        // There's no need to loop through all smokegrenade_projectile.
        // Because this event will fire every time a smoke grenade is exploded.

        new ent = -1;
        new prev = 0;

        while ((ent = FindEntityByClassname(ent, "smokegrenade_projectile")) != -1)
        {
            if (prev)
                RemoveEdict(prev);
            prev = ent;
        }

        if (prev) RemoveEdict(prev);
    }
}

public OnPlayerHurt(Handle:event, const String:name[], bool:db)
{
    new userid = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new damage = GetEventInt(event, "dmg_health");

    decl String:weapon[MAX_NAME_LENGTH];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    new bool:kill = GetClientHealth(userid) <= 0;

    // It's not in LR, so treat it normally.
    if (attacker &&
        userid &&
        attacker != userid &&
        GetClientTeam(attacker) == TEAM_PRISONERS &&
        GetClientTeam(userid) == TEAM_GUARDS &&
        g_iEndGame == ENDGAME_NONE &&
        damage > 1)
        RebelTrk_OnPrisonerHurtGuard(attacker, kill);

    // It's in LR, so we have to let lastrequest.sp do some special checks.
    if (g_iEndGame == ENDGAME_LR && !kill)
        LR_OnPlayerDamaged(userid, attacker, false, weapon);
}

public OnPlayerDeath(Handle:event, const String:eventname[], bool:dontBroadcast)
{
    // Get client IDs from event args.
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));

    decl String:weapon[32];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    // LR Stuff.
    if (g_iEndGame == ENDGAME_LR)
        LR_OnPlayerDamaged(victim, attacker, true, weapon);

    // Track them so they can't rejoin to respawn.
    JoinSpawn_OnPlayerDeath(victim);

    // Should we start the search and destroy early?
    Warday_OnPlayerDeath();

    // Mute players that die.
    Muting_OnPlayerDeath(victim);

    new bool:was_lead = (g_iLeadGuard == victim);

    // If the Lead Guard dies, reset the lead.
    if (g_iEndGame == ENDGAME_NONE) LeadGuard_OnPlayerDeath(victim);

    // Count living Guards and Prisoners and see if we need to go into LR mode.
    CheckEndGame();

    // If the damage was self inflicted or caused by the world...
    if ((attacker == victim) || (attacker == 0))
        return;

    // Ensure players are in-game.
    if (!IsClientInGame(victim) || !IsClientInGame(attacker))
    {
        // Explode them if they have the bomb.
        Bomb_OnPlayerDeath(victim);

        // Reset dead player trackers.
        RebelTrk_ResetTrackers(victim);
        return;
    }

    // Exit if the damage was caused by a bot (it's not expected that bots will be used with this plugin).
    if (IsFakeClient(attacker) || IsFakeClient(victim))
        return;

    // Give the attacker more health if they used a knife.
    Weapons_OnPlayerDeath(attacker);

    // Get teams.
    new attacker_team = GetClientTeam(attacker);
    new victim_team = GetClientTeam(victim);

    // Exit if the damage was friendly-fire (which should be off anyway).
    if (attacker_team == victim_team)
        return;

    // Do stuff based on team.
    switch(attacker_team)
    {
        case TEAM_PRISONERS:
        {
            if (g_iEndGame == ENDGAME_NONE)
                PrisonRep_OnPrisonerKilledGuard(attacker, was_lead);
        }
        case TEAM_GUARDS:
        {
            if (g_iEndGame == ENDGAME_NONE)
                RebelTrk_OnGuardKilledPrisoner(attacker, victim);

            else if (g_iEndGame == ENDGAME_LR)
            {
                new ct_index = FindValueInArray(g_hLRCTs, attacker);
                if (ct_index == -1 || FindValueInArray(g_hLRTs, victim) != ct_index)
                    RebelTrk_OnGuardKilledPrisoner(attacker, victim);
            }
        }
    }

    // Reset dead player trackers.
    RebelTrk_ResetTrackers(victim);

    // Explode them if they have the bomb.
    Bomb_OnPlayerDeath(victim);
}

public Action:OnWeaponDrop(client, const String:command[], args)
{
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

public OnItemPickup(Handle:event, const String:eventname[], bool:dontBroadcast)
{
    // Get client from event args.
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // Exit if client is dead.
    if (!IsPlayerAlive(client))
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
    Invis_OnWeaponSwitch(client, weapon);
    RebelTrk_OnWeaponSwitch(client, weapon);
}

// ###################### COMMANDS ######################

public Action:Command_Say(client, args)
{
    // Is it a real client?
    if ((client <= 0) || (!IsClientInGame(client)))
        return Plugin_Continue;

    // Did the player type a command, such as !pd or /pd
    if (IsChatTrigger())
    {
        decl String:command[2];
        GetCmdArg(1, command, sizeof(command));

        // Stop, if the command was meant to be silent
        if (command[0] == '/')
            return Plugin_Stop;

        // Prevent command spam on round start
        if (!g_bHasRoundStarted || (GetTime() - g_iRoundStartTime) < 5)
            return Plugin_Stop;
    }

    // Command wasn't a chat trigger, so check if the player wanted to leads
    else
        LeadGuard_CheckLead(client);

    // Perform applicable tasks.
    if (!Gag_AllowedToUseChat(client))
        return Plugin_Stop;
    if (ClrNms_ApplyColor(client))
        return Plugin_Handled;

    // Else.
    return Plugin_Continue;
}

public Action:Command_SayTeam(client, args)
{
    // Is it a real client?
    if ((client <= 0) || (!IsClientInGame(client)))
        return Plugin_Continue;

    // Did the player type a command, such as !pd or /pd
    if (IsChatTrigger())
    {
        decl String:command[2];
        GetCmdArg(1, command, sizeof(command));

        // Stop, if the command was meant to be silent
        if (command[0] == '/')
            return Plugin_Stop;

        // Prevent command spam on round start
        if (!g_bHasRoundStarted || (GetTime() - g_iRoundStartTime) < 5)
            return Plugin_Stop;
    }

    // Perform applicable tasks.
    new bool:teamchat = true;
    if (!Gag_AllowedToUseChat(client))
        return Plugin_Stop;
    if (ClrNms_ApplyColor(client, teamchat))
        return Plugin_Handled;

    // Else.
    return Plugin_Continue;
}

// ###################### FUNCTIONS ######################


SetWeaponAmmo(weapon, owner, clip=0, ammo=-1)
{
    if (clip > -1)
        SetEntData(weapon, m_iClip1, clip);

    if (ammo > -1)
        SetEntData(owner, m_iAmmo +
                   GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") * 4,
                   ammo, _, true);
}

CheckEndGame()
{
    if (g_iEndGame == ENDGAME_NONE || g_iEndGame == ENDGAME_WARDAY)
    {
        new total_prisoners;
        new total_guards;
        new this_team;
        new last_guard;

        for(new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                if (IsPlayerAlive(i))
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
            if ((total_guards > 1) && (total_prisoners > 2))
                break;
        }
        // If there are 1 or 2 prisoners.
        if (total_guards == 1)
        {
            g_iEndGame = ENDGAME_LASTGUARD;
            EmitSoundToAll(g_sSoundAlarm);
            PrintCenterTextAll("LAST GUARD");
            PrintHintTextToAll("LAST GUARD");
            PrintToChatAll("%s LAST GUARD came before LR.", MSG_PREFIX);
            PrintToChatAll("%s \x03%N\x04 can kill \x03ANY\x04 remaining terrorist.", MSG_PREFIX, last_guard);

            // Reset rebel status and colors.
            RebelTrk_EndGameTime();

            /*
                Reconnect to database.
                Why on LR?  Because the perfect time to do a "sm plugins reload hg_jbaio" is after LR.
                    (stuff like Lead CT wont get messed up)
                    So we need to do a DB_Connect here (after LR, BUT hopefully BEFORE someone reloads the plugin).
                        That way, people's Rep for the round will get saved.
            */
            CreateTimer(0.1, DB_Connect);
            return;
        }
        else if (total_prisoners <= 2)
        {
            SetTeamScore(TEAM_GUARDS, GetTeamScore(TEAM_GUARDS) + 1);
            g_bGotToLR = true;

            g_iEndGame = ENDGAME_LR;
            EmitSoundToAll(g_sSoundAlarm);
            PrintCenterTextAll("LR TIME");
            PrintHintTextToAll("LR TIME");
            PrintToChatAll("%s LR TIME", MSG_PREFIX);

            // Reset rebel status and colors.
            RebelTrk_EndGameTime();

            // Give lead credit for reaching LR.
            LeadGuard_EndGameTime();

            /*
                Reconnect to database.
                Why on LR?  Because the perfect time to do a "sm plugins reload hg_jbaio" is after LR.
                    (stuff like Lead CT wont get messed up)
                    So we need to do a DB_Connect here (after LR, BUT hopefully BEFORE someone reloads the plugin).
                        That way, people's Rep for the round will get saved.
            */
            CreateTimer(0.1, DB_Connect);
            return;
        }
    }
}

public Action:ServerOpenCells(Handle:timer)
{
    if (!g_bAreCellsOpened)
    {
        g_bAreCellsOpened = true;
        Warday_CellsOpened();
    }

    g_hServerOpenCellsTimer = INVALID_HANDLE;
}

public Action:DisplayPlayerCommands(Handle:timer, any:client)
{
    if (!IsClientInGame(client))
        return Plugin_Continue;

    // Is admin?
    new AdminId:admid = GetUserAdmin(client);
    if (admid != INVALID_ADMIN_ID)
    {
        PrintToChat(client, "%s \x01sm_coloredname\x04 (type in console)", MSG_PREFIX);
        PrintToChat(client, "%s The following commands take \x03partial name", MSG_PREFIX);
        PrintToChat(client, "%s \x01or \x03part of name with spaces \x04(\x01in quotes\x04)", MSG_PREFIX);
        PrintToChat(client, "%s \x01or \x03Steam ID \x04(STEAM_0:X:XXXXXXXX)", MSG_PREFIX);
        PrintToChat(client, "%s \x01or \x03userid number \x04(from status)", MSG_PREFIX);
        PrintToChat(client, "%s \x03!\x01movet\x04, \x03!\x01movect\x04, \x03!\x01movespec\x04, \x03!\x01mute\x04, \x03!\x01unmute", MSG_PREFIX);
        PrintToChat(client, "%s \x03!\x01tlist\x04, \x03!\x01untlist\x04, \x03!\x01lock\x04, \x03!\x01unlock", MSG_PREFIX);
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
    ResetPack(data);
    new client = ReadPackCell(data);
    new knife = ReadPackCell(data);
    new bool:giveknife = false;
    if (knife > 0)
        giveknife = true;
    CloseHandle(data);
    StripWeps(client, giveknife);
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

    // creats "tocreate" amount of spawns.
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

    if (g_iGame == GAMETYPE_CSS)
        CS_TerminateRound(3.0, CSRoundEnd_CTWin);

    if (!g_bGotToLR)
        SetTeamScore(TEAM_GUARDS, GetTeamScore(TEAM_GUARDS) + 1);
    return Plugin_Stop;
}

public Action:Timer_ReloadPlugin(Handle:timer)
{
    LogMessage("Reloading now...");
    ServerCommand("sm plugins reload %s", PLUGIN_NAME);
    return Plugin_Stop;
}
