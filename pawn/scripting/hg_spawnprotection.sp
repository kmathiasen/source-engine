#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define MSG_PREFIX "\x01[\x04HG Spawn Protection\x01]\x03"
#define TEAM_UNASSIGNED 0
#define TEAM_SPEC 1
#define TEAM_T 2
#define TEAM_CT 3
#define CHECK_MOVE_EVERY 0.50

public Plugin:myinfo =
{
    name = "hg_spawnprotection",
    author = "HeLLsGamers",
    description = "HG DM Spawn Protection",
    version = "1.0.3",
    url = "http://www.hellsgamers.com/"
};

// ConVar handles.
new Handle:g_hBoxSize = INVALID_HANDLE;
new Handle:g_hMaxProtectedTime = INVALID_HANDLE;
new Handle:g_hMaxProtectedShots = INVALID_HANDLE;
new Handle:g_hTColor = INVALID_HANDLE;
new Handle:g_hCTColor = INVALID_HANDLE;

// ConVar values.
new Float:g_fBoxSize = 150.0;
new Float:g_fMaxProtectedTime = 5.0;
new g_iMaxProtectedShots = 5;
new g_iTColor[4] = {255, 0, 0, 150};
new g_iCTColor[4] = {0, 0, 255, 150};

// Global handles.
new Handle:g_hProtectionTimers[MAXPLAYERS + 1];     // Holds timer handle for each player.
new Handle:g_hWepAlphaTimers[MAXPLAYERS + 1];       // ^ for setting weapon alphas.
new Float:g_fLocationsOfSpawn[MAXPLAYERS + 1][3];   // Holds origin vector for each player.
new Float:g_fTimesOfSpawn[MAXPLAYERS + 1];          // Holds timestamp when spawned for each player.
new g_iPlayerShots[MAXPLAYERS + 1];                 // Holds number of shots taken for each player.

// Models, and sprites (indicies).
new g_iSpriteBeam = -1;
new g_iSpriteRing = -1;

// Colors. {R, G, B, A}
new g_iColorRed[4] = {255, 25, 15, 255};
new g_iColorGreen[4] = {25, 255, 30, 255};
new g_iColorBlue[4] = {50, 75, 255, 255};

public OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_death", OnPlayerDeath);
    HookEvent("weapon_fire", OnPlayerShoot);
    HookEvent("item_pickup", OnItemPickup);
    RegAdminCmd("showboxes", Command_ShowBoxes, ADMFLAG_CHANGEMAP, "Shows spawn protection boxes relative to each spawn point");

    // ConVars.
    g_hBoxSize = CreateConVar("hg_spawn_box_size", "150.0",
                              "Size of the protection box");
    g_hMaxProtectedTime = CreateConVar("hg_spawn_protected_max_time", "5.0",
                                       "Max amount of seconds that can pass before spawn protection goes away");
    g_hMaxProtectedShots = CreateConVar("hg_spawn_protected_max_shots", "5",
                                        "Max number of shots a protected player can take before protection goes away");
    g_hTColor = CreateConVar("hg_spawn_protection_t_color", "255 0 0 150",
                             "RGBA Value of Ts when they have spawn protection");
    g_hCTColor = CreateConVar("hg_spawn_protection_ct_color", "0 0 255 150",
                              "RGBA Value of CTs when they have spawn protection");
    HookConVarChange(g_hBoxSize, OnConVarChanged);
    HookConVarChange(g_hMaxProtectedTime, OnConVarChanged);
    HookConVarChange(g_hTColor, OnConVarChanged);
    HookConVarChange(g_hCTColor, OnConVarChanged);
    AutoExecConfig(true);

    // Ensure nobody is permanently protected due to reloading the plugin.
    for(new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) <= TEAM_SPEC)
            continue;
        SetEntityHealth(i, 100);
        SetEntityRenderColor(i, 255, 255, 255, 255);
        g_iPlayerShots[i] = 0;
    }
}

public OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    decl String:temp[4][4];

    if (CVar == g_hBoxSize)
    {
        g_fBoxSize = GetConVarFloat(CVar);
        PrintToChatAll("%s CVar \"Box Size\" changed to [%f]", MSG_PREFIX, g_fBoxSize);
    }

    else if (CVar == g_hMaxProtectedTime)
    {
        g_fMaxProtectedTime = GetConVarFloat(CVar);
        PrintToChatAll("%s CVar \"Protection Time\" changed to [%f]", MSG_PREFIX, g_fMaxProtectedTime);
    }

    else if (CVar == g_hMaxProtectedShots)
    {
        g_iMaxProtectedShots = GetConVarInt(CVar);
        PrintToChatAll("%s CVar \"Protected Shots\" changed to [%i]", MSG_PREFIX, g_iMaxProtectedShots);
    }

    else if (CVar == g_hTColor)
    {
        ExplodeString(newv, " ", temp, 4, 4);
        for (new i = 0; i < 4; i++)
            g_iTColor[i] = StringToInt(temp[i]);
        PrintToChatAll("%s CVar \"T Protected Color\" changed to [%s]", MSG_PREFIX, newv);
    }

    else if (CVar == g_hCTColor)
    {
        ExplodeString(newv, " ", temp, 4, 4);
        for (new i = 0; i < 4; i++)
            g_iCTColor[i] = StringToInt(temp[i]);
        PrintToChatAll("%s CVar \"CT Protected Color\" changed to [%s]", MSG_PREFIX, newv);
    }
}

public OnMapStart()
{
    // Pre-cache models and sprites.
    g_iSpriteBeam = PrecacheModel("materials/sprites/laser.vmt");
    g_iSpriteRing = PrecacheModel("materials/sprites/halo01.vmt");
}

MakeProtected(client)
{
    // Notify player he is protected.
  //PrintToChat(client, "%s YOU ARE PROTECTED WHILE INSIDE PROTECTION BOX FOR %i SECONDS", MSG_PREFIX, RoundToNearest(g_fMaxProtectedTime));

    // Set the player to invulnerable and a special transparent color.
    SetEntityHealth(client, 5221);
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    if (GetClientTeam(client) == TEAM_T)
        SetEntityRenderColor(client, g_iTColor[0], g_iTColor[1], g_iTColor[2], g_iTColor[3]);
    else
        SetEntityRenderColor(client, g_iCTColor[0], g_iCTColor[1], g_iCTColor[2], g_iCTColor[3]);

    // Show client's protection box to the client.
    ShowBoxOfClient(client);
}

MakeUnprotected(client)
{
    // Notify player he is no longer protected.
  //PrintToChat(client, "%s YOU ARE NO LONGER PROTECTED", MSG_PREFIX);
    PrintHintText(client, "YOU ARE NO LONGER PROTECTED");

    // Set his health and color back to normal.
    SetEntityHealth(client, 100);
    SetEntityRenderColor(client, 255, 255, 255, 255);

    // Set WEAPON alpha.
    SetAlphaOfClientItems(client, 255);
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // IIRC, player_spawn fires once before player_activate.
    if (GetClientTeam(client) <= TEAM_SPEC)
        return;

    // Record [where] and [when] this player spawned, so we can compare against these values later.
    GetClientAbsOrigin(client, g_fLocationsOfSpawn[client]);
    g_fTimesOfSpawn[client] = GetEngineTime();

    // Protect client.
    MakeProtected(client);

    // No need for userids here, we handle OnClientDisconnect.
    g_hProtectionTimers[client] = CreateTimer(CHECK_MOVE_EVERY, CheckTimeAndLocation,
                                             client, TIMER_REPEAT);
}

