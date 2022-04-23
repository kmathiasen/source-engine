
#define END_RADIUS 150.0

new bool:g_bInClimb[MAXPLAYERS + 1];

/* ----- Events ----- */


public Climb_OnLRStart(t, ct, const String:arg[])
{
    CountDownLR(t, ct, 3, Climb_OnCountedDown);

    SetEntProp(t, Prop_Data, "m_takedamage", 0, 1);
    SetEntProp(ct, Prop_Data, "m_takedamage", 0, 1);

    g_bInClimb[t] = true;
    g_bInClimb[ct] = true;

    Tele_DoClient(0, t, "Climb Bottom", false);
    Tele_DoClient(0, ct, "Climb Bottom", false);

    if (g_iGame == GAMETYPE_TF2)
    {
        SetEntProp(t, Prop_Send, "m_CollisionGroup", 2);
        SetEntProp(ct, Prop_Send, "m_CollisionGroup", 2);
    }
}

public Climb_OnLREnd(t, ct)
{
    g_bInClimb[t] = false;
    g_bInClimb[ct] = false;

    if (IsClientInGame(t) && JB_IsPlayerAlive(t))
    {
        SetEntProp(t, Prop_Data, "m_takedamage", 2, 1);

        if (g_iGame == GAMETYPE_TF2)
            SetEntProp(t, Prop_Send, "m_CollisionGroup", 5);
    }

    if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
    {
        SetEntProp(ct, Prop_Data, "m_takedamage", 2, 1);

        if (g_iGame == GAMETYPE_TF2)
            SetEntProp(ct, Prop_Send, "m_CollisionGroup", 5);
    }
}


/* ----- Callbacks ----- */


public Climb_OnCountedDown(t, ct)
{
    CreateTimer(0.033, Timer_CheckClimbWinner, t, TIMER_REPEAT);
    CreateTimer(0.033, Timer_CheckClimbWinner, ct, TIMER_REPEAT);

    CreateTimer(20.0, Timer_ClimbUnGodMode, t);
    CreateTimer(20.0, Timer_ClimbUnGodMode, ct);

    PrintToChat(t, "%s Better climb! You only have\x03 20\x04 seconds left of god mode!", MSG_PREFIX);
    PrintToChat(ct, "%s Better climb! You only have\x03 20\x04 seconds left of god mode!", MSG_PREFIX);
}

public Action:Timer_CheckClimbWinner(Handle:timer, any:client)
{
    if (!g_bInClimb[client])
        return Plugin_Stop;

    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    // They went on a ladder. Those cheating bastards D:
    if (GetEntityMoveType(client) == MOVETYPE_LADDER && origin[2] < -624)
    {
        Tele_DoClient(0, client, "Climb Bottom", false);
        PrintToChat(client, "%s Yo... That's cheating... Bitch.", MSG_PREFIX);

        return Plugin_Continue;
    }

    else if (!MapCoords_IsInRoomEz(client, "Climb"))
    {
        MakeWinner(client);

        g_bInClimb[client] = false;
        g_bInClimb[GetPartner(client)] = false;

        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public Action:Timer_ClimbUnGodMode(Handle:timer, any:client)
{
    if (JB_IsPlayerAlive(client))
        SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
}
