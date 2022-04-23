/**
 * Title: BHop Timer for HellsGamers
 * Author: Bonbon
 *
 * To Do:
 *  Maybe change to use MySQL DB (not up to me)
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#pragma semicolon 1

#define STARTMODE_FINISHED 0
#define STARTMODE_AT_START 1
#define STARTMODE_IN_PROGRESS 2
#define STARTMODE_PAUSED 3

#define TEAM_SPEC 1
#define TEAM_T 2
#define TEAM_CT 3

#define SPECMODE_FIRST_PERSON 4
#define SPECMODE_THIRD_PERSON 5

#define FPS_300P_INDEX 0
#define FPS_300M_INDEX 1

#define TOPMENU_REGULAR 0
#define TOPMENU_SW 1
#define TOPMENU_W 2

#define POINT_HEIGHT 69.0
#define TIMER_INTERVAL 0.3
#define DEFAULT_TIMEOUT 30
#define MAX_SAVE_LOCATIONS 5

#define MSG_PREFIX "\x03[Timer]: \x01"

enum PlayerData
{
    PD_Regular = 0,
    PD_SW,
    PD_W
}

enum RunData
{
    RD_BestTime = 0,
    RD_BestTime_FPS,
    RD_BestTime_Jumps,
    RD_BestJumps,
    RD_BestJumps_FPS,
    RD_BestJumps_Time
}

enum MenuData
{
    MD_BestTime = 0,
    MD_BestJumps
}

/* Stores their current run mode, a PlayerData object */
new PlayerData:iRunMode[MAXPLAYERS + 1];

/*
 * arr[client][PD_Object][FPS_300P_INDEX] = Milestone 300+ FPS
 * arr[client][PD_Object][FPS_300M_INDEX] = Milestone < 300 FPS
 */

new iCachedBestJumps[MAXPLAYERS + 1][PlayerData][2];
new Float:fCachedBestTimes[MAXPLAYERS + 1][PlayerData][2];

/*
 * sKeyNames[PD_Object][FPS_INDEX][RD_Index] = "SQL Key"
 */

new String:sKeyNames[PlayerData][2][RunData][32];

/*
 * hTopMenus[PD_Object][FPS_INDEX][MD_Index]
 */

new Handle:hTopMenus[PlayerData][MenuData][2];

new iSpriteBeam = -1;
new iSpriteRing = -1;
new iColorBlue[4] = {50, 75, 255, 255};
new iClientJumps[MAXPLAYERS + 1];
new iClientStartMode[MAXPLAYERS + 1];

new iClientFPS[MAXPLAYERS + 1];
new iSpeedUnit = 0;
new iAlpha = 50;
new iMaxSaves = 3;
new iMaxScouts = 3;
new m_hGroundEntity = -1;

new bool:bDisabledForMap;
new bool:bAlreadyStarted[MAXPLAYERS + 1];
new bool:bInDB[MAXPLAYERS + 1];
new bool:bShowHud[MAXPLAYERS + 1];

/* Note that "width" and "length" are actually half width, half length */
new Float:fCachedStart[3];
new Float:fCachedStartWidth;
new Float:fCachedStartLength;
new Float:fCachedEnd[3];
new Float:fCachedEndWidth;
new Float:fCachedEndLength;
new Float:fTempTopLeft[3];
new Float:fTempBottomRight[3];
new Float:fClientTimes[MAXPLAYERS + 1];

/* ConVar Handles */
new Handle:hUpdateTopMenusEvery = INVALID_HANDLE;
new Handle:hSpeedUnit = INVALID_HANDLE;
new Handle:hAlpha = INVALID_HANDLE;
new Handle:hMaxSaves = INVALID_HANDLE;
new Handle:hMaxScouts = INVALID_HANDLE;
new Handle:hLowGravAmount = INVALID_HANDLE;
new Handle:hSpamEvery = INVALID_HANDLE;

/* Menu Handles */
new Handle:hMainMenu = INVALID_HANDLE;
new Handle:hHelpMenu = INVALID_HANDLE;

/* Misc Handles */
new Handle:hSpawnPoints = INVALID_HANDLE;
new Handle:hDB = INVALID_HANDLE;

new String:sSpawnPointsPath[PLATFORM_MAX_PATH];
new String:sCachedMap[MAX_NAME_LENGTH];
new String:sError[256];

new String:sMenuTitles[MenuData][32];
new String:sMenuFPSTitles[MenuData][32];

#include "timer/database.sp"
#include "timer/admin.sp"
#include "timer/chat.sp"
#include "timer/commands.sp"
#include "timer/remover.sp"
#include "timer/stats.sp"
#include "timer/tele.sp"

/* ----- Plugin Info ----- */


public Plugin:myinfo =
{
    name = "BHop Timer for Hells Gamers",
    author = "Bonbon",
    description = "Keeps track of players best BHop runs on a per map basis",
    version = "1.0.0",
    url = "http://hellsgamers.com/"
}


