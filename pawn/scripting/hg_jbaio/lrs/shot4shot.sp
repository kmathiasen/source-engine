
new g_iActiveS4S;
new g_iPlayerS4SSlot[MAXPLAYERS + 1];
new bool:g_bPlayingS4S[MAXPLAYERS + 1];
new String:g_sPlayerS4SWeapon[MAXPLAYERS + 1][MAX_NAME_LENGTH];

/* ----- Events ----- */


public S4S_OnLRStart(t, ct, const String:arg[])
{
    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_SaveClassData(t);
        TF2_SaveClassData(ct);
    }

    StripWeps(t, false);
    StripWeps(ct, false);

    PrintToChatAll("%s The rules of the game are simple. Shoot the other player without going over the line", MSG_PREFIX);
    TeleportToS4S(t, ct);

    g_bPlayingS4S[t] = true;
    g_bPlayingS4S[ct] = true;

    Format(g_sPlayerS4SWeapon[t], MAX_NAME_LENGTH, arg);
    Format(g_sPlayerS4SWeapon[ct], MAX_NAME_LENGTH, arg);

    new random = GetRandomInt(0, 1) ? t : ct;

    PrintToChatAll("%s Randomly selected \x03%N\x04 to go first for \x05Shot-4-Shot",
                   MSG_PREFIX, random);

    if (g_iGame == GAMETYPE_TF2)
    {
        for (new i = 0; i < 2; i++)
        {
            new client = i == 0 ? t : ct;

            if (StrEqual(arg, "pistol"))
            {
                TF2_SetPlayerClass(client, TFClass_Scout, true, false);
                TF2_GivePlayerWeapon(client, "tf_weapon_bat", TF2_BAT, WEPSLOT_KNIFE);

                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_scattergun", TF2_SCATTERGUN, WEPSLOT_PRIMARY), client, 0, 0);
                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_pistol", TF2_SCOUT_PISTOL, WEPSLOT_SECONDARY), client, 0, 0);

                g_iMaxPrimaryClip[client] = 6;
                g_iMaxPrimaryAmmo[client] = 32;

                g_iMaxSecondaryClip[client] = 12;
                g_iMaxSecondaryAmmo[client] = 36;

                g_iPlayerS4SSlot[client] = WEPSLOT_SECONDARY;
            }

            else if (StrEqual(arg, "huntsman"))
            {
                TF2_SetPlayerClass(client, TFClass_Sniper, true, false);
                TF2_GivePlayerWeapon(client, "tf_weapon_club", TF2_KUKRI, WEPSLOT_KNIFE);

                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_smg", TF2_SMG, WEPSLOT_SECONDARY), client, 0, 0);
                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_compound_bow", TF2_HUNTSMAN, WEPSLOT_PRIMARY), client, 0, 0);

                g_iMaxPrimaryClip[client] = 1;
                g_iMaxPrimaryAmmo[client] = 12;

                g_iMaxSecondaryClip[client] = 25;
                g_iMaxSecondaryAmmo[client] = 75;

                g_iPlayerS4SSlot[client] = WEPSLOT_PRIMARY;
            }

            TF2_SetProperModel(client);
            SetEntityHealth(client, TF2_GetMaxHealth(client));
        }

        new wepid = GetPlayerWeaponSlot(random, g_iPlayerS4SSlot[random]);

        SetWeaponAmmo(wepid, random, 1, -1);
        EquipPlayerWeapon(random, wepid);
    }

    else
    {
        SetEntityHealth(t, 100);
        SetEntityHealth(ct, 100);

        new index = GivePlayerItem(random, arg);

        SetEntData(index, m_iClip1, 1);
        SetEntData(random, m_iAmmo +
                   GetEntProp(index, Prop_Send, "m_iPrimaryAmmoType") * 4,
                   0, _, true);

        if (++g_iActiveS4S == 1)
            HookEvent("weapon_fire", S4S_OnWeaponFire);
    }
}

public S4S_OnLREnd(t, ct)
{
    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_LoadClassData(t);
        TF2_LoadClassData(ct);
    }

    if (--g_iActiveS4S <= 0 && g_iGame != GAMETYPE_TF2)
        UnhookEvent("weapon_fire", S4S_OnWeaponFire);

    g_bPlayingS4S[t] = false;
    g_bPlayingS4S[ct] = false;

    if (IsClientInGame(t) && JB_IsPlayerAlive(t))
        StripWeps(t);

    if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
        StripWeps(ct);
}

stock S4S_TF2_OnWeaponFire(client, weapon)
{
    new lr_index = GetIndex(client);

    if (lr_index == -1 || !g_bPlayingS4S[client])
        return;

    new desired_weapon = GetPlayerWeaponSlot(client, g_iPlayerS4SSlot[client]);

    if (desired_weapon == weapon)
    {
        new other = GetArrayCell(GetClientTeam(client) == TEAM_PRISONERS ? g_hLRCTs : g_hLRTs, lr_index);
        new wepid = GetPlayerWeaponSlot(other, g_iPlayerS4SSlot[other]);

        if (StrEqual(g_sPlayerS4SWeapon[other], "huntsman"))
        {
            SetWeaponAmmo(wepid, other, 1, 1);
        }

        else
        {
            SetWeaponAmmo(wepid, other, 1, 0);
        }

        EquipPlayerWeapon(other, wepid);
        PrintToChatAll("%s \x03%N\x04 has taken their shot!", MSG_PREFIX, client);
    }
}

public S4S_OnWeaponFire(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new lr_index = GetIndex(client);

    if (lr_index == -1 || !g_bPlayingS4S[client])
        return;

    new other = GetArrayCell(GetClientTeam(client) == TEAM_PRISONERS ? g_hLRCTs : g_hLRTs, lr_index);

    StripWeps(other, false);
    CreateTimer(0.0, Timer_StripWeps_NoKnife, client);

    new index = GivePlayerItem(other, g_sPlayerS4SWeapon[other]);

    SetEntData(index, m_iClip1, 1);
    SetEntData(other, m_iAmmo +
               GetEntProp(index, Prop_Send, "m_iPrimaryAmmoType") * 4,
               0, _, true);

    PrintToChatAll("%s \x03%N\x04 has taken their shot!", MSG_PREFIX, client);
}
