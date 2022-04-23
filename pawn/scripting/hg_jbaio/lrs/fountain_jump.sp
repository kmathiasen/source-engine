
#define FOUNTAIN_RADIUS 74.0

new g_iTicksOnFountain[MAXPLAYERS + 1];
new Handle:g_hFJTrackers[MAXPLAYERS + 1];
new Float:g_fFountainCenter[3] = {165.0, -2687.5, 124.0};

/* ----- Events ----- */


public FJ_OnLRStart(t, ct, const String:arg[])
{
    Tele_DoClient(0, t, "Top of Solitary", false);
    Tele_DoClient(0, ct, "Top of Solitary", false);

    if (g_iGame == GAMETYPE_TF2)
    {
        SetEntProp(t, Prop_Send, "m_CollisionGroup", 2);
        SetEntProp(ct, Prop_Send, "m_CollisionGroup", 2);
    }

    CountDownLR(t, ct, 3, FJ_OnLRCountedDown);
    PrintToChatAll("%s First person to get on second tier of fountain wins!", MSG_PREFIX);
}

public FJ_OnLRCountedDown(t, ct)
{
    StripWeps(t, false);
    StripWeps(ct, false);

    g_iTicksOnFountain[t] = 0;
    g_iTicksOnFountain[ct] = 0;

    new juan = GetRandomInt(0, 1) ? t : ct;
    new eother = juan == t ? ct : t;

    g_hFJTrackers[juan] = CreateTimer(0.01, Timer_FJCheckWinner, juan, TIMER_REPEAT);
    g_hFJTrackers[eother] = CreateTimer(0.01, Timer_FJCheckWinner, eother, TIMER_REPEAT);
}

public FJ_OnLREnd(t, ct)
{
    if (g_hFJTrackers[t] != INVALID_HANDLE)
        CloseHandle(g_hFJTrackers[t]);

    if (g_hFJTrackers[ct] != INVALID_HANDLE)
        CloseHandle(g_hFJTrackers[ct]);

    g_hFJTrackers[t] = INVALID_HANDLE;
    g_hFJTrackers[ct] = INVALID_HANDLE;

    if (g_iGame == GAMETYPE_TF2)
    {
        if (IsClientInGame(t) && JB_IsPlayerAlive(t))
            SetEntProp(t, Prop_Send, "m_CollisionGroup", 5);

        if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
            SetEntProp(ct, Prop_Send, "m_CollisionGroup", 5);
    }
}


/* ----- Timers ----- */


public Action:Timer_FJCheckWinner(Handle:timer, any:client)
{
    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    new Float:z_dist = origin[2] - g_fFountainCenter[2];
    if (z_dist < 10.0 && z_dist > -10.0 &&
        SquareRoot(Pow(origin[0] - g_fFountainCenter[0], 2.0) +
                   Pow(origin[1] - g_fFountainCenter[1], 2.0)) <= FOUNTAIN_RADIUS)
    {
        if (++g_iTicksOnFountain[client] > 4)
        {
            new partner = GetPartner(client);
            MakeWinner(client);

            CloseHandle(g_hFJTrackers[partner]);
            g_hFJTrackers[partner] = INVALID_HANDLE;

            g_hFJTrackers[client] = INVALID_HANDLE;
            return Plugin_Stop;
        }
    }

    else
        g_iTicksOnFountain[client] = 0;

    return Plugin_Continue;
}