/* ----- Events ----- */


public OnPluginStart()
{
    BuildPath(Path_SM,
              sSpawnPointsPath, sizeof(sSpawnPointsPath), "data/bhoptimer.txt");

    hSpawnPoints = CreateKeyValues("locations");
    if (FileExists(sSpawnPointsPath))
        FileToKeyValues(hSpawnPoints, sSpawnPointsPath);

    AddCommandListener(OnJoinTeam, "jointeam");

    HookEvent("player_team", OnPlayerChangeTeam);
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_jump", OnPlayerJump);
    HookEvent("player_hurt", OnPlayerHurt);
    HookEvent("player_death", OnPlayerDeath);
    HookEvent("round_start", OnRoundStart);
    HookEvent("round_end", OnRoundEnd);

    hUpdateTopMenusEvery = CreateConVar("timer_update_top_every", "180.0",
                                        "Every x seconds to update the top menus");

    hAlpha = CreateConVar("timer_player_alpha", "50",
                          "How invisible the player is, 0 = fully invisible, 255 = fully visible",
                          0, true, 0.0, true, 255.0);
    
    hSpeedUnit = CreateConVar("timer_speed_unit",
                              "0", "0 = regular units, 1 = km/h");

    hMaxSaves = CreateConVar("timer_max_save_locations", "3",
                             "The maximum number of locations a client can save in a map",
                             0, true, 0.0, true, float(MAX_SAVE_LOCATIONS));

    hMaxScouts = CreateConVar("timer_max_scouts", "3",
                              "Maximum number of scouts a player can get each round");

    hLowGravAmount = CreateConVar("timer_lowgrav_amount", "0.666",
                                  "what percentage (as decimal) to set a players gravity to when they use !lowgrav (>= 1 disables)");

    hSpamEvery = CreateConVar("timer_spam_every", "60",
                              "Every <x> seconds to tell people to type !timer");

    HookConVarChange(hSpeedUnit, OnConVarChanged);
    HookConVarChange(hAlpha, OnConVarChanged);
    HookConVarChange(hMaxSaves, OnConVarChanged);
    HookConVarChange(hMaxScouts, OnConVarChanged);

    sKeyNames[PD_Regular][FPS_300P_INDEX][RD_BestTime] = "besttime_300p";
    sKeyNames[PD_Regular][FPS_300P_INDEX][RD_BestTime_FPS] = "besttime_300p_fps";
    sKeyNames[PD_Regular][FPS_300P_INDEX][RD_BestTime_Jumps] = "besttime_300p_jumps";
    sKeyNames[PD_Regular][FPS_300P_INDEX][RD_BestJumps] = "bestjumps_300p";
    sKeyNames[PD_Regular][FPS_300P_INDEX][RD_BestJumps_FPS] = "bestjumps_300p_fps";
    sKeyNames[PD_Regular][FPS_300P_INDEX][RD_BestJumps_Time] = "bestjumps_300p_time";

    sKeyNames[PD_Regular][FPS_300M_INDEX][RD_BestTime] = "besttime_300m";
    sKeyNames[PD_Regular][FPS_300M_INDEX][RD_BestTime_FPS] = "besttime_300m_fps";
    sKeyNames[PD_Regular][FPS_300M_INDEX][RD_BestTime_Jumps] = "besttime_300m_jumps";
    sKeyNames[PD_Regular][FPS_300M_INDEX][RD_BestJumps] = "bestjumps_300m";
    sKeyNames[PD_Regular][FPS_300M_INDEX][RD_BestJumps_FPS] = "bestjumps_300m_fps";
    sKeyNames[PD_Regular][FPS_300M_INDEX][RD_BestJumps_Time] = "bestjumps_300m_time";

    sKeyNames[PD_SW][FPS_300P_INDEX][RD_BestTime] = "besttime_sw_300p";
    sKeyNames[PD_SW][FPS_300P_INDEX][RD_BestTime_FPS] = "besttime_sw_300p_fps";
    sKeyNames[PD_SW][FPS_300P_INDEX][RD_BestTime_Jumps] = "besttime_sw_300p_jumps";
    sKeyNames[PD_SW][FPS_300P_INDEX][RD_BestJumps] = "bestjumps_sw_300p";
    sKeyNames[PD_SW][FPS_300P_INDEX][RD_BestJumps_FPS] = "bestjumps_sw_300p_fps";
    sKeyNames[PD_SW][FPS_300P_INDEX][RD_BestJumps_Time] = "bestjumps_sw_300p_time";

    sKeyNames[PD_SW][FPS_300M_INDEX][RD_BestTime] = "besttime_sw_300m";
    sKeyNames[PD_SW][FPS_300M_INDEX][RD_BestTime_FPS] = "besttime_sw_300m_fps";
    sKeyNames[PD_SW][FPS_300M_INDEX][RD_BestTime_Jumps] = "besttime_sw_300m_jumps";
    sKeyNames[PD_SW][FPS_300M_INDEX][RD_BestJumps] = "bestjumps_sw_300m";
    sKeyNames[PD_SW][FPS_300M_INDEX][RD_BestJumps_FPS] = "bestjumps_sw_300m_fps";
    sKeyNames[PD_SW][FPS_300M_INDEX][RD_BestJumps_Time] = "bestjumps_sw_300m_time";

    sKeyNames[PD_W][FPS_300P_INDEX][RD_BestTime] = "besttime_w_300p";
    sKeyNames[PD_W][FPS_300P_INDEX][RD_BestTime_FPS] = "besttime_w_300p_fps";
    sKeyNames[PD_W][FPS_300P_INDEX][RD_BestTime_Jumps] = "besttime_w_300p_jumps";
    sKeyNames[PD_W][FPS_300P_INDEX][RD_BestJumps] = "bestjumps_w_300p";
    sKeyNames[PD_W][FPS_300P_INDEX][RD_BestJumps_FPS] = "bestjumps_w_300p_fps";
    sKeyNames[PD_W][FPS_300P_INDEX][RD_BestJumps_Time] = "bestjumps_w_300p_time";

    sKeyNames[PD_W][FPS_300M_INDEX][RD_BestTime] = "besttime_w_300m";
    sKeyNames[PD_W][FPS_300M_INDEX][RD_BestTime_FPS] = "besttime_w_300m_fps";
    sKeyNames[PD_W][FPS_300M_INDEX][RD_BestTime_Jumps] = "besttime_w_300m_jumps";
    sKeyNames[PD_W][FPS_300M_INDEX][RD_BestJumps] = "bestjumps_w_300m";
    sKeyNames[PD_W][FPS_300M_INDEX][RD_BestJumps_FPS] = "bestjumps_w_300m_fps";
    sKeyNames[PD_W][FPS_300M_INDEX][RD_BestJumps_Time] = "bestjumps_w_300m_time";

    sMenuTitles[MD_BestTime] = "Shortest Times";
    sMenuTitles[MD_BestJumps] = "Least Jumps";

    sMenuFPSTitles[FPS_300P_INDEX] = "(>= 300 FPS)";
    sMenuFPSTitles[FPS_300M_INDEX] = "(< 300 FPS)";

    CreateTimer(TIMER_INTERVAL, Timer_CheckClientStatus, _, TIMER_REPEAT);
    ConnectToDB();
    CreateOneTimeMenus();

    DB_OnPluginStart();
    Admin_OnPluginStart();
    Stats_OnPluginStart();
    Tele_OnPluginStart();
    Commands_OnPluginStart();
    Chat_OnPluginStart();

    m_hGroundEntity = FindSendPropOffs("CBasePlayer", "m_hGroundEntity");

    AutoExecConfig(true);

    /* For FindTarget */
    LoadTranslations("common.phrases");
}

