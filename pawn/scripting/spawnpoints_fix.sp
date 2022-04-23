#include <sourcemod>
#include <sdktools>

new Handle:hSpawns = INVALID_HANDLE;
new total;
new bool:enabled;

public OnPluginStart()
{
    hSpawns = CreateTrie();
    HookEvent("player_spawn", OnPlayerSpawn);
}

public OnMapStart()
{
    decl String:current_map[MAX_NAME_LENGTH];
    GetCurrentMap(current_map, sizeof(current_map))

    enabled = StrEqual(current_map, "cs_crackhouse_b3", false);
    ClearTrie(hSpawns);

    new index = -1;
    total = 0;

    decl String:sTotal[8];
    decl Float:temp[3];

    while ((index = FindEntityByClassname(index, "info_player_terrorist")) != -1)
    {
        IntToString(total, sTotal, sizeof(sTotal));
        GetEntPropVector(index, Prop_Send, "m_vecOrigin", temp);

        if (temp[0] == 0.0 && temp[1] == 0.0)
            continue;

        SetTrieArray(hSpawns, sTotal, temp, 3);
        total++;
    }

    index = -1;
    new prev = 0;

    while ((index = FindEntityByClassname(index, "info_player_counterterrorist")) != -1)
    {
        IntToString(total, sTotal, sizeof(sTotal));
        GetEntPropVector(index, Prop_Send, "m_vecOrigin", temp);

        if (temp[0] == 0.0 && temp[1] == 0.0)
        {
            if (prev)
                AcceptEntityInput(index, "kill");
            prev = index;
        }
    }

    if (prev)
        AcceptEntityInput(prev, "kill");
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (enabled && client && IsPlayerAlive(client) && GetClientTeam(client) == 2)
    {
        decl String:sRand[8];
        IntToString(GetRandomInt(0, total), sRand, sizeof(sRand));

        decl Float:origin[3];
        GetTrieArray(hSpawns, sRand, origin, 3);

        TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
    }
}
