// ./cstrike/addons/sourcemod/scripting/gangs.sp

/**
 * To Do:
 *      Maybe/When Time:
 *          Code's getting a bit messy...
 *          Allow leaders to change their name... for a price
 *
 *  Add Admin command to boot from gang
 *  Confirm/investigate later: If you change your perk, it says you can't for another yadda yadda hours even though you should be able to.
 *  Remove all that debug shit
 *
 *  Only give people gang perks if they're alive (lolwut)
 *
 *  Change the perks you get on round start to have that data cached.
 */

/**
 * Gang Reputation Mod For Hells Gamers
 * 
 * Author: Bonbon
 *
 * This is based off the original gang system made by Cr(+)sshair
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS

#include <cstrike>
#include <tf2>
#include <throwingknives>
#include <hg_jbaio>
#include <hg_premium>

#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION "2.0.0"

#define MAX_DRUGS 100
#define MAX_DRUGS_INITIAL 50

#define MENU_NOT_CREATED 0
#define MENU_BEING_CREATED 1
#define MENU_CREATED 2

#define TEAM_SPEC 1
#define TEAM_T 2
#define TEAM_CT 3

#define MEMBERTYPE_NONE 0
#define MEMBERTYPE_MEMBER 1
#define MEMBERTYPE_COOWNER 2
#define MEMBERTYPE_OWNER 3

#define GAMETYPE_CSS 0
#define GAMETYPE_CSGO 1
#define GAMETYPE_TF2 2

#define CLUSTER_DISTANCE 100
#define DEFAULT_TIMEOUT 60
#define MSG_PREFIX "\x01[\x03Gangs\x01]: "

#pragma semicolon 1

enum _:PlayerData
{
    PD_Points = 0,
    PD_TotalSpent,
    PD_TotalDrugs,
    PD_Contributed
};

enum _:GangData
{
    GD_Rep = 0,
    GD_TotalSpent,
};

new bool:bIsLR;
new bool:bIsThursday;
new bool:bPerkEnabled[MAXPLAYERS + 1];

new Float:fAbsorbMultiplier[MAXPLAYERS + 1];
new Float:fGiveMultiplier[MAXPLAYERS + 1];

new Float:fElectricChair[3] = {-133.0, -3220.0, 0.0};

new g_iGame;
new iMicrowavesThisRound;
new iRoundStartTime;
new totalSQLKeys;
new levels;                 /* Stores the number of levels */
new upgradeCosts[MAXPLAYERS + 1];
new memberType[MAXPLAYERS + 1];

/* Offsets */
new m_iAccount = -1;
new m_clrRender = -1;
new m_iAmmo = -1;
new m_iClip1 = -1;