public OnConVarChanged(Handle:convar, const String:sOld[], const String:sNew[])
{
    if (convar == hSpeedUnit)
        iSpeedUnit = GetConVarInt(hSpeedUnit);

    else if (convar == hAlpha)
        iAlpha = GetConVarInt(hAlpha);

    else if (convar == hMaxSaves)
        iMaxSaves = GetConVarInt(hMaxSaves);

    else if (convar == hMaxScouts)
        iMaxScouts = GetConVarInt(hMaxScouts);
}

public OnConfigsExecuted()
{
    new Float:interval = GetConVarFloat(hUpdateTopMenusEvery);

    CreateTimer(interval, UpdateTopMenus, RoundToNearest(interval),
                TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

    CreateTimer(20.0, ShowPoints, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(GetConVarFloat(hSpamEvery), Timer_DisplayAdvert, _,
                TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnDBConnect()
{
    // pass
}

public OnMapStart()
{
    iSpriteBeam = PrecacheModel("materials/sprites/laser.vmt");
    iSpriteRing = PrecacheModel("materials/sprites/halo01.vmt");

    GetCurrentMap(sCachedMap, sizeof(sCachedMap));
    CheckDisabled();

    /* Account for Late Load */
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            decl String:steamid[32];
            GetClientAuthString(i, steamid, sizeof(steamid));

            OnClientAuthorized(i, steamid);
            OnClientPutInServer(i);
        }
    }

    CreateTopMenus();
}

public OnClientPutInServer(client)
{
    bShowHud[client] = true;

    Tele_OnClientPutInServer(client);
    Commands_OnClientPutInServer(client);
}

public OnClientDisconnect(client)
{
    Commands_OnClientDisconnect(client);
}

public OnClientAuthorized(client, const String:steamid[])
{
    decl String:query[1024];
    decl String:name[MAX_NAME_LENGTH];
    decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

    GetClientName(client, name, sizeof(name));
    SQL_EscapeString(hDB, name, sNewName, sizeof(sNewName));

    Format(query, sizeof(query),
           "UPDATE playerdata SET name = '%s' WHERE steamid = '%s'",
           sNewName, steamid);

    SQL_TQuery(hDB, EmptyCallback, query);

    Format(query, sizeof(query),
           "SELECT besttime_300p, bestjumps_300p, besttime_300m, bestjumps_300m, besttime_sw_300p, bestjumps_sw_300p, besttime_sw_300m, bestjumps_sw_300m, besttime_w_300p, bestjumps_w_300p, besttime_w_300m, bestjumps_w_300m FROM playerdata WHERE map = '%s' AND steamid = '%s'",
           sCachedMap, steamid);

    SQL_TQuery(hDB, CacheBestTimeCallback, query, GetClientUserId(client));
    QueryClientConVar(client, "fps_max", GetFPSMax);
}

public OnRoundStart(Handle:event, const String:name[], bool:db)
{
    Remover_OnRoundStart();
}

public OnRoundEnd(Handle:event, const String:name[], bool:db)
{
    Remover_OnRoundEnd();
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    ResetPlayerStatus(client);
    bAlreadyStarted[client] = false;

    SetEntityGravity(client, 1.0);
    SetEntityHealth(client, 612);

    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, 255, 255, 255, iAlpha);

    Commands_OnPlayerSpawn(client);
}

public OnPlayerHurt(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    SetEntityHealth(client, 612);
}

public OnPlayerChangeTeam(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new bool:disconnect = GetEventBool(event, "disconnect");

    if (disconnect || !IsClientInGame(client))
        return;

    CreateTimer(0.1, SpawnPlayer, client);
    Commands_OnPlayerChangeTeam(client, GetEventInt(event, "team"));
}

public OnPlayerJump(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    iClientJumps[client]++;
    iAttemptedJumps[client] = 0;
}

public OnPlayerDeath(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    CreateTimer(0.1, SpawnPlayer, client);
}


/* ----- Commands ----- */


public Action:OnJoinTeam(client, const String:command[], argc)
{
    decl String:sTeam[2];
    GetCmdArg(1, sTeam, sizeof(sTeam));

    new team = StringToInt(sTeam);
    new target;

    if (team == TEAM_SPEC)
        return Plugin_Continue;

    if (GetTeamClientCount(TEAM_T))
        target = TEAM_T;

    else if (GetTeamClientCount(TEAM_CT))
        target = TEAM_CT;

    if (target && team != target)
    {
        decl String:joinTeamString[16];
        Format(joinTeamString, sizeof(joinTeamString), "jointeam %d", target);

        FakeClientCommand(client, joinTeamString);
        return Plugin_Handled;
    }

    iClientPad[client] = 0;
    return Plugin_Continue;
}


/* ----- Menus ----- */


public HelpMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    else if (action == MenuAction_Select)
    {
        decl String:display[255];
        decl String:text[240];

        GetMenuItem(menu, selected, text, sizeof(text));
        Format(display, sizeof(display), "%s%s", MSG_PREFIX, text);

        PrintToChat(client, display);
        DisplayMenu(hHelpMenu, client, DEFAULT_TIMEOUT);
    }
}

public MainMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action != MenuAction_Select)
        return;

    switch (selected + 1)
    {
        /* Global Stats */
        case 1:
            DisplayMenu(hTopMenu, client, DEFAULT_TIMEOUT);

        /* Location Manager */
        case 2:
        {
            WarnPlayer(client);
            DisplayMenu(hCPMenu, client, DEFAULT_TIMEOUT);
        }

        /* Commands */
        case 3:
            DisplayMenu(hHelpMenu, client, DEFAULT_TIMEOUT);

        /* Current Players */
        case 4:
            ShowPlayerMenu(client);
    }
}


/* ----- Timers ----- */

public Action:SpawnPlayer(Handle:timer, any:client)
{
    if (client > 0 && !IsClientInGame(client))
        return Plugin_Stop;

    else if (client < 1)
        return Plugin_Stop;

    if (!IsPlayerAlive(client) &&
        GetClientTeam(client) >= 2)
        CS_RespawnPlayer(client);

    return Plugin_Continue;
}

public Action:ShowPoints(Handle:timer, any:interval)
{
    decl Float:fTempTopLeft2[3];
    decl Float:fTempBottomRight2[3];

    if (fCachedStartWidth)
    {
        fTempTopLeft2[0] = fCachedStart[0] + fCachedStartLength;
        fTempTopLeft2[1] = fCachedStart[1] + fCachedStartWidth;
        fTempTopLeft2[2] = fCachedStart[2] + 10.0;

        fTempBottomRight2[0] = fCachedStart[0] - fCachedStartLength;
        fTempBottomRight2[1] = fCachedStart[1] - fCachedStartWidth;
        fTempBottomRight2[2] = fCachedStart[2] + 10.0;

        decl Float:BottomLeft[3];
        BottomLeft[0] = fTempBottomRight2[0];
        BottomLeft[1] = fTempTopLeft2[1];
        BottomLeft[2] = fTempTopLeft2[2];

        decl Float:TopRight[3];
        TopRight[0] = fTempTopLeft2[0];
        TopRight[1] = fTempBottomRight2[1];
        TopRight[2] = fTempBottomRight2[2];

        CreateStandardBeam(fTempTopLeft2, TopRight);
        CreateStandardBeam(fTempTopLeft2, BottomLeft);
        CreateStandardBeam(fTempBottomRight2, BottomLeft);
        CreateStandardBeam(fTempBottomRight2, TopRight);
    }

    if (fCachedEndWidth)
    {
        fTempTopLeft2[0] = fCachedEnd[0] + fCachedEndLength;
        fTempTopLeft2[1] = fCachedEnd[1] + fCachedEndWidth;
        fTempTopLeft2[2] = fCachedEnd[2] + 10.0;

        fTempBottomRight2[0] = fCachedEnd[0] - fCachedEndLength;
        fTempBottomRight2[1] = fCachedEnd[1] - fCachedEndWidth;
        fTempBottomRight2[2] = fCachedEnd[2] + 10.0;

        fTempTopLeft2[2] += 10.0;
        fTempBottomRight2[2] += 10.0;

        decl Float:BottomLeft[3];
        BottomLeft[0] = fTempBottomRight2[0];
        BottomLeft[1] = fTempTopLeft2[1];
        BottomLeft[2] = fTempTopLeft2[2];

        decl Float:TopRight[3];
        TopRight[0] = fTempTopLeft2[0];
        TopRight[1] = fTempBottomRight2[1];
        TopRight[2] = fTempBottomRight2[2];

        CreateStandardBeam(fTempTopLeft2, TopRight);
        CreateStandardBeam(fTempTopLeft2, BottomLeft);
        CreateStandardBeam(fTempBottomRight2, BottomLeft);
        CreateStandardBeam(fTempBottomRight2, TopRight);
    }
}

