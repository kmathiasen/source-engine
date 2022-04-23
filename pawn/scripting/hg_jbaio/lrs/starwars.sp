
new g_iSWCount;
new String:g_sSWArg[MAXPLAYERS + 1][MAX_NAME_LENGTH];

/* ----- Events ----- */


public SW_OnLRStart(t, ct, const String:arg[])
{
    CountDownLR(t, ct, 3, SW_OnLRCountedDown);

    Format(g_sSWArg[t], MAX_NAME_LENGTH, arg);
    Format(g_sSWArg[ct], MAX_NAME_LENGTH, arg);

    if (++g_iSWCount == 1)
        HookEvent("bullet_impact", SW_OnBulletImpact);
}

public SW_OnLREnd(t, ct)
{
    if (--g_iSWCount == 0)
        UnhookEvent("bullet_impact", SW_OnBulletImpact);
}

public SW_OnBulletImpact(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsInLR(client, "Star Wars"))
    {
        decl Float:impact[3];
        decl Float:origin[3];

        impact[0] = GetEventFloat(event, "x");
        impact[1] = GetEventFloat(event, "y");
        impact[2] = GetEventFloat(event, "z");

        GetClientAbsOrigin(client, origin);
        origin[2] += 45.0;

        new x_mult = impact[0] < origin[0] ? -1 : 1;
        new y_mult = impact[1] < origin[1] ? -1 : 1;
        new z_mult = impact[2] < origin[2] ? -1 : 1;

        impact[0] += x_mult * 6.0;
        origin[0] += x_mult * 3.0;

        impact[1] += y_mult * 6.0;
        origin[1] += y_mult * 3.0;

        impact[2] += z_mult * 6.0;
        origin[2] += z_mult * 3.0;

        TE_SetupBeamPoints(origin, impact,
                           g_iSpriteBeam, g_iSpriteRing,
                           1, 1, 0.3, 1.0, 10.0, 0, 1.0,
                           g_iLRTeamColors[GetClientTeam(client) - 2], 100);

        TE_SendToAll();
    }
}

/* ----- Callbacks ----- */


public SW_OnLRCountedDown(t, ct)
{
    GivePlayerItem(t, "weapon_knife");
    GivePlayerItem(ct, "weapon_knife");

    new t_wep = GivePlayerItem(t, g_sSWArg[t]);
    new ct_wep = GivePlayerItem(ct, g_sSWArg[t]);

    // debug
    if (t_wep < 0)
        LogError("Star wars fucked up. g_sSWArg[t] = %s", g_sSWArg[t]);

    SetEntData(t_wep, m_iClip1, 1024);
    SetEntData(ct_wep, m_iClip1, 1024);

    SetEntData(t, m_iAmmo +
               GetEntProp(t_wep, Prop_Send, "m_iPrimaryAmmoType") * 4,
               1024, _, true);

    SetEntData(ct, m_iAmmo +
               GetEntProp(ct_wep, Prop_Send, "m_iPrimaryAmmoType") * 4,
               1024, _, true);
}
