#include <sourcemod>
#include <sdktools>

#define DEFAULT_TIMEOUT 30
#define LEN_STEAMIDS 24
#define MSG_PREFIX "\x03[Timer]: \x01"

new bool:bDisabledForMap = true;

new iSpriteBeam = -1;
new iSpriteRing = -1;
new iColorBlue[4] = {50, 75, 255, 255};

new Handle:hAdminMenu = INVALID_HANDLE;
new Handle:hSpawnPoints = INVALID_HANDLE;
new Handle:hCompletedSteamidsArray = INVALID_HANDLE;

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

new String:sCachedMap[MAX_NAME_LENGTH];
new String:sSpawnPointsPath[PLATFORM_MAX_PATH];

/* ----- Plugin Info ----- */


public Plugin:myinfo =
{
    name = "Minigames GameME points for Hells Gamers",
    author = "Bonbon",
    description = "Rewards players GameME points for completing a map",
    version = "0.0.0beta",
    url = "http://hellsgamers.com/"
}
/* ----- Events ----- */

public OnPluginStart()
{
    RegConsoleCmd("sm_addstart", Command_AddStart,
                  "Create a starting location for the current map");

    RegConsoleCmd("sm_addend", Command_AddEnd,
                  "Create an ending location for the current map");

    RegConsoleCmd("sm_tadmin", Command_AdminMenu,
                  "Displays the timer admin menu");

    CreateMenus();

    BuildPath(Path_SM,
              sSpawnPointsPath, sizeof(sSpawnPointsPath), "data/bhoptimer.txt");

    hSpawnPoints = CreateKeyValues("locations");
    hCompletedSteamidsArray = CreateArray(ByteCountToCells(LEN_STEAMIDS));

    if (FileExists(sSpawnPointsPath))
        FileToKeyValues(hSpawnPoints, sSpawnPointsPath);

    CheckDisabled();

    CreateTimer(20.0, Timer_ShowPoints, _, TIMER_REPEAT);
    CreateTimer(1.0, Timer_CheckFinished, _, TIMER_REPEAT);
}

public OnMapStart()
{
    iSpriteBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
    iSpriteRing = PrecacheModel("materials/sprites/glow01.vmt");

    GetCurrentMap(sCachedMap, sizeof(sCachedMap));
    ClearArray(hCompletedSteamidsArray);
    CheckDisabled();
}

/* ----- Commands ----- */

public Action:Command_AdminMenu(client, args)
{
    if (IsAuthed(client))
        DisplayMenu(hAdminMenu, client, DEFAULT_TIMEOUT);
    return Plugin_Handled;

}

public Action:Command_AddStart(client, args)
{
    if (IsAuthed(client))
        AddLocation(0, client);
    return Plugin_Handled;
}

public Action:Command_AddEnd(client, args)
{
    if (IsAuthed(client))
        AddLocation(1, client);
    return Plugin_Handled;
}


/* ----- Menus ----- */


public AddTopLeftSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action == MenuAction_Select)
    {
        GetClientAbsOrigin(client, fTempTopLeft);
        SetStockAngles(client, "Bottom Right");

        decl String:point[8];
        GetMenuItem(menu, selected, point, sizeof(point));

        new Handle:menu2 = CreateMenu(AddBottomRightSelect);
        SetMenuTitle(menu2, "Select Bottom Right Corner");

        AddMenuItem(menu2, point, "Select Bottom Right Corner");
        DisplayMenu(menu2, client, MENU_TIME_FOREVER);
    }
}

public AddBottomRightSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:point[8];
        GetMenuItem(menu, selected, point, sizeof(point));

        GetClientAbsOrigin(client, fTempBottomRight);

        /*
         * Up is +, corresponds to length, x.
         * Left is +, corresponds to width, y.
         */

        new temp;
        new Float:halfLength = (fTempTopLeft[0] - fTempBottomRight[0]) / 2.0;
        new Float:halfWidth = (fTempTopLeft[1] - fTempBottomRight[1]) / 2.0;

        if (StrEqual(point, "start"))
        {
            fCachedStart[0] = fTempTopLeft[0] - halfLength;
            fCachedStart[1] = fTempTopLeft[1] - halfWidth;
            fCachedStart[2] = fTempTopLeft[2];

            fCachedStartWidth = halfWidth;
            fCachedStartLength = halfLength;
        }

        else
        {
            fCachedEnd[0] = fTempTopLeft[0] - halfLength;
            fCachedEnd[1] = fTempTopLeft[1] - halfWidth;
            fCachedEnd[2] = fTempTopLeft[2];

            fCachedEndWidth = halfWidth;
            fCachedEndLength = halfLength;
            temp = 1;
        }

        decl String:sLengthKey[16];
        decl String:sWidthKey[16];

        Format(sLengthKey, sizeof(sLengthKey), "%s length", point);
        Format(sWidthKey, sizeof(sWidthKey), "%s width", point);

        /*
         * Rewind the KeyValue
         * Set the location to the current map
         * Create the current map key, if it doesn't exist (because that's not
         *  done on map start)
         */

        KvRewind(hSpawnPoints);
        KvJumpToKey(hSpawnPoints, sCachedMap, true);

        KvSetFloat(hSpawnPoints, sLengthKey, halfLength);
        KvSetFloat(hSpawnPoints, sWidthKey, halfWidth);

        switch (temp)
        {
            case 0:
                KvSetVector(hSpawnPoints, point, fCachedStart);

            case 1:
                KvSetVector(hSpawnPoints, point, fCachedEnd);
        }

        /* Save the KeyValue file */
        KvRewind(hSpawnPoints);
        KeyValuesToFile(hSpawnPoints, sSpawnPointsPath);

        PrintToChat(client, "%sSaving data file...", MSG_PREFIX);
        CheckDisabled();

        Timer_ShowPoints(INVALID_HANDLE, 0);
    }
}