public Action:Timer_DisplayAdvert(Handle:timer, any:data)
{
    PrintToChatAll("%sType \x03!\x04timer\x01 for stats, commands, and more",
                   MSG_PREFIX);
    return Plugin_Continue;
}

public Action:Timer_CheckClientStatus(Handle:timer, any:data)
{
    if (bDisabledForMap)
        return Plugin_Continue;

    new Float:engine_time = GetEngineTime();

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        else if (GetClientTeam(i) < 2 || !IsPlayerAlive(i))
        {
            new observing = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
            new specMode  = GetEntProp(i, Prop_Send, "m_iObserverMode");

            if (observing > 0 &&
                (specMode == SPECMODE_FIRST_PERSON ||
                 specMode == SPECMODE_THIRD_PERSON))
                DisplayPlayerTime(observing, i, engine_time - fClientTimes[observing]);

            continue;
        }

        switch (iClientStartMode[i])
        {
            case STARTMODE_AT_START:
            {
                if (!IsInStart(i))
                {
                    ResetPlayerStatus(i, STARTMODE_IN_PROGRESS);

                    if (!bAlreadyStarted[i])
                    {
                        PrintToChatAll("%s%N has started the map", MSG_PREFIX, i);
                        bAlreadyStarted[i] = true;
                    }
                }
            }

            case STARTMODE_IN_PROGRESS:
            {
                new buttons = GetClientButtons(i);
                if (iRunMode[i] > PD_Regular && GetEntityMoveType(i) != MOVETYPE_LADDER)
                {
                    if (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
                        iRunMode[i] = PD_Regular;

                    else if (buttons & IN_BACK)
                        iRunMode[i] = PD_SW;
                }

                if (GetEntityMoveType(i) == MOVETYPE_NOCLIP)
                {
                    PrintToChat(i,
                                "%sYour timer has been \x04STOPPED\x01 for \x04noclip",
                                MSG_PREFIX);

                    ResetPlayerStatus(i);
                    continue;
                }

                if ((buttons & IN_LEFT) || (buttons & IN_RIGHT))
                {
                    PrintToChat(i,
                                "%sYour timer has been \x04STOPPED\x01 for \x04+left/+right",
                                MSG_PREFIX);
    
                    ResetPlayerStatus(i);
                    continue;
                }

                DisplayPlayerTime(i, i, engine_time - fClientTimes[i]);

                if (IsAtEnd(i))
                {
                    decl String:sMode[16];
                    decl String:displayMode[32];

                    switch (iRunMode[i])
                    {
                        case PD_Regular:
                        {
                            sMode[0] = '\0';
                            displayMode = "Mode: Regular";
                        }

                        case PD_SW:
                        {
                            sMode = "\x04 (Side Ways)\x01";
                            displayMode = "Mode: Side Ways";
                        }

                        case PD_W:
                        {
                            sMode = "\x04 (W-Only)\x01";
                            displayMode = "Mode: W Only";
                        }
                    }

                    new Float:round_time = engine_time - fClientTimes[i];
                    new Float:decimal = round_time - RoundToFloor(round_time);

                    PrintToChatAll("%s\x04%N\x01 has finished the map%s in \x04%02d:%05.2f\x01 and \x04%d\x01 jumps at \x04%d\x01 FPS",
                                   MSG_PREFIX, i, sMode,
                                   RoundToNearest(round_time) / 60,
                                   (RoundToFloor(round_time) % 60) + decimal,
                                   iClientJumps[i],
                                   iClientFPS[i]);

                    PrintToChat(i,
                                "%sAs soon as you return to spawn, your timer will reset",
                                MSG_PREFIX);

                    decl String:query[256];
                    decl String:steamid[32];

                    iClientStartMode[i] = STARTMODE_FINISHED;
                    GetClientAuthString(i, steamid, sizeof(steamid));

                    new FPS_Index = iClientFPS[i] >= 300 ? FPS_300P_INDEX : FPS_300M_INDEX;
                    new PlayerData:PD_Index = iRunMode[i];

                    decl String:fps[32];
                    decl String:jumps[32];
                    decl String:time[32];

                    Format(fps, sizeof(fps), "FPS: %d", iClientFPS[i]);
                    Format(jumps, sizeof(jumps), "Jumps: %d", iClientJumps[i]);
                    Format(time, sizeof(time), "Time: %02d:%05.2f", 
                           RoundToNearest(round_time) / 60,
                           (RoundToFloor(round_time) % 60) + decimal);

                    new Handle:panel = CreatePanel();
                    SetPanelTitle(panel, "You beat the map!");

                    DrawPanelItem(panel, "", ITEMDRAW_SPACER);

                    DrawPanelText(panel, displayMode);
                    DrawPanelText(panel, fps);
                    DrawPanelText(panel, jumps);
                    DrawPanelText(panel, time);

                    new old_jumps = iCachedBestJumps[i][PD_Index][FPS_Index];
                    new Float:old_time = fCachedBestTimes[i][PD_Index][FPS_Index];

                    if (!bInDB[i])
                        AddToDB(i);

                    if (iClientJumps[i] < old_jumps || old_jumps == 0)
                    {
                        decl String:oldadd[48];

                        Format(oldadd, sizeof(oldadd),
                               "Previous Best Jumps: %d", old_jumps);
                        DrawPanelText(panel, oldadd);

                        iCachedBestJumps[i][PD_Index][FPS_Index] = iClientJumps[i];

                        Format(query, sizeof(query),
                               "UPDATE playerdata SET %s = %d, %s = %f, %s = %d WHERE steamid = '%s' and map = '%s'",
                               sKeyNames[PD_Index][FPS_Index][RD_BestJumps],
                               iClientJumps[i],
                               sKeyNames[PD_Index][FPS_Index][RD_BestJumps_Time],
                               round_time,
                               sKeyNames[PD_Index][FPS_Index][RD_BestJumps_FPS],
                               iClientFPS[i], steamid, sCachedMap);

                        SQL_TQuery(hDB, EmptyCallback, query);
                        ConstructTopMenu(PD_Index, FPS_Index, MD_BestJumps);
                    }

                    if (round_time < old_time || old_time == 0.0)
                    {
                        decl String:oldadd[48];

                        Format(oldadd, sizeof(oldadd),
                               "Previous Best Time: %02d:%05.2f",
                               RoundToNearest(old_time) / 60,
                               (RoundToNearest(old_time) % 60) + (old_time - RoundToFloor(old_time)));
                        DrawPanelText(panel, oldadd);

                        fCachedBestTimes[i][PD_Index][FPS_Index] = round_time;

                        Format(query, sizeof(query),
                               "UPDATE playerdata SET %s = %f, %s = %d, %s = %d WHERE steamid = '%s' and map = '%s'",
                               sKeyNames[PD_Index][FPS_Index][RD_BestTime],
                               round_time,
                               sKeyNames[PD_Index][FPS_Index][RD_BestTime_Jumps],
                               iClientJumps[i],
                               sKeyNames[PD_Index][FPS_Index][RD_BestTime_FPS],
                               iClientFPS[i], steamid, sCachedMap);

                        SQL_TQuery(hDB, EmptyCallback, query);
                        ConstructTopMenu(PD_Index, FPS_Index, MD_BestTime);
                    }

                    DrawPanelItem(panel, "", ITEMDRAW_SPACER);

                    SetPanelCurrentKey(panel, 10);
                    DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);

                    SendPanelToClient(panel, i, EmptyMenuSelect, MENU_TIME_FOREVER);
                    CloseHandle(panel);
    
                    bAlreadyStarted[i] = false;
                }

                else if (IsInStart(i))
                    ResetPlayerStatus(i);
            }

            /* Once they're back at the spawn, we can restart their time */
            case STARTMODE_FINISHED:
            {
                if (IsInStart(i))
                {
                    if (!bAlreadyStarted[i])
                        PrintToChat(i,
                                    "%sAs soon as you leave the spawn point, your timer will start",
                                    MSG_PREFIX);

                    iClientStartMode[i] = STARTMODE_AT_START;
                    SetEntityGravity(i, 1.0);
                }
            }

            case STARTMODE_PAUSED:
            {
                // pass
            }
        }
    }

    return Plugin_Continue;
}


