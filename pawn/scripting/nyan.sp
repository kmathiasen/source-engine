#include <sourcemod>
#include <sdktools>

#define SOUND_LENGTH 3.202

#define TRAILS_LIFETIME "4.0"
#define TRAILS_START_WIDTH "40.0"
#define TRAILS_END_WIDTH "45.0"

new Handle:hNyanTimers[MAXPLAYERS + 1];
new iTrailEntities[MAXPLAYERS + 1];

public OnPluginStart()
{
    RegAdminCmd("sm_nyan", Command_Nyan, ADMFLAG_ROOT);
    LoadTranslations("common.phrases.txt");

    HookEvent("player_death", OnStopNyan);
    HookEvent("player_spawn", OnStopNyan);
    HookEvent("round_end", OnRoundEnd);
}

public OnMapStart()
{
    AddFileToDownloadsTable("sound/nyan/nyan_3.wav");
    AddFileToDownloadsTable("materials/sprites/trails/mat_nyan.vtf");
    AddFileToDownloadsTable("materials/sprites/trails/mat_nyan.vmt");

    PrecacheSound("nyan/nyan_3.wav");
}

public OnClientDisconnect(client)
{
    StopNyan(client);
}

public OnStopNyan(Handle:event, const String:name[], bool:db)
{
    StopNyan(GetClientOfUserId(GetEventInt(event, "userid")));
}

public OnRoundEnd(Handle:event, const String:name[], bool:db)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            StopNyan(i);
    }
}

public Action:Command_Nyan(client, args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_nyan <target> [0/1]");
        return Plugin_Handled;
    }

    new toggle = -1;
    if (args > 1)
    {
        decl String:sToggle[3];
        GetCmdArg(2, sToggle, sizeof(sToggle));

        toggle = StringToInt(sToggle);
    }

    decl String:target[MAX_NAME_LENGTH];
    GetCmdArg(1, target, sizeof(target));

    decl matching[MAXPLAYERS];
    decl String:target_name[MAX_NAME_LENGTH];
    new bool:tn_is_ml;

    new found = ProcessTargetString(target, client,
                                    matching, MAXPLAYERS,
                                    COMMAND_FILTER_ALIVE,
                                    target_name, sizeof(target_name),
                                    tn_is_ml);

    if (found < 1)
    {
        ReplyToCommand(client, "[SM]: No targets found");
        return Plugin_Handled;
    }

    for (new i = 0; i < found; i++)
    {
        new t_client = matching[i];
        new bool:on;

        if (toggle == -1)
            on = (hNyanTimers[t_client] == INVALID_HANDLE)

        else
            on = toggle ? true : false;

        if (on)
        {
            if (hNyanTimers[t_client] != INVALID_HANDLE)
                continue;

            StartNyan(t_client);
        }

        else
            StopNyan(t_client);
    }

    ShowActivity2(client, "[SM] ", "Toggled nyan cat on %s", target_name);
    return Plugin_Handled;
}

public Action:Timer_PlayNyan(Handle:timer, any:client)
{
    EmitSoundToAll("nyan/nyan_3.wav", client);
    return Plugin_Continue;
}

stock StartNyan(client)
{
    StopNyan(client);

    decl Float:origin[3];
    decl String:parentname[64];

    PrecacheModel("materials/sprites/trails/mat_nyan.vmt");

    Format(parentname, sizeof(parentname), "nyan_%d", GetClientUserId(client));
    DispatchKeyValue(client, "targetname", parentname);

    new index = CreateEntityByName("env_spritetrail");
    SetEntPropFloat(index, Prop_Send, "m_flTextureRes", 0.05);

    DispatchKeyValue(index, "parentname", parentname);
    DispatchKeyValue(index, "renderamt", "255");
    DispatchKeyValue(index, "rendercolor", "255 255 255 255");
    DispatchKeyValue(index, "spritename", "materials/sprites/trails/mat_nyan.vmt");
    DispatchKeyValue(index, "lifetime", TRAILS_LIFETIME);
    DispatchKeyValue(index, "startwidth", TRAILS_START_WIDTH);
    DispatchKeyValue(index, "endwidth", TRAILS_END_WIDTH);
    DispatchKeyValue(index, "rendermode", "0");

    DispatchSpawn(index);
    iTrailEntities[client] = index;

    GetClientAbsOrigin(client, origin);
    origin[2] += 5.0;

    TeleportEntity(index, origin, NULL_VECTOR, NULL_VECTOR);
    SetVariantString(parentname);
    AcceptEntityInput(index, "SetParent", index, index);

    hNyanTimers[client] = CreateTimer(SOUND_LENGTH,
                                      Timer_PlayNyan,
                                      client,
                                      TIMER_REPEAT);

    SetEntityMoveType(client, MOVETYPE_NOCLIP);
    EmitSoundToAll("nyan/nyan_3.wav", client);
}

stock StopNyan(client)
{
    if (iTrailEntities[client] != -1 && IsValidEntity(iTrailEntities[client]))
    {
        decl String:classname[MAX_NAME_LENGTH];
        GetEntityClassname(iTrailEntities[client], classname, sizeof(classname));

        if (StrEqual(classname, "env_spritetrail"))
            AcceptEntityInput(iTrailEntities[client], "kill");

        iTrailEntities[client] = -1;
    }

    if (hNyanTimers[client] != INVALID_HANDLE)
    {
        CloseHandle(hNyanTimers[client]);
        hNyanTimers[client] = INVALID_HANDLE;

        SetEntityMoveType(client, MOVETYPE_WALK);
    }
}

