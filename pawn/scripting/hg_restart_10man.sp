#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define INTERVAL 60.0

new g_iRestartTime;

public OnPluginStart()
{
    CreateTimer(INTERVAL, Timer_CheckRestart, _, TIMER_REPEAT);
}

public Action:Timer_CheckRestart(Handle:timer, any:data)
{
    g_iRestartTime += INTERVAL;

    if (g_iRestartTime > 60 * 60 * 6)
    {
        new bool:humans = false;

        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                humans = true;
                break;
            }
        }

        if (!humans)
        {
            InsertServerCommand("_restart");
            ServerExecute();
        }
    }

    return Plugin_Continue;
}
