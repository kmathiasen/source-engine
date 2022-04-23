// Credit to <eVa>Dog for the flame thrower

new g_iCZLRCount = 0;
new bool:g_bCZLoaded = false;
new Handle:g_hCZEnforeMoveType = INVALID_HANDLE;
new Float:g_fLastFlame[MAXPLAYERS + 1];

/* ----- Events ----- */


public CZ_OnLRStart(t, ct, const String:arg[])
{
    CountDownLR(t, ct, 3, CZ_OnLRCountedDown);

    if (!g_bCZLoaded)
    {
        RegConsoleCmd("drop", CZ_OnWeaponDrop);
        g_bCZLoaded = true;
    }

    if (++g_iCZLRCount == 1)
    {
        HookEvent("weapon_fire_on_empty", CZ_WeaponFireOnEmpty);
        g_hCZEnforeMoveType = CreateTimer(1.0, Timer_CZEnforceMoveType, _, TIMER_REPEAT);
    }
}

public CZ_OnLRCountedDown(t, ct)
{
    CZ_SetupPlayer(t);
    CZ_SetupPlayer(ct);
}

public CZ_OnLREnd(t, ct)
{
    if (--g_iCZLRCount == 0)
    {
        UnhookEvent("weapon_fire_on_empty", CZ_WeaponFireOnEmpty);

        CloseHandle(g_hCZEnforeMoveType);
        g_hCZEnforeMoveType = INVALID_HANDLE;
    }

    CZ_UnsetupPlayer(t);
    CZ_UnsetupPlayer(ct);
}

public Action:CZ_OnWeaponDrop(client, args)
{
    if (IsInLR(client, "Charizard"))
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action:CZ_WeaponFireOnEmpty(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsInLR(client, "Charizard") && GetEngineTime() - g_fLastFlame[client] >= 0.8)
    {
        DoFlame(client);
        g_fLastFlame[client] = GetEngineTime();
    }
}

public Action:Timer_CZEnforceMoveType(Handle:timer, any:args)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) &&
            JB_IsPlayerAlive(i) &&
            IsInLR(i, "Charizard") &&
            GetEntityMoveType(i) != MOVETYPE_NONE)
            SetEntityMoveType(i, MOVETYPE_FLY);
    }

    return Plugin_Continue;
}

/* ----- Functions ----- */

stock CZ_SetupPlayer(client)
{
    new iShotgun = GivePlayerItem(client, g_iGame == GAMETYPE_CSS ? "weapon_m3" : "weapon_nova");
    GivePlayerItem(client, "weapon_knife");

    SetWeaponAmmo(iShotgun, client, 0, 0);
    SetEntityMoveType(client, MOVETYPE_FLY);
}

stock CZ_UnsetupPlayer(client)
{
    if (IsClientInGame(client))
    {
        ExtinguishEntity(client);

        if (JB_IsPlayerAlive(client))
        {
            new iShotgun = GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY);
            if (iShotgun > 0)
                SetWeaponAmmo(iShotgun, client, 69, 666);

            UnfreezePlayer(client);
            SetEntityHealth(client, 100);
        }
    }
}