/* ----- Callbacks ----- */

public GetFPSMax(QueryCookie:cookie, client, ConVarQueryResult:result,
                 const String:cvarName[], const String:cvarValue[])
{
    iClientFPS[client] = StringToInt(cvarValue);
}

public EmptyCallback(Handle:db, Handle:hndl, const String:error[], any:data)
{
    LogError("Error in EmptyCallback: %s", error);
}


/* ----- Functions ----- */


stock DisplayButtons(targetClient, sendClient)
{
    new buttons = GetClientButtons(targetClient);
}

stock DisplayPlayerTime(targetClient, sendClient, Float:client_time)
{
    if (!bShowHud[sendClient])
        return;

    new Float:speed;

    decl Float:velocity[3];
    decl String:sSpeed[16];
    decl String:sWOnly[16];

    GetEntPropVector(targetClient, Prop_Data, "m_vecVelocity", velocity);
    speed = SquareRoot(Pow(velocity[0], 2.0) +
                       Pow(velocity[1], 2.0) +
                       Pow(velocity[2], 2.0));

    switch (iSpeedUnit)
    {
        /* Game units per second */
        case 0:
            Format(sSpeed, sizeof(sSpeed), "%.2f units/s", speed);

        /* Kilometers per hour */
        case 1:
        {
            speed *= 0.06858;
            Format(sSpeed, sizeof(sSpeed), "%.2f km/h", speed);
        }
    }

    switch (iRunMode[targetClient])
    {
        case PD_Regular:
            sWOnly[0] = '\0';

        case PD_SW:
            sWOnly = " (Side Ways)";

        case PD_W:
            sWOnly = " (W-Only)";
    }

    decl String:fps[24] = "";

    if (targetClient != sendClient)
        Format(fps, sizeof(fps), "\nfps_max: %d", iClientFPS[targetClient]);

    PrintHintText(sendClient,
                  "Time%s: %02d:%05.2f\nJumps: %d\nspeed: %s%s",
                  sWOnly,
                  RoundToNearest(client_time) / 60,
                  (RoundToFloor(client_time) % 60) + (client_time - RoundToFloor(client_time)),
                  iClientJumps[targetClient],
                  sSpeed, fps);
}