new String:sError[PLATFORM_MAX_PATH];
new String:sGangNames[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new String:sCacheGang[MAXPLAYERS + 1][MAX_NAME_LENGTH];

/* ConVar Handles */
new Handle:hMinSpawn = INVALID_HANDLE;
new Handle:hMaxSpawn = INVALID_HANDLE;
new Handle:hBuyTime = INVALID_HANDLE;
new Handle:hTDropPercent = INVALID_HANDLE;
new Handle:hCTDropPercent = INVALID_HANDLE;
new Handle:hCig = INVALID_HANDLE;
new Handle:hBooze = INVALID_HANDLE;
new Handle:hWeed = INVALID_HANDLE;
new Handle:hCoke = INVALID_HANDLE;
new Handle:hHeroin = INVALID_HANDLE;
new Handle:hCostPerLevel = INVALID_HANDLE;
new Handle:hOnBreakPercent = INVALID_HANDLE;
new Handle:hChangePerkEvery = INVALID_HANDLE;
new Handle:hGangPruneOnethreshold = INVALID_HANDLE;
new Handle:hGangPruneOneDays = INVALID_HANDLE;
new Handle:hGangPruneTwothreshold = INVALID_HANDLE;
new Handle:hGangPruneTwoDays = INVALID_HANDLE;
new Handle:hGangPruneThreethreshold = INVALID_HANDLE;
new Handle:hGangPruneThreeDays = INVALID_HANDLE;
new Handle:hMinRatio = INVALID_HANDLE;
new Handle:hRepAtLR = INVALID_HANDLE;
new Handle:hCostPerContributed = INVALID_HANDLE;
new Handle:hMinBootCost = INVALID_HANDLE;
new Handle:hUpdateEvery = INVALID_HANDLE;
new Handle:hMinLevelForTrails = INVALID_HANDLE;
new Handle:hMinMembersForTrails = INVALID_HANDLE;
new Handle:hTrailDrainRep = INVALID_HANDLE;
new Handle:hTrailDrainGangPoints = INVALID_HANDLE;


/* Menu Handles */
new Handle:hPassLeaderMenus[MAXPLAYERS + 1];

new Handle:hGlobalStatsMenu = INVALID_HANDLE;
new Handle:hMainMenu = INVALID_HANDLE;
new Handle:hJoinGangByNameMenu = INVALID_HANDLE;
new Handle:hJoinGangByOwnerMenu = INVALID_HANDLE;
new Handle:hIdentifyPlayersMenu = INVALID_HANDLE;
new Handle:hJoinGangMenu = INVALID_HANDLE;
new Handle:hConfirmLeaveGangMenu = INVALID_HANDLE;
new Handle:hGangOptionsMenu = INVALID_HANDLE;
new Handle:hGangCoOwnerMenu = INVALID_HANDLE;
new Handle:hGangPerksMenu = INVALID_HANDLE;
new Handle:hGangInfo = INVALID_HANDLE;
new Handle:hGangByNameInfo = INVALID_HANDLE;
new Handle:hGangByOwnerInfo = INVALID_HANDLE;
new Handle:hCommandMenu = INVALID_HANDLE;
new Handle:hCurrentPlayersMenu = INVALID_HANDLE;
new Handle:hManageCoOwnerMenu = INVALID_HANDLE;
new Handle:hTrailRequestCost = INVALID_HANDLE;

/* Misc Handles */
new Handle:hDrugDB = INVALID_HANDLE;
new Handle:hLevelCosts = INVALID_HANDLE;
new Handle:hPerksEnabled = INVALID_HANDLE;

new Handle:hPlayerData = INVALID_HANDLE;
new Handle:hPlayerUpdate = INVALID_HANDLE;
new Handle:hUpdateArray = INVALID_HANDLE;

new Handle:hRepData = INVALID_HANDLE;
new Handle:hRepUpdate = INVALID_HANDLE;
new Handle:hRepArray = INVALID_HANDLE;

#include "gangs/admin.sp"
#include "gangs/buymenu.sp"
#include "gangs/drugs.sp"
#include "gangs/ganginfo.sp"
#include "gangs/gangleader.sp"
#include "gangs/gangmembers.sp"
#include "gangs/points.sp"
#include "gangs/servercommands.sp"
#include "gangs/stats.sp"
#include "gangs/trails.sp"

/* ----- Plugin Info ----- */


public Plugin:myinfo =
{
    name = "Gangs for Hells Gamers",
    author = "Bonbon",
    description = "Implements gangs into Jail Break",
    version = PLUGIN_VERSION,
    url = "http://hellsgamers.com/"
}


/* ----- Sourcemod Forwards ----- */


public OnPluginStart()
{
    CreateConVar("gangs_version", PLUGIN_VERSION, "Version of gangs for HellsGamers running on this server", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    hMinSpawn = CreateConVar("gang_min_spawn", "5",
                             "Minimum number of drugs to spawn", _, true, 1.0,
                             true, 30.0);

    hMaxSpawn = CreateConVar("gang_max_spawn", "20",
                             "Maximum number of drugs to spawn", _, true, 1.0,
                             true, 30.0);

    hBuyTime = CreateConVar("gang_buy_time", "60",
                            "Amount of time (in seconds) that a user can buy perks at the start of a round");

    hTDropPercent = CreateConVar("gang_tdrop_percent", "0.02",
                                 "Chance that a T will drop drugs when they die",
                                 _, true, 0.0, true, 1.0);

    hCTDropPercent = CreateConVar("gang_ctdrop_percent", "0.2",
                                 "Chance that a CT will drop drugs when they die",
                                 _, true, 0.0, true, 1.0);

    hCig = CreateConVar("gang_cig_points", "3",
                        "Points that picking up cigarrettes gives you");

    hBooze = CreateConVar("gang_booze_points", "4",
                          "Points that picking up alcohol gives you");

    hWeed = CreateConVar("gang_weed_points", "5",
                         "Points that picking up weed gives you");

    hCoke = CreateConVar("gang_coke_points", "6",
                         "Points that picking up cocain gives you");

    hHeroin = CreateConVar("gang_heroin_points", "7",
                           "Points that picking up heroin gives you");

    hCostPerLevel = CreateConVar("gang_cost_per_level", "20",
                                 "Points required per level to join a gang");

    hOnBreakPercent = CreateConVar("gang_on_break_percent", "0.05",
                                   "Percent chance that breaking a prop will spawn drugs");

    hChangePerkEvery = CreateConVar("gang_change_perk_every", "24",
                                    "Allow the leader to change their perk every x hours");

    hGangPruneOnethreshold = CreateConVar("gang_prune_one_threshold", "50",
                                          "Point threshold for the first pruning (non gang members)");

    hGangPruneOneDays = CreateConVar("gang_prune_one_days", "14",
                                     "Days inactive before pruning players for first pruning");

    hGangPruneTwothreshold = CreateConVar("gang_prune_two_threshold", "400",
                                          "Point threshold for the second pruning (gang members, non leaders)");

    hGangPruneTwoDays = CreateConVar("gang_prune_two_days", "30",
                                     "Days inactive before pruning players for second pruning (gang members, non leaders)");

    hGangPruneThreethreshold = CreateConVar("gang_prune_three_threshold", "10000",
                                            "Point threshold for the third pruning (everyone, leadership will be passed)");

    hGangPruneThreeDays = CreateConVar("gang_prune_three_days", "60",
                                       "Days inactive before pruning players for third pruning");

    hMinRatio = CreateConVar("gang_ct_t_ratio", "0.33",
                             "If the ratio of CTs to Ts falls below this, drugs won't spawn");

    hRepAtLR = CreateConVar("gang_rep_at_lr", "10",
                            "Amount of rep a players gang will get when LR is reached (CTs and Ts recieve this)");
    
    hCostPerContributed = CreateConVar("gang_boot_cost_per_contributed", "0.5",
                                       "Amount of gang points it costs to kick someone out of a gang for every 1 point they contributed");

    hMinBootCost = CreateConVar("gang_min_boot", "50",
                                "Flat rate cost (added onto cost per contributed) to kick someone out of a gang");

    hUpdateEvery = CreateConVar("gang_update_every", "300",
                                "Every <x> seconds to update the points DB");


    hMinLevelForTrails = CreateConVar("gang_min_level_for_trails", "21",
                                      "Minimum level of a gang to be eligible for a trail");

    // Make it the same as sv_visiblemaxplayers (CS:S 64, CS:GO 46, TF2 32)
    hMinMembersForTrails = CreateConVar("gang_min_members_for_trails", "64",
                                        "Minimum member count of a gang to be eligible for a trail");

    hTrailDrainRep = CreateConVar("gang_trail_drain_rep", "2",
                                  "How many player rep (per round) trails drain");

    hTrailDrainGangPoints = CreateConVar("gang_trail_drain_gangpoints", "1",
                                         "How many gang points (per round per player) trails drain");

    hTrailRequestCost = CreateConVar("gang_trail_request_cost", "25000",
                                     "Cost (in gang points) to request a trail");

    AutoExecConfig(true, "gangs");

    if (g_iGame == GAMETYPE_TF2)
    {
        HookEvent("teamplay_round_start", OnRoundStart);
        HookEvent("teamplay_round_win", OnRoundEnd);
    }

    else
    {
        HookEvent("round_start", OnRoundStart);
        HookEvent("round_end", OnRoundEnd);
    }

    HookEvent("player_death", OnPlayerDeath);
    HookEvent("player_changename", OnPlayerChangeName);
    HookEvent("player_spawn", OnPlayerSpawn);

    RegConsoleCmd("sm_menu", Command_MainMenu);

    ConnectToDB();

    hLevelCosts = CreateDataPack();
    ServerCommand("exec sourcemod/gangcosts.cfg");

    m_iAccount = FindSendPropOffs("CCSPlayer", "m_iAccount");
    m_clrRender = FindSendPropOffs("CAI_BaseNPC", "m_clrRender");
    m_iAmmo = FindSendPropInfo("CCSPlayer", "m_iAmmo");
    m_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");

    for (new i = 0; i < MAXPLAYERS + 1; i++)
        sCacheGang[i] = "None";

    ConstructMenus();

    Admin_OnPluginStart();
    BuyMenu_OnPluginStart();
    Drugs_OnPluginStart();
    Points_OnPluginStart();
    GangLeader_OnPluginStart();
    GangMembers_OnPluginStart();
    GangInfo_OnPluginStart();
    ServerCommands_OnPluginStart();
    Stats_OnPluginStart();
    Trails_OnPluginStart();

    /* For FindTarget */
    LoadTranslations("common.phrases");

    /* Account for Late Load */
    new bool:construct;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            decl String:steamid[32];
            GetClientAuthString2(i, steamid, sizeof(steamid));

            OnClientPutInServer(i);
            OnClientAuthorized(i, steamid);
    
            construct = true;
        }
    }

    if (construct)
        OnRoundStart(INVALID_HANDLE, "", false);

    hPerksEnabled = RegClientCookie("hg_gangs_perks_enabled",
                                    "Are players perks enabled",
                                    CookieAccess_Public);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    decl String:game[PLATFORM_MAX_PATH];
    GetGameFolderName(game, sizeof(game));

    if (StrEqual(game, "cstrike"))
        g_iGame = GAMETYPE_CSS;

    else if (StrEqual(game, "csgo"))
        g_iGame = GAMETYPE_CSGO;

    else
        g_iGame = GAMETYPE_TF2;

    return APLRes_Success;
}

