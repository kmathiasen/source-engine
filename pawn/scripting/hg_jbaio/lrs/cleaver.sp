
new g_iCleaverInUse;

/* ----- Events ----- */


public CLE_OnLRStart(t, ct, const String:arg[])
{
    TF2_SaveClassData(t);
    TF2_SaveClassData(ct);

    CLE_SetupPlayer(t);
    CLE_SetupPlayer(ct);

    if (g_iCleaverInUse)
        TeleportToS4S(t, ct);

    else
    {
        Tele_DoClient(0, t, "Roof 1", false);
        Tele_DoClient(0, ct, "Roof 2", false);
    }
}

stock CLE_SetupPlayer(client)
{
    TF2_SetPlayerClass(client, TFClass_Scout, true, false);
    TF2_SetProperModel(client);

    SetEntityHealth(client, TF2_GetMaxHealth(client));

    TF2_GivePlayerWeapon(client, "tf_weapon_scattergun", TF2_SCATTERGUN, WEPSLOT_PRIMARY);
    TF2_GivePlayerWeapon(client, "tf_weapon_cleaver", TF2_FLYING_GUILLOTINE, WEPSLOT_SECONDARY);
    TF2_GivePlayerWeapon(client, "tf_weapon_bat", TF2_BAT, WEPSLOT_KNIFE);

    SetWeaponAmmo(GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY), client, 0, 0);
    SetWeaponAmmo(GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY), client, -1, 99);
    
    g_iMaxPrimaryClip[client] = 6;
    g_iMaxPrimaryAmmo[client] = 32;

    g_iMaxSecondaryClip[client] = -1;
    g_iMaxSecondaryAmmo[client] = 1;
}

public CLE_OnLREnd(t, ct)
{
    if (g_iCleaverInUse == t)
        g_iCleaverInUse = 0;

    TF2_LoadClassData(t);
    TF2_LoadClassData(ct);
}

