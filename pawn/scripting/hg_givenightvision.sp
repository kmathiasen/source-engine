
// Includes.
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

// Definitions.
#define MSG_PREFIX "\x01\x03"
#define PLUGIN_NAME "hg_givenightvision"
#define PLUGIN_VERSION "0.01"

// Plugin display info.
public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "HG Give Nightvision",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

public OnPluginStart()
{
    // Hook events.
    HookEvent("round_start", OnRoundStart);
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    CreateTimer(5.0, GiveNightVision);
}

public Action:GiveNightVision(Handle:timer)
{
    for(new i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
            continue;
        GivePlayerItem(i, "item_nvgs");
    }
    return Plugin_Stop;
}