public OnConfigsExecuted()
{
    PruneDatabase();
    Trails_OnConfigsExecuted();
}

public OnMapStart()
{
    CreateTimer(1.0, ServerCommands_OnMapStart);
    Drugs_OnMapStart();
    Points_OnMapStart();

    PrecacheModel("models/props/cs_office/microwave.mdl");
    PrecacheModel("models/props/de_tides/Vending_turtle.mdl");
}

/* Update their last connect time IFF they exist */
public OnClientAuthorized(client, const String:auth[])
{
    // CS:GO Compatibility
    decl String:steamid[32];
    Format(steamid, sizeof(steamid), auth);
    ReplaceString(steamid, sizeof(steamid), "STEAM_1", "STEAM_0");

    Points_OnClientAuthorized(client, steamid);

    bPerkEnabled[client] = true;
    memberType[client] = MEMBERTYPE_NONE;

    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT gang, steamid, isowner, joined FROM playerdata WHERE steamid = '%s'", steamid);

    SQL_TQuery(hDrugDB, UpdateGangCache, query, GetClientUserId(client));
    CheckNewName(client);

    Timer_OnClientFullyAuthorized(INVALID_HANDLE, GetClientUserId(client));
    CreateTimer(1.0, Timer_CheckCookies, GetClientUserId(client));
}

public Action:Timer_CheckCookies(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);

    if (client > 0)
    {
        if (!AreClientCookiesCached(client))
        {
            CreateTimer(5.0, Timer_CheckCookies, GetClientUserId(client));
        }

        else
        {
            new String:enabled[2];
            GetClientCookie(client, hPerksEnabled, enabled, sizeof(enabled));

            bPerkEnabled[client] = StrEqual(enabled, "1") || StrEqual(enabled, "");
        }
    }

    return Plugin_Stop;
}