public Action:CheckTimeAndLocation(Handle:timer, any:client)
{
    // Compare this client's [current location] and [time since he spawned] to the values
    // that we recorded when he first spawned.  If they exceed the pre-set limits, he should
    // no longer be invulnerable.
    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);
    if (origin[0] < g_fLocationsOfSpawn[client][0] - g_fBoxSize ||
        origin[0] > g_fLocationsOfSpawn[client][0] + g_fBoxSize ||
        origin[1] < g_fLocationsOfSpawn[client][1] - g_fBoxSize ||
        origin[1] > g_fLocationsOfSpawn[client][1] + g_fBoxSize ||
        GetEngineTime() - g_fTimesOfSpawn[client] >= g_fMaxProtectedTime)
    {
        // Unprotected client.
        MakeUnprotected(client);

        // Kill this repeating timer.
        g_hProtectionTimers[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    // He still has not exceeded the pre-set limits.  Keep him invulnerable and keep this
    // timer alive so we can check again on the next tick.
    return Plugin_Continue;
}

public OnPlayerShoot(Handle:event, const String:name[], bool:db)
{
    // Get client.
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // Is he currently protected?
    if (g_hProtectionTimers[client] != INVALID_HANDLE)
    {
        // Add this shot to the array tracking the number of shots for each player.
        g_iPlayerShots[client]++;

        // Did he reach the max allowed number of shots?
        if (g_iPlayerShots[client] >= g_iMaxProtectedShots)
        {
            // Unprotect client.
            MakeUnprotected(client);

            // Reset his trackers.
            CloseHandle(g_hProtectionTimers[client]);
            g_hProtectionTimers[client] = INVALID_HANDLE;
            g_iPlayerShots[client] = 0;
        }
    }
}

public OnItemPickup(Handle:event, const String:eventname[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (GetClientTeam(client) <= TEAM_SPEC)
        return;

    // Is he currently protected?
    if (g_hProtectionTimers[client] != INVALID_HANDLE)
    {
        // Schedule a timer to set WEAPON alpha.
        if (g_hWepAlphaTimers[client] != INVALID_HANDLE)
            CloseHandle(g_hWepAlphaTimers[client]);
        g_hWepAlphaTimers[client] = CreateTimer(0.3, SetWepAlphaDelayed, client);
    }
}

public OnPlayerDeath(Handle:event, const String:name[], bool:db)
{
    StopTimer(GetClientOfUserId(GetEventInt(event, "userid")));
}

public OnClientDisconnect(client)
{
    StopTimer(client);
}

stock StopTimer(client)
{
    if (g_hProtectionTimers[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hProtectionTimers[client]);
        g_hProtectionTimers[client] = INVALID_HANDLE;
    }
}

public Action:Command_ShowBoxes(client, args)
{
    if ((client <= 0) || (!IsClientInGame(client)))
    {
        PrintToConsole(0, "This command requires you to be in-game");
        return Plugin_Handled;
    }
    ShowBoxes("info_player_counterterrorist", g_iColorBlue, client);
    ShowBoxes("info_player_terrorist", g_iColorRed, client);
    return Plugin_Handled;
}

stock ShowBoxes(const String:classname[], rgba[4], client)
{
    // For each spawnpoint in map...
    new ent = -1;
    decl Float:origin[3];
    new Float:delay = 0.1;
    new Float:seconds = 30.0;
    while ((ent = FindEntityByClassname(ent, classname)) != -1)
    {
        // Get location of spawnpoint.
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);

        // There is a limit on how many entities can be drawn on a client's screen per gameframe.
        // We will need to pack up the necessary info and call a timer delayed by one gameframe.
        // The entities will be drawn in the timer callback.
        new Handle:data = CreateDataPack();
        WritePackCell(data, client && IsClientInGame(client) ? GetClientUserId(client) : 0);
        WritePackArray(data, origin, sizeof(origin));
        WritePackArray(data, rgba, sizeof(rgba));
        WritePackFloat(data, seconds);
        CreateTimer(delay, DrawBoxeEntities, any:data);
        delay += 0.1;
    }
}

stock ShowBoxOfClient(client)
{
    // Get client info.
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    // Draw box.
    new Handle:data = CreateDataPack();
    WritePackCell(data, GetClientUserId(client));
    WritePackArray(data, g_fLocationsOfSpawn[client], 3);
    if (GetClientTeam(client) == TEAM_T)
        WritePackArray(data, g_iColorRed, sizeof(g_iColorRed));
    else
        WritePackArray(data, g_iColorBlue, sizeof(g_iColorBlue));
    WritePackFloat(data, g_fMaxProtectedTime);
    CreateTimer(0.1, DrawBoxeEntities, any:data);
}

public Action:DrawBoxeEntities(Handle:timer, any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    decl Float:origin[3];
    decl rgba[4];
    new client = GetClientOfUserId(ReadPackCell(Handle:data));
    ReadPackArray(data, origin, sizeof(origin));
    ReadPackArray(data, rgba, sizeof(rgba));
    new Float:seconds = ReadPackFloat(Handle:data);
    CloseHandle(Handle:data);
    if (!client)
        return Plugin_Stop;

    // Define the points of the box around this spawnpoint.
    new Float:x = origin[0]; // x corresponds to length
    new Float:y = origin[1]; // y corresponds to width
    new Float:z = origin[2]; // z corresponds to height
    decl Float:NorthWestPoint[3];
    decl Float:NorthEastPoint[3];
    decl Float:SouthWestPoint[3];
    decl Float:SouthEastPoint[3];
    PopulateVector(NorthWestPoint,
                   x - g_fBoxSize,
                   y + g_fBoxSize,
                   z);
    PopulateVector(NorthEastPoint,
                   x + g_fBoxSize,
                   y + g_fBoxSize,
                   z);
    PopulateVector(SouthWestPoint,
                   x - g_fBoxSize,
                   y - g_fBoxSize,
                   z);
    PopulateVector(SouthEastPoint,
                   x + g_fBoxSize,
                   y - g_fBoxSize,
                   z);

    // Draw the line segments of this box.
    CreateStandardBeam(NorthWestPoint, NorthEastPoint, rgba, seconds, client); // North side of box.
    CreateStandardBeam(SouthWestPoint, SouthEastPoint, rgba, seconds, client); // South side of box.
    CreateStandardBeam(NorthWestPoint, SouthWestPoint, rgba, seconds, client); // West side of box.
    CreateStandardBeam(NorthEastPoint, SouthEastPoint, rgba, seconds, client); // East side of box.

    // Draw the diagonal cross beams of this box.
    CreateStandardBeam(NorthWestPoint, SouthEastPoint, g_iColorGreen, seconds, client);
    CreateStandardBeam(NorthEastPoint, SouthWestPoint, g_iColorGreen, seconds, client);

    // Done.
    return Plugin_Stop;
}

public Action:SetWepAlphaDelayed(Handle:timer, any:client)
{
    // Reset timer tracker.
    g_hWepAlphaTimers[client] = INVALID_HANDLE;

    // Set WEAPON alpha.
    if(IsClientInGame(client) && IsPlayerAlive(client))
        SetAlphaOfClientItems(client, GetClientTeam(client) == TEAM_T ? g_iTColor[3] : g_iCTColor[3]);

    // Done.
    return Plugin_Stop;
}

stock CreateStandardBeam(Float:start[3], Float:end[3], rgba[4], Float:seconds, client)
{
    TE_SetupBeamPoints(start, end, g_iSpriteBeam, g_iSpriteRing, 1, 1, seconds, 5.0, 5.0, 0, 10.0, rgba, 255);
    TE_SendToClient(client);
}

stock PopulateVector(Float:arr[3], Float:x, Float:y, Float:z)
{
    arr[0] = x;
    arr[1] = y;
    arr[2] = z;
}

stock ReadPackArray(Handle:data, any:buffer[], numcells)
{
    for(new i = 0; i < numcells; i++)
        buffer[i] = ReadPackCell(data);
}

stock WritePackArray(Handle:data, const any:array[], numcells)
{
    for(new i = 0; i < numcells; i++)
        WritePackCell(data, array[i]);
}

stock SetAlphaOfClientItems(client, alpha)
{
    new iItems = FindSendPropOffs("CBaseCombatCharacter", "m_hMyWeapons");
    if (iItems != -1)
    {
        for(new i=0; i<=128; i+=4)
        {
            new nEntityID = GetEntDataEnt2(client, (iItems+i));
            if (!IsValidEdict(nEntityID))
                continue;
            SetEntityRenderMode(nEntityID, RENDER_TRANSCOLOR);
            SetEntityRenderColor(nEntityID, 255, 255, 255, alpha);
        }
    }
}
