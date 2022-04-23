
new g_iCFPartner[MAXPLAYERS + 1];
new Handle:g_hCFTrackers[MAXPLAYERS + 1];

/* ----- Events ----- */

public CF_OnLRStart(t, ct, const String:arg[])
{
    g_hCFTrackers[t] = CreateTimer(0.1, Timer_CFCheckWon, t, TIMER_REPEAT);
    g_hCFTrackers[ct] = CreateTimer(0.1, Timer_CFCheckWon, ct, TIMER_REPEAT);

    g_iCFPartner[t] = ct;
    g_iCFPartner[ct] = t;

    SetEntityGravity(t, 0.95);
    SetEntityGravity(ct, 0.95);

    SetEntData(t, m_CollisionGroup, 5, 4, true);
    SetEntData(ct, m_CollisionGroup, 5, 4, true);
}
public CF_OnLREnd(t, ct)
{
    if (IsClientInGame(t) && JB_IsPlayerAlive(t))
    {
        SetEntityGravity(t, 1.0);
        SetEntData(t, m_CollisionGroup, 2, 4, true);
    }

    if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
    {
        SetEntityGravity(ct, 1.0);
        SetEntData(ct, m_CollisionGroup, 2, 4, true);
    }

    if (g_hCFTrackers[t] != INVALID_HANDLE)
        CloseHandle(g_hCFTrackers[t]);
    g_hCFTrackers[t] = INVALID_HANDLE;

    if (g_hCFTrackers[ct] != INVALID_HANDLE)
        CloseHandle(g_hCFTrackers[ct]);
    g_hCFTrackers[ct] = INVALID_HANDLE;
}


/* ----- Timers ----- */

public Action:Timer_CFCheckWon(Handle:Timer, any:client)
{
    new on = GetEntDataEnt2(client, m_hGroundEntity);
    SetEntityGravity(client, 0.95);

    if (on == g_iCFPartner[client])
    {
        g_hCFTrackers[client] = INVALID_HANDLE;

        CF_OnLREnd(on, client);
        MakeWinner(client);

        return Plugin_Stop;
    }

    return Plugin_Continue;
}