public Action:Timer_OnClientFullyAuthorized(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client < 1)
        return Plugin_Handled;

    if (!AreClientCookiesCached(client))
    {
        CreateTimer(1.0, Timer_OnClientFullyAuthorized, GetClientUserId(client));
        return Plugin_Handled;
    }

    // Their cookies are available for reading
    Trails_OnClientFullyAuthorized(client);
    return Plugin_Handled;
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

    Trails_OnClientPutInServer(client);
}

public OnClientDisconnect(client)
{
    Points_OnClientDisconnect(client);
    sCacheGang[client] = "None";

    if (hPassLeaderMenus[client] != INVALID_HANDLE)
    {
        CloseHandle(hPassLeaderMenus[client]);
        hPassLeaderMenus[client] = INVALID_HANDLE;
    }

    CheckLastRequest();
}


/* ----- Events ----- */


public OnPlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
    CheckNewName(GetClientOfUserId(GetEventInt(event, "userid")));
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    fAbsorbMultiplier[client] = 0.0;
    fGiveMultiplier[client] = 0.0;

    decl Float:fLoc[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", fLoc);

    new Float:dropPercent = GetConVarFloat(GetClientTeam(client) == 2 ? 
                                           hTDropPercent : hCTDropPercent);

    if (GetRandomFloat() <= dropPercent)
        SpawnDrugs(fLoc[0], fLoc[1], fLoc[2] + 15);

    CheckLastRequest();

    ServerCommands_OnPlayerDeath(client);
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    Drugs_OnRoundStart();
    Stats_OnRoundStart();
    GangLeader_OnRoundStart();
    GangMembers_OnRoundStart();
    BuyMenu_OnRoundStart();
    Admin_OnRoundStart();

    iRoundStartTime = GetTime();
    ConstructRoundStartMenus();

    bIsLR = false;
    bIsThursday = IsThursday();
    SetLightStyle(0, "m");

    iMicrowavesThisRound = 0;
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!bIsThursday)
    {
        GangMembers_OnPlayerSpawn(client);
        ServerCommands_OnPlayerSpawn(client);
    }

    fAbsorbMultiplier[client] = 0.0;
    fGiveMultiplier[client] = 0.0;

    Trails_OnPlayerSpawn(client);
}

public Action:OnTakeDamage(victim,
                          &attacker, &inflictor, &Float:damage, &damagetype)
{
    if (victim > 0 && victim <= MaxClients && fAbsorbMultiplier[victim])
    {
        damage *= fAbsorbMultiplier[victim];
        return Plugin_Changed;
    }

    else if (attacker <= 0 ||
             attacker > MaxClients ||
             GetClientTeam(attacker) == GetClientTeam(victim))
        return Plugin_Continue;

    else if (fGiveMultiplier[attacker])
    {
        damage *= fGiveMultiplier[attacker];
        return Plugin_Changed;
    }

    return ServerCommands_OnTakeDamage(victim, attacker, damage);
}

public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    Drugs_OnRoundEnd();

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            SetEntityGravity(i, 1.0);
    }
}


/* ----- Commands ----- */


public Action:Command_MainMenu(client, args)
{
    if (bIsThursday)
    {
        PrintToChat(client, "%s Sorry, this feature is disabled due to \x04Throwback Thursday", MSG_PREFIX);
        return Plugin_Handled;
    }

    DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);
    return Plugin_Handled;
}

