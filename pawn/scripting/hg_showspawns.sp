#include <sourcemod>
#include <sdktools>
#define BEAM_SECONDS 20.0

new g_iTrustedAdmins[MAXPLAYERS + 1];
new beam = -1;
new halo = -1;

public OnPluginStart()
{
    CreateTimer(BEAM_SECONDS, Timer_ShowSpawns, _, TIMER_REPEAT);
}

public OnMapStart()
{
    beam = PrecacheModel("materials/sprites/laser.vmt");
    halo = PrecacheModel("materials/sprites/halo01.vmt");
    ShowSpawns("info_player_terrorist", 255, 0, 0, 255);
    ShowSpawns("info_player_counterterrorist", 0, 0, 255, 255);
}

public Action:Timer_ShowSpawns(Handle:timer, any:data)
{
    ShowSpawns("info_player_terrorist", 255, 0, 0, 255);
    ShowSpawns("info_player_counterterrorist", 0, 0, 255, 255);
    return Plugin_Continue;
}

stock ShowSpawns(const String:classname[], r, g, b, a)
{
    // Get trusted admins
    new adminFlags;
    new bufferIndex;
    for(new i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;
        adminFlags = GetUserFlagBits(i);
        if(!(adminFlags & ADMFLAG_CHANGEMAP) && !(adminFlags & ADMFLAG_ROOT))
            continue;
        g_iTrustedAdmins[bufferIndex] = i;
        bufferIndex++;
    }
    if(bufferIndex <= 0)
        return;

    // Show each spawnpoint.
    new ent = -1;
    new color[4];
    color[0] = r;
    color[1] = g;
    color[2] = b;
    color[3] = a;
    while ((ent = FindEntityByClassname(ent, classname)) != -1)
    {
        decl Float:origin[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
        TE_SetupBeamRingPoint(origin, 50.0, 51.0, beam, halo,
                              0, 15, BEAM_SECONDS, 7.0, 0.0, color, 1, 0);
        TE_Send(g_iTrustedAdmins, bufferIndex);
    }
}