stock DoFlame(client)
{
    new Float:distance = 600.0;
    new Float:vAngles[3];
    new Float:vOrigin[3];
    new Float:aOrigin[3];
    new Float:EndPoint[3];
    new Float:AnglesVec[3];
    new Float:targetOrigin[3];
    new Float:pos[3];

    new String:tName[128];
    new String:bone[MAX_NAME_LENGTH];

    if (g_iGame == GAMETYPE_CSS)
        Format(bone, sizeof(bone), "forward");

    else
        Format(bone, sizeof(bone), "muzzle_flash");

    GetClientEyePosition(client, vOrigin);
    GetClientAbsOrigin(client, aOrigin);
    GetClientEyeAngles(client, vAngles);

    // A little routine developed by Sollie and Crimson to find the endpoint of a traceray
    // Very useful!
    GetAngleVectors(vAngles, AnglesVec, NULL_VECTOR, NULL_VECTOR);

    EndPoint[0] = vOrigin[0] + (AnglesVec[0]*distance);
    EndPoint[1] = vOrigin[1] + (AnglesVec[1]*distance);
    EndPoint[2] = vOrigin[2] + (AnglesVec[2]*distance);
                            
    new Handle:trace = TR_TraceRayFilterEx(vOrigin, EndPoint, MASK_SHOT, RayType_EndPoint, TraceEntityFilterPlayer, client)	;

    // Ident the player
    Format(tName, sizeof(tName), "target%i", client);
    DispatchKeyValue(client, "targetname", tName);

    EmitSoundToClient(client, "weapons/rpg/rocketfire1.wav", _, _, _, _, 0.7);

    // Create the Flame
    new String:flame_name[128];
    Format(flame_name, sizeof(flame_name), "Flame%i", client);
    new flame = CreateEntityByName("env_steam");
    DispatchKeyValue(flame,"targetname", flame_name);
    DispatchKeyValue(flame, "parentname", tName);
    DispatchKeyValue(flame,"SpawnFlags", "1");
    DispatchKeyValue(flame,"Type", "0");
    DispatchKeyValue(flame,"InitialState", "1");
    DispatchKeyValue(flame,"Spreadspeed", "10");
    DispatchKeyValue(flame,"Speed", "800");
    DispatchKeyValue(flame,"Startsize", "10");
    DispatchKeyValue(flame,"EndSize", "250");
    DispatchKeyValue(flame,"Rate", "15");
    DispatchKeyValue(flame,"JetLength", "400");
    DispatchKeyValue(flame,"RenderColor", "180 71 8");
    DispatchKeyValue(flame,"RenderAmt", "180");
    DispatchSpawn(flame);
    TeleportEntity(flame, aOrigin, AnglesVec, NULL_VECTOR);
    SetVariantString(tName);
    AcceptEntityInput(flame, "SetParent", flame, flame, 0);

    SetVariantString(bone);

    AcceptEntityInput(flame, "SetParentAttachment", flame, flame, 0);
    AcceptEntityInput(flame, "TurnOn");

    // Create the Heat Plasma
    new String:flame_name2[128];
    Format(flame_name2, sizeof(flame_name2), "Flame2%i", client);
    new flame2 = CreateEntityByName("env_steam");
    DispatchKeyValue(flame2,"targetname", flame_name2);
    DispatchKeyValue(flame2, "parentname", tName);
    DispatchKeyValue(flame2,"SpawnFlags", "1");
    DispatchKeyValue(flame2,"Type", "1");
    DispatchKeyValue(flame2,"InitialState", "1");
    DispatchKeyValue(flame2,"Spreadspeed", "10");
    DispatchKeyValue(flame2,"Speed", "600");
    DispatchKeyValue(flame2,"Startsize", "50");
    DispatchKeyValue(flame2,"EndSize", "400");
    DispatchKeyValue(flame2,"Rate", "10");
    DispatchKeyValue(flame2,"JetLength", "500");
    DispatchSpawn(flame2);
    TeleportEntity(flame2, aOrigin, AnglesVec, NULL_VECTOR);
    SetVariantString(tName);
    AcceptEntityInput(flame2, "SetParent", flame2, flame2, 0);

    SetVariantString(bone);

    AcceptEntityInput(flame2, "SetParentAttachment", flame2, flame2, 0);
    AcceptEntityInput(flame2, "TurnOn");

    new Handle:flamedata = CreateDataPack();
    CreateTimer(1.0, KillFlame, flamedata);
    WritePackCell(flamedata, flame);
    WritePackCell(flamedata, flame2);

    if(TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
    }
    CloseHandle(trace);

    for (new i = 1; i <= GetMaxClients(); i++)
    {
        if (i == client)
            continue;

        if (IsClientInGame(i) && JB_IsPlayerAlive(i))
        {
            if (GetClientTeam(i) == GetClientTeam(client))
                continue;
                
            GetClientAbsOrigin(i, targetOrigin);
            
            if ((GetVectorDistance(targetOrigin, pos) < 200) && 
                (GetVectorDistance(targetOrigin, vOrigin) < 600) &&
                IsInLR(i, "Charizard"))
            {
                IgniteEntity(i, 5.0, false, 1.5, false);
                SlapPlayer(i, 5, false);
            }
        }
    }
}

public bool:TraceEntityFilterPlayer(entity, contentsMask, any:data)
{
    return data != entity;
} 

public Action:KillFlame(Handle:timer, Handle:flamedata)
{
    ResetPack(flamedata);
    new ent1 = ReadPackCell(flamedata);
    new ent2 = ReadPackCell(flamedata);
    CloseHandle(flamedata);
    
    new String:classname[256];
    
    if (IsValidEntity(ent1))
    {
        AcceptEntityInput(ent1, "TurnOff");
        GetEdictClassname(ent1, classname, sizeof(classname));
        if (StrEqual(classname, "env_steam", false))
        {
            RemoveEdict(ent1);
        }
    }
    
    if (IsValidEntity(ent2))
    {
        AcceptEntityInput(ent2, "TurnOff");
        GetEdictClassname(ent2, classname, sizeof(classname));
        if (StrEqual(classname, "env_steam", false))
        {
            RemoveEdict(ent2);
        }
    }
}