public Action:OnSayTeam(client, const String:text[], maxlength)
{
    for (new i = 0; i < 4; i++)
    {
        if (text[i] != '!')
            return Plugin_Continue;
    }

    if (bIsThursday)
    {
        PrintToChat(client, "%s Sorry, this feature is disabled due to \x04Throwback Thursday", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (LibraryExists("hg_jbaio") &&
        JB_IsClientGagged(client))
    {
        PrintToChat(client, "%s You may not use gang chat while gagged", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:gang[MAX_NAME_LENGTH];
    strcopy(gang, sizeof(gang), sCacheGang[client]);

    if (StrEqual(gang, "None"))
    {
        PrintToChat(client, "%s You are trying to use gang chat, but you are not in a gang!", MSG_PREFIX);
        PrintToChat(client, "%s Type \x03!menu\x01 to view the gang menu", MSG_PREFIX);
        return Plugin_Stop;
    }

    decl String:said[188];
    decl String:message[192];
    decl String:name[MAX_NAME_LENGTH];

    GetClientName(client, name, sizeof(name));
    strcopy(said, sizeof(said), text[4]);

    said[sizeof(said) - 1] = '\0';
    Format(message, sizeof(message),
            "\x04(\x03%s\x04) %s:\x01%s", gang, name, said);

    if (StrContains(said, "\x07") != -1 || StrContains(said, "\x08") != -1)
    {
        PrintToChat(client, "Don't be a faggot, faggot.");
        return Plugin_Stop;
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (StrEqual(sCacheGang[i], gang) ||
            GetUserFlagBits(i) & ADMFLAG_KICK ||
            GetUserFlagBits(i) & ADMFLAG_ROOT)
            PrintToChat(i, message);
    }

    decl String:path[PLATFORM_MAX_PATH];

    BuildPath(Path_SM, path, sizeof(path), "scripting/gangchat.log");
    LogToFile(path, "%L gangchat - %s", client, said);

    BuildPath(Path_SM, path, sizeof(path), "logs/gangchat.log");
    LogToFile(path, "%L gangchat - %s", client, said);

    return Plugin_Stop;
}


/* ----- Menus ----- */


stock ConstructMenus()
{
    /* Main, !menu, Menu */
    hMainMenu = CreateMenu(mainMenuSelect);
    SetMenuTitle(hMainMenu, "Gangs Main Menu");

    AddMenuItem(hMainMenu, "", "Your Stats");
    AddMenuItem(hMainMenu, "", "Global Stats");
    AddMenuItem(hMainMenu, "", "Join/Leave Gang");
    AddMenuItem(hMainMenu, "", "Gang Options");
    AddMenuItem(hMainMenu, "", "Commands");
    AddMenuItem(hMainMenu, "", "Gang Info");

    /* Are You Sure Menus */
    hConfirmLeaveGangMenu = CreateMenu(ConfirmLeaveGangMenuSelect);
    SetMenuTitle(hConfirmLeaveGangMenu, "Are You Sure? Can't Be Undone");

    AddMenuItem(hConfirmLeaveGangMenu, "", "No");
    AddMenuItem(hConfirmLeaveGangMenu, "", "Yes");

    SetMenuExitBackButton(hConfirmLeaveGangMenu, true);

    /* Command Menu */
    hCommandMenu = CreateMenu(commandMenuSelect);
    SetMenuTitle(hCommandMenu, "Gang Commands");

    AddMenuItem(hCommandMenu, "Shows the main menu", "/menu");
    AddMenuItem(hCommandMenu, "Shows the buy menu", "/buy");
    AddMenuItem(hCommandMenu, "Shows the top menu", "/top");
    AddMenuItem(hCommandMenu, "Tells your current points", "/points");
    AddMenuItem(hCommandMenu, "Tells your gangs rep", "/gangpoints");
    AddMenuItem(hCommandMenu, "Shows an info menu of all players", "/players");
    AddMenuItem(hCommandMenu, "Removes you from the CT Queue", "/leavequeue");

    AddMenuItem(hCommandMenu,
                "Adds you to the CT queue, or shows your position in it",
                "/queue");

    AddMenuItem(hCommandMenu,
                "Donates points to your gang's rep", "/donate <amount>/'all'");

    AddMenuItem(hCommandMenu,
                "Shows all online players in gangs", "/identify");

    AddMenuItem(hCommandMenu,
                "Creates a new gang with specified name", "/create <gangname>");

    AddMenuItem(hCommandMenu,
                "Donate points to another player", "/giveplayer");

    AddMenuItem(hCommandMenu,
                "Sends a message to all online players in your gang",
                "teamchat - '!!!! <message>'");

    SetMenuExitBackButton(hCommandMenu, true);

    CreateGangInfoMenus();
    ConstructGangMenus();
}

stock ConstructRoundStartMenus()
{
    decl String:steamid[32];

    if (hIdentifyPlayersMenu != INVALID_HANDLE)
        CloseHandle(hIdentifyPlayersMenu);

    if (hCurrentPlayersMenu != INVALID_HANDLE)
        CloseHandle(hCurrentPlayersMenu);

    hIdentifyPlayersMenu = CreateMenu(tellPlayerRankSelect);
    SetMenuTitle(hIdentifyPlayersMenu, "Active Players: Name - Gang");

    hCurrentPlayersMenu = CreateMenu(currentPlayersMenuSelect);
    SetMenuTitle(hCurrentPlayersMenu, "Current Players");

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        GetClientAuthString2(i, steamid, sizeof(steamid));

        decl String:sUserid[8];
        IntToString(GetClientUserIdSafe(i), sUserid, sizeof(sUserid));

        decl String:name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));


        if (!StrEqual(sCacheGang[i], "None"))
        {
            decl String:display[64];
            Format(display, sizeof(display), "%s - %s", name, sCacheGang[i]);

            AddMenuItem(hIdentifyPlayersMenu, steamid, display);
        }

        AddMenuItem(hCurrentPlayersMenu, sUserid, name);

        if (StrEqual(sCacheGang[i], "None"))
            AddMenuItem(hInvitePlayerMenu, sUserid, name);
    }
}

public EmptyMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    // pass
}

public currentPlayersMenuSelect(Handle:menu,
                                MenuAction:action, client, selected)
{
    if (action != MenuAction_Select)
        return;

    decl String:userid[8];
    GetMenuItem(menu, selected, userid, sizeof(userid));

    new tClient = GetClientOfUserId(StringToInt(userid));
    decl String:steamid[32];

    if (!tClient)
    {
        PrintToChat(client,
                    "%s That player has left the server", MSG_PREFIX);
        return;
    }

    GetClientAuthString2(tClient, steamid, sizeof(steamid));
    TellPlayerStats(client, steamid);
}

public commandMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    else if (action == MenuAction_Select)
    {
        decl String:message[128];
        decl String:sFormattedMessage[150];

        GetMenuItem(menu, selected, message, sizeof(message));
        Format(sFormattedMessage,
               sizeof(sFormattedMessage), "%s %s", MSG_PREFIX, message);

        PrintToChat(client, sFormattedMessage);
        DisplayMenu(menu, client, DEFAULT_TIMEOUT);
    }
}

public tellPlayerRankSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:steamid[MAX_NAME_LENGTH];
        GetMenuItem(menu, selected, steamid, sizeof(steamid));

        TellPlayerStats(client, steamid);
    }
}

public emptyMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    /* Pass */
}

public mainMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action != MenuAction_Select)
        return;

    switch (selected + 1)
    {
        /* Your Stats */
        case 1:
        {
            decl String:steamid[32];
            GetClientAuthString2(client, steamid, sizeof(steamid));

            TellPlayerStats(client, steamid);
        }

        /* Global Stats */
        case 2:
            DisplayMenu(hGlobalStatsMenu, client, DEFAULT_TIMEOUT);

        /* Join/Leave Gang */
        case 3:
            DisplayMenu(hJoinGangMenu, client, DEFAULT_TIMEOUT);

        /* Gang Options */
        case 4:
        {
            switch (memberType[client])
            {
                case MEMBERTYPE_NONE:
                    PrintToChat(client, "%s You are not in a gang...", MSG_PREFIX);

                case MEMBERTYPE_MEMBER:
                    DisplayMenu(hGangMemberOptionsMenu, client, DEFAULT_TIMEOUT);

                case MEMBERTYPE_COOWNER:
                    DisplayMenu(hGangCoOwnerMenu, client, DEFAULT_TIMEOUT);

                case MEMBERTYPE_OWNER:
                    DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);
            }
        }

        /* Donate To Gang */
        case 5:
            DisplayMenu(hCommandMenu, client, DEFAULT_TIMEOUT);

        /* Gang Info */
        case 6:
            DisplayMenu(hGangInfo, client, DEFAULT_TIMEOUT);
    }
}


/* ----- SQL Callbacks ----- */


public pruneThreeCallback(Handle:hGang,
                          Handle:hndl, const String:error[], any:data)
{
    new threshold = GetConVarInt(hGangPruneThreethreshold);
    decl String:query[256];

    while (SQL_FetchRow(hndl))
    {
        new points = SQL_FetchInt(hndl, 0);

        decl String:steamid[32];
        SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

        decl String:sGangName[MAX_NAME_LENGTH];
        SQL_FetchString(hndl, 2, sGangName, sizeof(sGangName));

        Format(query, sizeof(query),
               "SELECT name FROM gangs WHERE ownersteamid = '%s'", steamid);
        SQL_TQuery(hDrugDB, checkNeedToPassCallback, query);

        Format(query, sizeof(query),
               "UPDATE playerdata SET isowner = 0 WHERE steamid = '%s'", steamid);

        if (points > threshold)
            continue;

        Format(query, sizeof(query),
               "DELETE FROM playerdata WHERE steamid = '%s'", steamid);
        SQL_TQuery(hDrugDB, EmptyCallback, query);

        if (StrEqual("None", sGangName))
            continue;

        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        SQL_EscapeString(hDrugDB, sGangName, sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "UPDATE gangs SET membercount = membercount - 1 WHERE name = '%s'",
               sNewName);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }
}

public checkNeedToPassCallback(Handle:hGang,
                               Handle:hndl, const String:error[], any:data)
{
    if (SQL_FetchRow(hndl))
    {
        decl String:query[256];
        decl String:sGangName[MAX_NAME_LENGTH];
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

        SQL_FetchString(hndl, 0, sGangName, sizeof(sGangName));
        SQL_EscapeString(hDrugDB, sGangName, sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "SELECT steamid, gang, name FROM playerdata WHERE gang = '%s' ORDER BY points DESC LIMIT 1",
               sNewName);

        new Handle:hData = CreateDataPack();
        WritePackString(hData, sNewName);

        SQL_TQuery(hDrugDB, prunePassLeaderCallback, query, hData);
    }
}

public prunePassLeaderCallback(Handle:hGang,
                               Handle:hndl, const String:error[], any:hData)
{
    if (SQL_FetchRow(hndl))
    {
        decl String:query[256];
        decl String:steamid[32];
        decl String:sGangName[MAX_NAME_LENGTH];
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

        SQL_FetchString(hndl, 0, steamid, sizeof(steamid));
        SQL_FetchString(hndl, 1, sGangName, sizeof(sGangName));

        SQL_EscapeString(hDrugDB, sGangName, sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "UPDATE gangs SET ownersteamid = '%s' WHERE name = '%s'",
               steamid, sNewName);
        SQL_TQuery(hDrugDB, EmptyCallback, query);

        Format(query, sizeof(query),
               "UPDATE playerdata SET isowner = 1, joined = 0 WHERE steamid = '%s'",
               steamid);
        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }

    else
    {
        ResetPack(hData);
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        decl String:query[256];

        ReadPackString(hData, sNewName, sizeof(sNewName));
        Format(query, sizeof(query),
               "DELETE FROM gangs WHERE name = '%s'", sNewName);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }

    CloseHandle(hData);
}

