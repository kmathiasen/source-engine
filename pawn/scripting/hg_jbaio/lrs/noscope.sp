
new g_iNSLRCount;
new bool:g_bBlockScope[MAXPLAYERS + 1];

/* ----- Events ----- */


public NS_OnLRStart(t, ct, const String:arg[])
{
    TeleportToS4S(t, ct);
    g_iNSLRCount++;

    if (g_iNSLRCount == 1)
        HookEvent("weapon_zoom", NS_OnWeaponZoom, EventHookMode_Pre);

    g_bBlockScope[t] = true;
    g_bBlockScope[ct] = true;

    StripWeps(t);
    StripWeps(ct);

    GivePlayerItem(t, arg);
    GivePlayerItem(ct, arg);

    SetEntityHealth(t, 100);
    SetEntityHealth(ct, 100);
}

public NS_OnLREnd(t, ct)
{
    if (--g_iNSLRCount == 0)
        UnhookEvent("weapon_zoom", NS_OnWeaponZoom, EventHookMode_Pre);

    g_bBlockScope[t] = false;
    g_bBlockScope[ct] = false;
}

public Action:NS_OnWeaponZoom(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_bBlockScope[client])
    {
        decl String:wep[MAX_NAME_LENGTH];
        GetClientWeapon(client, wep, sizeof(wep));

        RemovePlayerItem(client, GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"));
        GivePlayerItem(client, wep);

        PrintToChat(client, "%s That's not nice, cheating and all :(", MSG_PREFIX);
        SetEntData(client, m_iFOV, 0, 4, true);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}
