
#define END_RADIUS 150.0

new g_iRaceCount;
new Handle:g_hRaceLasers = INVALID_HANDLE;
new bool:g_bInRace[MAXPLAYERS + 1];

new Float:g_iRaceStart[3] = {-1958.0, -1751.0, 10.0};
new Float:g_iRaceEnd[3] = {-1954.0, -3612.0, 10.0};

/* ----- Events ----- */


public Race_OnLRStart(t, ct, const String:arg[])
{
    if (++g_iRaceCount == 1)
    {
        Timer_ShowRacePoints(INVALID_HANDLE, 0);
        g_hRaceLasers = CreateTimer(10.0, Timer_ShowRacePoints, _, TIMER_REPEAT);
    }

    CountDownLR(t, ct, 3, Race_OnCountedDown);

    SetEntProp(t, Prop_Data, "m_takedamage", 0, 1);
    SetEntProp(ct, Prop_Data, "m_takedamage", 0, 1);

    g_bInRace[t] = true;
    g_bInRace[ct] = true;

    TeleportEntity(t, g_iRaceStart, NULL_VECTOR, NULL_VECTOR);
    TeleportEntity(ct, g_iRaceStart, NULL_VECTOR, NULL_VECTOR);

    if (g_iGame == GAMETYPE_TF2)
    {
        SetEntProp(t, Prop_Send, "m_CollisionGroup", 2);
        SetEntProp(ct, Prop_Send, "m_CollisionGroup", 2);
    }
}

public Action:Timer_ShowRacePoints(Handle:timer, any:data)
{
    TE_SetupBeamRingPoint(g_iRaceStart,
                          END_RADIUS, END_RADIUS + 1,
                          g_iSpriteBeam, g_iSpriteRing,
                          0, 15, 10.0, 7.0, 0.0,
                          g_iColorGreen, 1, 0);

    TE_SendToAll();

    TE_SetupBeamRingPoint(g_iRaceEnd,
                          END_RADIUS, END_RADIUS + 1,
                          g_iSpriteBeam, g_iSpriteRing,
                          0, 15, 10.0, 7.0, 0.0,
                          g_iColorGreen, 1, 0);

    TE_SendToAll();
    return Plugin_Continue;
}

public Race_OnLREnd(t, ct)
{
    if (--g_iRaceCount == 0 && g_hRaceLasers != INVALID_HANDLE)
    {
        CloseHandle(g_hRaceLasers);
    }
    g_hRaceLasers = INVALID_HANDLE;

    g_bInRace[t] = false;
    g_bInRace[ct] = false;

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


public Race_OnCountedDown(t, ct)
{
    CreateTimer(0.033, Timer_CheckWinner, t, TIMER_REPEAT);
    CreateTimer(0.033, Timer_CheckWinner, ct, TIMER_REPEAT);

    CreateTimer(3.0, Timer_UnGodMode, t);
    CreateTimer(3.0, Timer_UnGodMode, ct);

    PrintToChat(t, "%s Better run! You only have\x03 3\x04 seconds left of god mode!", MSG_PREFIX);
    PrintToChat(ct, "%s Better run! You only have\x03 3\x04 seconds left of god mode!", MSG_PREFIX);
}

public Action:Timer_CheckWinner(Handle:timer, any:client)
{
    if (!g_bInRace[client])
        return Plugin_Stop;

    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    // They cheated. They're outside of hurdles
    if (!(origin[2] < 280.0 &&
        origin[0] > -2150.0 && origin[0] < -1730.0 &&
        origin[1] > -3700.0 && origin[1] < -1700.0))
    {
        new partner = GetPartner(client);
        MakeWinner(partner);

        PrintToChatAll("%s \x03%N\x04 has cheated in \x03race\x04 and has lost!", MSG_PREFIX, client);

        g_bInRace[client] = false;
        g_bInRace[partner] = false;

        return Plugin_Stop;
    }

    else if (SquareRoot(Pow(origin[0] - g_iRaceEnd[0], 2.0) +
                   Pow(origin[1] - g_iRaceEnd[1], 2.0)) <= (END_RADIUS / 2.0))
    {
        MakeWinner(client);

        g_bInRace[client] = false;
        g_bInRace[GetPartner(client)] = false;

        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public Action:Timer_UnGodMode(Handle:timer, any:client)
{
    if (JB_IsPlayerAlive(client))
        SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
}
