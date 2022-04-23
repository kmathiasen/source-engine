#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "0.0.1.9"

#define DMG_FALL (1 << 5)

public Plugin:myinfo =
{
	name = "No Fall Damage",
	author = "alexip121093",
	description = "no falling damage",
	version = PLUGIN_VERSION,
	url = "www.sourcemod.net"
}

public OnPluginStart()
{
    // Hook SDKHook events for each client.
    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
    if(damagetype & DMG_FALL)
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}
