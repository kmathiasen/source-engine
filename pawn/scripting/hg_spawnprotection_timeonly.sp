#include <sourcemod>
#include <sdktools>

#define TEAM_T 2
#define TEAM_CT 3
 
public Plugin:myinfo =
{
    name = "hg_spawnprotection",
    author = "HeLLsGamers",
    description = "HG DM Spawn Protection (Just time based)",
    version = "1.3",
    url = "http://www.hellsgamers.com/"
};

// ConVars.
new Handle:g_hProtectionTimeCT = INVALID_HANDLE;
new Handle:g_hProtectionTimeT = INVALID_HANDLE;
new Float:g_fProtectionTimeCT = 3.0;
new Float:g_fProtectionTimeT = 3.0;
new Handle:g_hTColor = INVALID_HANDLE;
new Handle:g_hCTColor = INVALID_HANDLE;
new g_iTColor[4] = {255, 0, 0, 150};
new g_iCTColor[4] = {0, 0, 255, 150};

// Timer handle storage.
new Handle:g_hProtectionTimers[MAXPLAYERS + 1];
new g_iProtectionTimeLeft[MAXPLAYERS + 1];

public OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_death", OnPlayerDeath);

    // ConVars.
    g_hProtectionTimeCT = CreateConVar("hg_spawn_protection_time_ct", "3.0",
                                       "The amount of seconds that the CT team will be protected");
    g_hProtectionTimeT = CreateConVar("hg_spawn_protection_time_t", "3.0",
                                      "The amount of seconds that the T team will be protected");
    g_hTColor = CreateConVar("hg_spawn_protection_t_color", "255 0 0 150",
                             "RGBA Value of Ts when they have spawn protection");
    g_hCTColor = CreateConVar("hg_spawn_protection_ct_color", "0 0 255 150",
                              "RGBA Value of CTs when they have spawn protection");
    HookConVarChange(g_hProtectionTimeCT, OnConVarChanged);
    HookConVarChange(g_hProtectionTimeT, OnConVarChanged);
    HookConVarChange(g_hTColor, OnConVarChanged);
    HookConVarChange(g_hCTColor, OnConVarChanged);
    AutoExecConfig(true);

    // Ensure nobody is permanently protected due to reloading the plugin.
    for(new i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i) || GetClientTeam(i) < TEAM_T)
            continue;
        SetEntityHealth(i, 100);
        SetEntityRenderColor(i, 255, 255, 255, 255);
    }
}

public OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    decl String:temp[4][4];

    if (CVar == g_hProtectionTimeCT)
        g_fProtectionTimeCT = GetConVarFloat(CVar);

    else if (CVar == g_hProtectionTimeT)
        g_fProtectionTimeT = GetConVarFloat(CVar);

    else if (CVar == g_hTColor)
    {
        ExplodeString(newv, " ", temp, 4, 4);
        for (new i = 0; i < 4; i++)
            g_iTColor[i] = StringToInt(temp[i]);
    }

    else
    {
        ExplodeString(newv, " ", temp, 4, 4);
        for (new i = 0; i < 4; i++)
            g_iCTColor[i] = StringToInt(temp[i]);
    }
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new team = GetClientTeam(client);

    // IIRC, player_spawn fires once before player_activate.
    if (team < TEAM_T)
        return;

    // Set the player to invulnerable and a special transparent color.
    SetEntityHealth(client, 5221);
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    if (team == TEAM_T)
    {
        SetEntityRenderColor(client, g_iTColor[0], g_iTColor[1], g_iTColor[2], g_iTColor[3]);
        g_iProtectionTimeLeft[client] = RoundToNearest(g_fProtectionTimeT);
    }
    else
    {
        SetEntityRenderColor(client, g_iCTColor[0], g_iCTColor[1], g_iCTColor[2], g_iCTColor[3]);
        g_iProtectionTimeLeft[client] = RoundToNearest(g_fProtectionTimeCT);
    }

    // No need for userids here, we handle OnClientDisconnect.
    g_hProtectionTimers[client] = CreateTimer(1.0,
                                              CheckSpawnProtection,
                                              client,
                                              TIMER_REPEAT);
}

public Action:CheckSpawnProtection(Handle:timer, any:client)
{
    // If the invulnerability time is over, stop invulnerability.
    if (g_iProtectionTimeLeft[client] <= 0)
    {
        // Set his health and color back to normal.
        SetEntityHealth(client, 100);
        SetEntityRenderColor(client, 255, 255, 255, 255);
        g_hProtectionTimers[client] = INVALID_HANDLE;

        // Notify player he is no longer protected.
        PrintHintText(client, "YOU ARE NO LONGER PROTECTED");
        return Plugin_Stop;
    }

    // Otherwise, decrement the invulnerability time left.
    else
    {
        // Notify player of how much time is left.
        PrintHintText(client, "SPAWN PROTECTION WILL END IN %i SECONDS", g_iProtectionTimeLeft[client]);

        // Decrement time left.
        g_iProtectionTimeLeft[client]--;
        return Plugin_Continue;
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