stock CheckDisabled()
{
    KvRewind(hSpawnPoints);

    /* Fast caching of wether or not the map has spawn points */
    if(KvJumpToKey(hSpawnPoints, sCachedMap))
    {
        bDisabledForMap = false;
    
        KvGetVector(hSpawnPoints, "start", fCachedStart, NULL_VECTOR);
        fCachedStartWidth = KvGetFloat(hSpawnPoints, "start width", 0.0);
        fCachedStartLength = KvGetFloat(hSpawnPoints, "start length", 0.0);

        KvGetVector(hSpawnPoints, "end", fCachedEnd, NULL_VECTOR);
        fCachedEndWidth = KvGetFloat(hSpawnPoints, "end width", 0.0);
        fCachedEndLength = KvGetFloat(hSpawnPoints, "end length", 0.0);

        /* Either a start location, or end location is missing */
        if (fCachedStartWidth == 0.0 || fCachedEndWidth == 0.0)
            bDisabledForMap = true;
    }

    else
    {
        bDisabledForMap = true;
        fCachedStartWidth = 0.0;
        fCachedEndWidth = 0.0;
    }
}

stock ResetPlayerStatus(client, startmode=STARTMODE_FINISHED)
{
    iClientStartMode[client] = startmode;
    iClientJumps[client] = 0;
    fClientTimes[client] = GetEngineTime();
    iRunMode[client] = PD_W;
}

