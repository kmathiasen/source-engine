
new g_iHPCount;
new g_iHPGun[MAXPLAYERS + 1];

new Handle:g_hHPKillTimer[MAXPLAYERS + 1];

/* ----- Events ----- */


public HP_OnLRStart(t, ct, const String:arg[])
{
    Tele_DoClient(0, t, "HP 1", false);
    Tele_DoClient(0, ct, "HP 2", false);

    PrintToChatAll("%s The last person to have touched the hot potato dies!", MSG_PREFIX);
    CountDownLR(t, ct, 3, HP_OnCountedDown);
}

public HP_OnCountedDown(t, ct)
{
    StripWeps(t, false);
    StripWeps(ct, false);

    CreateDeagle(GetRandomInt(0, 1) ? t : ct);

    g_hHPKillTimer[t] = CreateTimer(GetRandomFloat(10.0, 20.0), HP_KillHolder, t);

    if (++g_iHPCount == 1)
        HookEvent("item_pickup", HP_OnItemPickup);
}

public HP_OnLREnd(t, ct)
{
    g_iHPGun[t] = -1;
    g_iHPGun[ct] = -1;

    if (g_hHPKillTimer[t] != INVALID_HANDLE)
    {
        CloseHandle(g_hHPKillTimer[t]);
        g_hHPKillTimer[t] = INVALID_HANDLE;
    }

    if (--g_iHPCount == 0)
        UnhookEvent("item_pickup", HP_OnItemPickup);

    if (JB_IsPlayerAlive(t))
        GivePlayerItem(t, "weapon_knife");

    if (JB_IsPlayerAlive(ct))
        GivePlayerItem(ct, "weapon_knife");
}

public Action:HP_OnItemPickup(Handle:event, const String:name[], bool:db)
{
    decl String:wep[MAX_NAME_LENGTH];
    GetEventString(event, "item", wep, sizeof(wep));

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new deag = GetPlayerWeaponSlot(client, 1);

    if (StrEqual(wep, "deagle"))
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (g_iHPGun[i] == deag)
            {
                new partner = GetPartner(client);
                SetWeaponAmmo(deag, client, 0, 0);

                if (partner != i && client != i)
                {
                    PrintToChatAll("%s \x03%N\x04 interefered with \x03%N\x04's \x05Hot Potato",
                                   MSG_PREFIX, client, i);

                    SlapPlayer(client, GetClientHealth(client) + 101);

                    AcceptEntityInput(deag, "kill");
                    CreateDeagle(i);
                }

                else
                {
                    SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.9);
                    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.25);

                    g_iHPGun[i] = -1;
                    g_iHPGun[client] = deag;
                }

                break;
            }
        }
    }

    // Make sure they didn't pick up a secondary weapon, in order to glitch the game
    else if (deag > 0)
    {
        PrintToChat(client, "%s That's not a potato...", MSG_PREFIX);

        RemovePlayerItem(client, deag);
        AcceptEntityInput(deag, "kill");
    }
}


/* ----- Functions ----- */


stock CreateDeagle(client)
{
    new partner = GetPartner(client);
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.25);

    if (partner > 0 && IsClientInGame(partner))
        SetEntPropFloat(partner, Prop_Data, "m_flLaggedMovementValue", 0.9);

    g_iHPGun[client] = GivePlayerItem(client, "weapon_deagle");
    SetWeaponAmmo(g_iHPGun[client], client, 0, 0);
}

/* ----- Callbacks ----- */


public Action:HP_KillHolder(Handle:timer, any:t)
{
    g_hHPKillTimer[t] = INVALID_HANDLE;
    new partner = GetPartner(t);

    if (g_iHPGun[t] > 0)
    {
        PrintToChatAll("%s Oh No! \x03%N\x04 died from the \x05Hot Potato",
                       MSG_PREFIX, t);

        SlapPlayer(t, GetClientHealth(t) + 101);
    }

    else
    {
        PrintToChatAll("%s Oh No! \x03%N\x04 died from the \x05Hot Potato",
                       MSG_PREFIX, partner);

        SlapPlayer(partner, GetClientHealth(partner) + 101);
    }
}
