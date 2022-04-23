
/* ----- Events ----- */


public DB_OnLRStart(t, ct, const String:arg[])
{
    new Float:gravity = GetConVarFloat(g_hCvLrDodgeballGravity);

    StripWeps(t, false);
    StripWeps(ct, false);

    SetEntityHealth(t, 1);
    SetEntityHealth(ct, 1);

    SetEntityGravity(t, gravity);
    SetEntityGravity(ct, gravity);

    SetEntProp(t, Prop_Send, "m_ArmorValue", 0);
    SetEntProp(ct, Prop_Send, "m_ArmorValue", 0);

    SetEntData(t, m_CollisionGroup, 5, 4, true);
    SetEntData(ct, m_CollisionGroup, 5, 4, true);

    TeleportToS4S(t, ct);

    GivePlayerFlashbang(t);
    GivePlayerFlashbang(ct);
}

public DB_OnLREnd(t, ct)
{
    if (IsClientInGame(t) && JB_IsPlayerAlive(t))
    {
        SetEntityGravity(t, 1.0);
        SetEntityHealth(t, 100);
        SetEntData(t, m_CollisionGroup, 2, 4, true);
    }

    if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
    {
        SetEntityGravity(ct, 1.0);
        SetEntityHealth(ct, 100);
        SetEntData(ct, m_CollisionGroup, 2, 4, true);
    }
}

stock DB_OnEntityCreated(entity, const String:classname[])
{
    if (g_iEndGame == ENDGAME_LR && StrEqual(classname, "flashbang_projectile"))
        SDKHook(entity, SDKHook_Spawn, DB_OnEntitySpawned);
}

public DB_OnEntitySpawned(entity)
{
    new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if (IsInLR(client, "Dodgeball"))
    {
        CreateTimer(0.0, Timer_RemoveThinkTick, entity, TIMER_FLAG_NO_MAPCHANGE);
        SetEntData(entity, m_CollisionGroup, 5, 4, true);
    }
}

public Action:Timer_RemoveThinkTick(Handle:timer, any:entity)
{
    SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
    CreateTimer(GetConVarFloat(g_hCvLrFlashbangGiveDelay),
                Timer_RemoveFlashbang,
                entity, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_RemoveFlashbang(Handle:timer, any:entity)
{
    if (IsValidEntity(entity))
    {
        decl String:classname[MAX_NAME_LENGTH];
        GetEntityClassname(entity, classname, sizeof(classname));

        if (!StrEqual(classname, "flashbang_projectile"))
            return;

        new client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
        AcceptEntityInput(entity, "Kill");

        GivePlayerFlashbang(client);
    }
}

/* ----- Functions ----- */


stock GivePlayerFlashbang(client)
{
    // Remove old FB.
    new wepid = GetPlayerWeaponSlot(client, WEPSLOT_NADE);
    if (wepid != -1)
    {
        RemovePlayerItem(client, wepid);
        RemoveEdict(wepid);
    }

    // Give new FB.
    GivePlayerItem(client, "weapon_flashbang");
}