public checkNewGangNameCallback(Handle:hGang,
                                Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (SQL_FetchRow(hndl))
    {
        decl String:name[MAX_NAME_LENGTH];
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        decl String:query[256];
        decl String:steamid[32];

        GetClientName(client, name, sizeof(name));
        SQL_EscapeString(hDrugDB, name, sNewName, sizeof(sNewName));

        GetClientAuthString2(client, steamid, sizeof(steamid));
        Format(query, sizeof(query),
               "UPDATE gangs SET ownername = '%s' WHERE ownersteamid = '%s'",
               sNewName, steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }
}

public pruneTwoCallback(Handle:hGang,
                        Handle:hndl, const String:error[], any:data)
{
    decl String:query[256];

    while (SQL_FetchRow(hndl))
    {
        decl String:steamid[32];
        decl String:sGangName[MAX_NAME_LENGTH];

        SQL_FetchString(hndl, 0, steamid, sizeof(steamid));
        SQL_FetchString(hndl, 1, sGangName, sizeof(sGangName));

        Format(query, sizeof(query),
               "DELETE FROM playerdata WHERE steamid = '%s'", steamid);
        SQL_TQuery(hDrugDB, EmptyCallback, query);

        if (StrEqual("None", sGangName))
            continue;

        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        SQL_EscapeString(hDrugDB, sGangName, sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "UPDATE gangs SET membercount = membercount - 1 WHERE name = '%s'",
               sNewName);
        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }
}

public CheckNewNameCallback(Handle:hGang,
                            Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (SQL_FetchRow(hndl) && IsClientInGame(client))
    {
        decl String:name[MAX_NAME_LENGTH];
        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        decl String:query[256];
        decl String:steamid[32];

        GetClientName(client, name, sizeof(name));
        GetClientAuthString2(client, steamid, sizeof(steamid));

        SQL_EscapeString(hDrugDB, name, sNewName, sizeof(sNewName));
        Format(query, sizeof(query),
               "UPDATE playerdata SET name = '%s' WHERE steamid = '%s'",
               sNewName, steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }
}

public UpdateGangCache(Handle:hGang, Handle:hndl,
                       const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (SQL_FetchRow(hndl))
    {
        decl String:steamid[32];
        decl String:query[256];
        decl String:buffer[MAX_NAME_LENGTH];

        SQL_FetchString(hndl, 0, buffer, sizeof(buffer));
        SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

        if (!StrEqual(buffer, "None", false) && !StrEqual(buffer, ""))
            memberType[client] = MEMBERTYPE_MEMBER;
        
        if (SQL_FetchInt(hndl, 3))
            memberType[client] = MEMBERTYPE_COOWNER;

        if (SQL_FetchInt(hndl, 2))
            memberType[client] = MEMBERTYPE_OWNER;

        for (new i = 0; i < MAX_NAME_LENGTH; i++)
            sCacheGang[client][i] = buffer[i];

        Format(query, sizeof(query),
               "UPDATE playerdata SET lastconnect = strftime('%%s', 'now') WHERE steamid = '%s'",
               steamid);

        SQL_TQuery(hGang, EmptyCallback, query);
    }

    else
    {
        decl String:steamid[32];
        decl String:name[MAX_NAME_LENGTH];

        GetClientAuthString2(client, steamid, sizeof(steamid));
        GetClientName(client, name, sizeof(name));

        decl String:query[256];

        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        SQL_EscapeString(hDrugDB, name, sNewName, sizeof(sNewName));

        Format(query, sizeof(query),
               "INSERT INTO playerdata VALUES ('%s', 'None', '%s', 0, '%d', 0, 0, 0, 0, 0)",
               steamid, sNewName, GetTime());

        SQL_TQuery(hDrugDB, EmptyCallback, query);
        totalSQLKeys += 1;
    }
}

public EmptyCallback(Handle:hGang, Handle:hndl, const String:error[], any:data)
{
    if (!StrEqual(error, ""))
        LogError(error);
}


/* ----- Misc SQL Calls ----- */


stock PruneDatabase()
{
    decl String:query[256];
    new currentTime = GetTime();

    /*
     * Prune tier 1
     * Will only remove people who are not in a gang
     * with less than gang_prune_one_threshold points (50)
     * Who are inactive for gang_prune_two_days (14)
     */

    Format(query, sizeof(query),
           "DELETE FROM playerdata WHERE (totalspent + points) < %d and lastconnect < %d and gang = 'None'",
           GetConVarInt(hGangPruneOnethreshold),
           currentTime - GetConVarInt(hGangPruneOneDays) * 86400);

    SQL_TQuery(hDrugDB, EmptyCallback, query);

    /*
     * Prune tier 2
     * Will only remove people who are not gang leaders
     * with less than gang_prune_two_threshold points (400)
     * Who are inactive for gang_prune_two_days (30)
     */
     
    Format(query, sizeof(query),
           "SELECT steamid, gang FROM playerdata WHERE isowner = 0 and (totalspent + points) < %d and lastconnect < %d",
           GetConVarInt(hGangPruneTwothreshold),
           currentTime - (GetConVarInt(hGangPruneTwoDays) * 86400));

    SQL_TQuery(hDrugDB, pruneTwoCallback, query);

    /*
     * Prune tier 1
     * Will only everyone
     * If they're a gang leader, leadership will be passed
     * with less than gang_prune_three_threshold points (10000)
     * Who are inactive for gang_prune_three_days (60)
     * If they're a gang leader, but have more than gang_prune_three_threshold
     * Leadership will still be passed, but will not be deleted
     */

    Format(query, sizeof(query),
           "SELECT points, steamid, gang FROM playerdata WHERE lastconnect < %d",
           currentTime - (GetConVarInt(hGangPruneThreeDays) * 86400));
    SQL_TQuery(hDrugDB, pruneThreeCallback, query);
}

stock ConnectToDB()
{
    hDrugDB = SQLite_UseDatabase("gangs", sError, sizeof(sError));
 
    if (hDrugDB == INVALID_HANDLE)
        PrintToServer("[SM] Error: Could not connect to database - %s",
                      sError);

    /*
     * contributed - amount of points contributed to current gang
     * joined -- NOT WHAT YOU THINK -- changed to be if a player is a co owner
     * totaldrugs - Amount of drugs (not points) the player has collected
     * totalspent - Total points spent/donated
     */

    SQL_TQuery(hDrugDB, EmptyCallback,
                  "CREATE TABLE IF NOT EXISTS playerdata (steamid TEXT, gang TEXT, name TEXT, points INTEGER, lastconnect INTEGER, contributed INTEGER, joined INTEGER, totaldrugs INTEGER, totalspent INTEGER, isowner INTEGER)");

    /*
     * totalspent - Total points spent to date (on upgrades ect)
     * lastchange - time (since epoch) of last perk change
     * level - Gangs level
     * created - time (since epoch) the gang was created
     * perkschanged - times the perks have been changed
     * perkdrain - points to drain per round for the perk
     * perkcommand - command to execute on round start for perk
     * perkmultiplier - value for %m
     */

    SQL_TQuery(hDrugDB, EmptyCallback,
                  "CREATE TABLE IF NOT EXISTS gangs (name TEXT, ownersteamid TEXT, ownername TEXT, perk TEXT, perkcommand TEXT, trail TEXT, trailenabled INTEGER, rep INTEGER, membercount INTEGER, totalspent INTEGER, lastchange INTEGER, level INTEGER, created INTEGER, perkschanged INTEGER, private INTEGER, perkdrain INTEGER, givetype INTEGER, perkmultiplier REAL)");
}


/* ----- Misc Functions ----- */


stock DisplayMSay(client, const String:title[], time, const String:format[], any:...)
{
    decl String:message[255];
    VFormat(message, sizeof(message), format, 4);

    new Handle:panel = CreatePanel();

    SetPanelTitle(panel, title);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER);

    DrawPanelText(panel, message);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER);

    // If It's CS:GO, the 9 key is exit. If it's any other game, the 0 key is exit.
    SetPanelCurrentKey(panel, (g_iGame == GAMETYPE_CSGO ? 9 : 10));
    DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);

    SendPanelToClient(panel, client, EmptyMenuSelect, time);
    CloseHandle(panel);
}