/* ----- Menus ----- */


public AdminMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action != MenuAction_Select)
        return;

    switch (selected + 1)
    {
        /* Add Start Location */
        case 1:
            AddLocation(0, client);

        /* Add End Location */
        case 2:
            AddLocation(1, client);
    }
}


/* ----- Functions ----- */


LogEventToGame(const String:event[], client)
{
    decl String:Auth[64];

    GetClientAuthString(client, Auth, sizeof(Auth));
    if (!GetClientAuthString(client, Auth, sizeof(Auth))) {
        strcopy(Auth, sizeof(Auth), "UNKNOWN");
    }

    new team = GetClientTeam(client), UserId = GetClientUserId(client);
    LogToGame("\"%N<%d><%s><%s>\" triggered \"%s\"", client, UserId, Auth, (team == 2) ? "TERRORIST" : "CT", event);
    LogMessage("\"%N<%d><%s><%s>\" triggered \"%s\"", client, UserId, Auth, (team == 2) ? "TERRORIST" : "CT", event);
}

stock CreateStandardBeam(Float:start[3], Float:end[3])
{
    TE_SetupBeamPoints(start, end,
                       iSpriteBeam, iSpriteRing,
                       1, 1, 20.0, 5.0, 5.0, 0, 10.0, iColorBlue, 256);
    TE_SendToAll();
}

stock CheckDisabled()
{
    KvRewind(hSpawnPoints);

    /* Fast caching of wether or not the map has spawn points */
    if(KvJumpToKey(hSpawnPoints, sCachedMap))
    {
        bDisabledForMap = false;

        KvGetVector(hSpawnPoints, "end", fCachedEnd, NULL_VECTOR);
        fCachedEndWidth = KvGetFloat(hSpawnPoints, "end width", 0.0);
        fCachedEndLength = KvGetFloat(hSpawnPoints, "end length", 0.0);

        /* Either a start location, or end location is missing */
        if (fCachedEndWidth == 0.0)
            bDisabledForMap = true;
    }

    else
    {
        bDisabledForMap = true;
        fCachedStartWidth = 0.0;
        fCachedEndWidth = 0.0;
    }
}

stock CreateMenus()
{
    hAdminMenu = CreateMenu(AdminMenuSelect);
    SetMenuTitle(hAdminMenu, "Timer Admin");

    AddMenuItem(hAdminMenu, "", "Add Start Point");
    AddMenuItem(hAdminMenu, "", "Add End Point");
}

/**
 * 0 - Add Start Location
 * 1 - Add End Location
 */

stock AddLocation(point, client)
{
    new Handle:menu = CreateMenu(AddTopLeftSelect);
    SetMenuTitle(menu, "Select Top Left Corner");

    switch (point)
    {
        case 0:
            AddMenuItem(menu, "start", "Select Top Left Corner");

        case 1:
            AddMenuItem(menu, "end", "Select Top Left Corner");
    }

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    SetStockAngles(client, "Top Left");
}

stock SetStockAngles(client, const String:corner[])
{
    /* I have a feeling NULL_VECTOR is {0.0, 0.0, 0.0} */
    decl Float:angles[3] = {0.01, 0.01, 0.01};
    TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);

    PrintToChat(client, "%s\x04IMPORTANT\x03!!!", MSG_PREFIX);
    PrintToChat(client,
                "%sSelect \x04%s\x01 Corner based on current view",
                MSG_PREFIX, corner);
}


/* ----- Timers ----- */


public Action:Timer_CheckFinished(Handle:timer, any:data)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) < 2 || !IsPlayerAlive(i))
            continue;

        decl Float:origin[3];
        GetClientAbsOrigin(i, origin);

        if (FloatAbs(origin[0] - fCachedEnd[0]) > fCachedEndWidth ||
            FloatAbs(origin[1] - fCachedEnd[1]) > fCachedEndLength ||
            origin[2] - fCachedEnd[2] > 100.0 ||
            fCachedEnd[2] - origin[2] < 66.0)
            continue;

        decl String:steamid[LEN_STEAMIDS];
        GetClientAuthString(i, steamid, sizeof(steamid));

        if (FindStringInArray(hCompletedSteamidsArray, steamid) > -1)
            continue;

        LogEventToGame("Meow", i);
        PushArrayString(hCompletedSteamidsArray, steamid);
    }
}

public Action:Timer_ShowPoints(Handle:timer, any:interval)
{
    decl Float:fTempTopLeft2[3];
    decl Float:fTempBottomRight2[3];

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


/* ----- Return Values ----- */


bool:IsAuthed(client)
{
    decl String:steamid[32];
    GetClientAuthString(client, steamid, sizeof(steamid));

    if (GetUserFlagBits(client) & ADMFLAG_ROOT  ||
        GetUserFlagBits(client) & ADMFLAG_CHANGEMAP)
        return true;

    PrintToChat(client,
                "%sYou are not authorized to mess up the map coords",
                MSG_PREFIX);
    return false;
}