stock CreateOneTimeMenus()
{
    hMainMenu = CreateMenu(MainMenuSelect);
    SetMenuTitle(hMainMenu, "Timer Main Menu");

    AddMenuItem(hMainMenu, "", "Global Stats");
    AddMenuItem(hMainMenu, "", "Location Manager");
    AddMenuItem(hMainMenu, "", "Commands");
    AddMenuItem(hMainMenu, "", "Current Players");

    AddMenuItem(hMainMenu, "", "More", ITEMDRAW_DISABLED);
    AddMenuItem(hMainMenu, "", "To", ITEMDRAW_DISABLED);
    AddMenuItem(hMainMenu, "", "Come?", ITEMDRAW_DISABLED);

    hHelpMenu = CreateMenu(HelpMenuSelect);
    SetMenuTitle(hHelpMenu, "Timer Commands");
    SetMenuExitBackButton(hHelpMenu, true);

    AddMenuItem(hHelpMenu, "Shows a usefull bhopping tutorial", "/help");
    AddMenuItem(hHelpMenu, "Restarts your timer, and sends you back to spawn", "/restart");
    AddMenuItem(hHelpMenu, "Displays the main timer menu", "!timer");
    AddMenuItem(hHelpMenu, "Shows the top menu for the current map", "/top");
    AddMenuItem(hHelpMenu, "Shows the Regular Stats for the current map", "/wr");
    AddMenuItem(hHelpMenu, "Shows the Side Ways stats for the current map", "/wrsw");
    AddMenuItem(hHelpMenu, "Shows the W Only stats for the current map", "/wrw");
    AddMenuItem(hHelpMenu, "Shows the Coordinate Manager menu", "!cp");
    AddMenuItem(hHelpMenu, "Teleports you to your current saved location \x04RESETS TIMER", "/teleport, /tele, /t");
    AddMenuItem(hHelpMenu, "Saves your current teleport location", "/save, /s");
    AddMenuItem(hHelpMenu, "Sets your current teleport location to your next saved one", "/next, /n");
    AddMenuItem(hHelpMenu, "Sets your current teleport location to your previous saved one", "/previous, /prev, /p");
    AddMenuItem(hHelpMenu, "Deletes your current point", "/delete, /del, /d");
    AddMenuItem(hHelpMenu, "Gives you a scout", "/scout");
    AddMenuItem(hHelpMenu, "Gives you low gravity \x04RESETS TIMER", "/lowgrav");
    AddMenuItem(hHelpMenu, "Resets your gravity", "/normalgrav");
    AddMenuItem(hHelpMenu, "Observes a player, and shows what keys they're pressing", "/spec or /pad or /showkeys <player name/#userid>");
    AddMenuItem(hHelpMenu, "Shows your own keys", "/padme, /showmykeys");
    AddMenuItem(hHelpMenu, "Makes everyone else invisible", "/hide");
    AddMenuItem(hHelpMenu, "Shows current players run data", "/players");
    AddMenuItem(hHelpMenu, "Toggles your hud display", "/toggle, /togglehud, /toggletimer");
    AddMenuItem(hHelpMenu, "Freezes you and your timer -- go ahead, get a snack", "/pause");
    AddMenuItem(hHelpMenu, "Un pauses you", "/resume");
    AddMenuItem(hHelpMenu, "Shows this menu", "/commands");

    Admin_CreateMenus();
    Stats_CreateMenus();
    Tele_CreateMenus();
    Commands_CreateMenus();
}

stock ConnectToDB()
{
    hDB = SQLite_UseDatabase("timer", sError, sizeof(sError));
    if (hDB == INVALID_HANDLE)
    {
        SetFailState(sError);
        return;
    }

    decl String:query[2048] = "CREATE TABLE IF NOT EXISTS playerdata (map TEXT, steamid TEXT, name TEXT";

    for (new i = 0; i < _:PlayerData; i++)
    {
        for (new j = 0; j < 2; j++)
        {
            StrCat(query, sizeof(query), ", ");

            StrCat(query, sizeof(query), sKeyNames[i][j][RD_BestTime]);
            StrCat(query, sizeof(query), " REAL, ");

            for (new k = 1; k < 5; k++)
            {
                StrCat(query, sizeof(query), sKeyNames[i][j][k]);
                StrCat(query, sizeof(query), " INTEGER, ");
            }

            StrCat(query, sizeof(query), sKeyNames[i][j][RD_BestJumps_Time]);
            StrCat(query, sizeof(query), " REAL");
        }
    }

    StrCat(query, sizeof(query), ")");
    SQL_TQuery(hDB, EmptyCallback, query);
}

stock CreateStandardBeam(Float:start[3], Float:end[3])
{
    TE_SetupBeamPoints(start, end,
                       iSpriteBeam, iSpriteRing,
                       1, 1, 20.0, 5.0, 5.0, 0, 10.0, iColorBlue, 256);
    TE_SendToAll();
}


/* ----- Return Values ----- */


bool:InBox(Float:testOrigin[3], Float:origin[3],
           Float:halfWidth, Float:halfLength)
{
    if (FloatAbs(testOrigin[0] - origin[0]) <= halfLength &&
        FloatAbs(testOrigin[1] - origin[1]) <= halfWidth &&
        FloatAbs(testOrigin[2] - origin[2]) <= POINT_HEIGHT)
        return true;
    return false;
}

bool:IsAtEnd(client)
{
    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    return InBox(origin, fCachedEnd, fCachedEndWidth, fCachedEndLength);
}

bool:IsInStart(client)
{
    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    return InBox(origin, fCachedStart, fCachedStartWidth, fCachedStartLength);
}
