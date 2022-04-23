
new g_iActiveM4M;
new g_iPlayingM4MClip[MAXPLAYERS + 1];

new bool:g_bPlayingM4M[MAXPLAYERS + 1];
new String:g_sPlayerM4MWeapon[MAXPLAYERS + 1][MAX_NAME_LENGTH];

/* ----- Events ----- */


public M4M_OnLRStart(t, ct, const String:arg[])
{
    PrintToChatAll("%s The rules of the game are simple. Shoot the other player without going over the line", MSG_PREFIX);
    TeleportToS4S(t, ct);

    SetEntityHealth(t, 100);
    SetEntityHealth(ct, 100);

    g_bPlayingM4M[t] = true;
    g_bPlayingM4M[ct] = true;

    StripWeps(t, false);
    StripWeps(ct, false);

    Format(g_sPlayerM4MWeapon[t], MAX_NAME_LENGTH, arg);
    Format(g_sPlayerM4MWeapon[ct], MAX_NAME_LENGTH, arg);

    new random = GetRandomInt(0, 1) ? t : ct;
    new index = GivePlayerItem(random, arg);
    new clip = GetEntData(index, m_iClip1);

    PrintToChatAll("%s Randomly selected \x03%N\x04 to go first for \x05Mag-4-Mag",
                   MSG_PREFIX, random);

    g_iPlayingM4MClip[t] = clip;
    g_iPlayingM4MClip[ct] = clip;

    SetEntData(random, m_iAmmo +
               GetEntProp(index, Prop_Send, "m_iPrimaryAmmoType") * 4,
               0, _, true);

    g_iActiveM4M++;
    if (g_iActiveM4M == 1)
        HookEvent("weapon_fire", M4M_OnWeaponFire);
}

public M4M_OnLREnd(t, ct)
{
    g_iActiveM4M--;
    if (g_iActiveM4M <= 0)
        UnhookEvent("weapon_fire", M4M_OnWeaponFire);

    g_bPlayingM4M[t] = false;
    g_bPlayingM4M[ct] = false;

    if (IsClientInGame(t) && JB_IsPlayerAlive(t))
        StripWeps(t);

    if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
        StripWeps(ct);
}

public M4M_OnWeaponFire(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new lr_index = GetIndex(client);

    if (lr_index == -1 || !g_bPlayingM4M[client])
        return;

    if (GetEntData(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), m_iClip1) > 1)
        return;

    new other = GetArrayCell(GetClientTeam(client) == TEAM_PRISONERS ? g_hLRCTs : g_hLRTs, lr_index);

    StripWeps(other, false);
    CreateTimer(0.0, Timer_StripWeps_NoKnife, client);

    new index = GivePlayerItem(other, g_sPlayerM4MWeapon[other]);

    SetEntData(index, m_iClip1, g_iPlayingM4MClip[other]);
    SetEntData(other, m_iAmmo +
               GetEntProp(index, Prop_Send, "m_iPrimaryAmmoType") * 4,
               0, _, true);

    PrintToChatAll("%s \x03%N\x04 has depleted their magazine!", MSG_PREFIX, client);
}
