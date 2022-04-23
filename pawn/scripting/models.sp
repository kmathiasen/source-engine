#include <sourcemod>
#include <sdktools>

/*
public OnMapStart()
{
    new String:strMap[128];
    GetCurrentMap(strMap, sizeof(strMap));
    Format(strMap, sizeof(strMap), "maps/%s.bsp", strMap);
    AddFileToDownloadsTable(strMap);
}
*/

public OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    if (GetClientTeam(client) == 2)
    {
        PrecacheModel("models/hostage/hostage.mdl");
        SetEntityModel(client, "models/hostage/hostage.mdl");
    }
}
