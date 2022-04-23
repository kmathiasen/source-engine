
new g_iFWCount;
new String:g_sFragWarsGrenade[MAXPLAYERS + 1][MAX_NAME_LENGTH];

/* ----- Events ----- */

public FW_OnLRStart(t, ct, const String:arg[])
{
    StripWeps(t, false);
    StripWeps(ct, false);

    GivePlayerItem(t, arg);
    GivePlayerItem(ct, arg);

    Format(g_sFragWarsGrenade[t], MAX_NAME_LENGTH, arg);
    Format(g_sFragWarsGrenade[ct], MAX_NAME_LENGTH, arg);

    SetEntityHealth(t, 100);
    SetEntityHealth(ct, 100);

    SetEntProp(t, Prop_Send, "m_ArmorValue", 0);
    SetEntProp(ct, Prop_Send, "m_ArmorValue", 0);

    Tele_DoClient(0, t, "Roof 1", false);
    Tele_DoClient(0, ct, "Roof 2", false);

    PrintToChatAll("%s Players may not leave the roof for \x03Frag Wars\x04", MSG_PREFIX);

    if (++g_iFWCount == 1)
        HookEvent("weapon_fire", FW_OnWeaponFire);
}

public FW_OnLREnd(t, ct)
{
    if (--g_iFWCount == 0)
        UnhookEvent("weapon_fire", FW_OnWeaponFire);
}

public FW_OnWeaponFire(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsInLR(client, "Frag Wars") ||
        IsInLR(client, "Molotov Cockwar"))
    {
        decl Float:origin[3];
        GetClientAbsOrigin(client, origin);

        if (origin[2] < 200.0)
        {
            PrintToChatAll("%s \x03%N\x04 cheated in \x03Grenade Wars\x04 and was slayed",
                           MSG_PREFIX, client);

            SlapPlayer(client, GetClientHealth(client) + 101);
            return;
        }

        decl String:weapon[MAX_NAME_LENGTH];
        GetEventString(event, "weapon", weapon, sizeof(weapon));

        if (StrEqual(weapon, g_sFragWarsGrenade[client][7]))
            CreateTimer(1.5, Timer_GiveGrenade, GetClientUserId(client));
    }
}


/* ----- Callbacks ----- */


public Action:Timer_GiveGrenade(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (client)
    {
        new index;
        while ((index = GetPlayerWeaponSlot(client, WEPSLOT_NADE)) != -1)
        {
            RemovePlayerItem(client, index);
            AcceptEntityInput(index, "kill");
        }

        GivePlayerItem(client, g_sFragWarsGrenade[client]);
    }
}