stock RespawnPlayer(client)
{
    JB_RespawnPlayer(client);
}

stock GetClientAuthString2(client, String:steamid[], maxlength)
{
    GetClientAuthString(client, steamid, maxlength);
    ReplaceString(steamid, maxlength, "STEAM_1", "STEAM_0");
}

stock CheckLastRequest()
{
    if (bIsLR)
        return;

    new count;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && JB_IsPlayerAlive(i) && GetClientTeam(i) == 2)
            count++;
    }

    if (count != 2)
        return;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && JB_IsPlayerAlive(i))
        {
            SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);

            if (!StrEqual(sCacheGang[i], "None"))
            {
                new points = GetConVarInt(hRepAtLR);
                PrintToChat(i,
                            "%s Your gang has recieved \x04%i\x01 gang points for reaching LR",
                            MSG_PREFIX, points);
        
                AddRepByGang(sCacheGang[i], points);
            }
        }
    }

    bIsLR = true;
}

stock CheckNewName(client)
{
    decl String:steamid[32];
    decl String:query[256];

    GetClientAuthString2(client, steamid, sizeof(steamid));
    Format(query, sizeof(query),
           "SELECT name FROM playerdata WHERE steamid = '%s'", steamid);

    SQL_TQuery(hDrugDB, CheckNewNameCallback, query, GetClientUserIdSafe(client));

    Format(query, sizeof(query),
           "SELECT rep FROM gangs WHERE ownersteamid = '%s'", steamid);

    SQL_TQuery(hDrugDB,
               checkNewGangNameCallback, query, GetClientUserId(client));
}


/* ----- Return Values ----- */


bool:IsThursday()
{
    /*
    decl String:day[MAX_NAME_LENGTH];
    FormatTime(day, sizeof(day), "%A");

    return g_iGame == GAMETYPE_CSS ? StrEqual(day, "Thursday") : false;
    */

    return false;
}

FindClientFromSteamid(const String:steamid[])
{
    new target;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        decl String:tSteamid[32];
        GetClientAuthString2(i, tSteamid, sizeof(tSteamid));

        if (StrEqual(tSteamid, steamid))
        {
            target = i;
            break;
        }
    }

    if (!target)
        target = -1;

    return target;
}

isRatioFucked()
{
    new Float:ratio = GetConVarFloat(hMinRatio);
    if ((GetTeamClientCount(3) / float(GetTeamClientCount(2))) < ratio)
        return 1;
    return 0;
}

GetClientUserIdSafe(client)
{
    if (IsClientInGame(client))
        return GetClientUserId(client);
    return 0;
}
