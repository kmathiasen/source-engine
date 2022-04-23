
new String:g_sHSWeapon[MAXPLAYERS + 1][MAX_NAME_LENGTH];

/* ----- Events ----- */


public HS_OnLRStart(t, ct, const String:arg[])
{
    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_SaveClassData(t);
        TF2_SaveClassData(ct);
    }

    TeleportToS4S(t, ct);
    CountDownLR(t, ct, 3, HS_OnLRCountedDown);

    PrintToChatAll("%s Only headshots will do damage in this LR!", MSG_PREFIX);
    Format(g_sHSWeapon[t], MAX_NAME_LENGTH, arg);

    SDKHook(t, SDKHook_TraceAttack, HS_OnTraceAttack);
    SDKHook(ct, SDKHook_TraceAttack, HS_OnTraceAttack);

    if (StrEqual(arg, "huntsman"))
    {
        SDKHook(t, SDKHook_OnTakeDamage, HS_OnTakeDamage);
        SDKHook(ct, SDKHook_OnTakeDamage, HS_OnTakeDamage);
    }
}

public HS_OnLREnd(t, ct)
{
    if (IsClientInGame(t))
    {
        SDKUnhook(t, SDKHook_TraceAttack, HS_OnTraceAttack);
        SDKUnhook(t, SDKHook_OnTakeDamage, HS_OnTakeDamage);
    }

    if (IsClientInGame(ct))
    {
        SDKUnhook(ct, SDKHook_TraceAttack, HS_OnTraceAttack);
        SDKUnhook(ct, SDKHook_OnTakeDamage, HS_OnTakeDamage);
    }

    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_LoadClassData(t);
        TF2_LoadClassData(ct);
    }
}

public HS_OnLRCountedDown(t, ct)
{
    StripWeps(t);
    StripWeps(ct);

    if (g_iGame == GAMETYPE_TF2)
    {
        for (new i = 0; i < 2; i++)
        {
            new client = i == 0 ? t : ct;

            if (StrEqual(g_sHSWeapon[t], "pistol"))
            {
                TF2_SetPlayerClass(client, TFClass_Scout, true, false);
                TF2_GivePlayerWeapon(client, "tf_weapon_bat", TF2_BAT, WEPSLOT_KNIFE);

                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_scattergun", TF2_SCATTERGUN, WEPSLOT_PRIMARY), client, 0, 0);
                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_pistol", TF2_SCOUT_PISTOL, WEPSLOT_SECONDARY), client, 12, 120);

                g_iMaxPrimaryClip[client] = 6;
                g_iMaxPrimaryAmmo[client] = 32;

                g_iMaxSecondaryClip[client] = 12;
                g_iMaxSecondaryAmmo[client] = 36;
            }

            else if (StrEqual(g_sHSWeapon[t], "minigun"))
            {
                TF2_SetPlayerClass(client, TFClass_Heavy, true, false);
                TF2_GivePlayerWeapon(client, "tf_weapon_fists", TF2_APOCO_FISTS, WEPSLOT_KNIFE);

                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_shotgun", TF2_SHOTGUN, WEPSLOT_SECONDARY), client, 0, 0);
                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_minigun", TF2_BRASS_BEAST, WEPSLOT_PRIMARY), client, -1, 800);

                g_iMaxPrimaryClip[client] = -1;
                g_iMaxPrimaryAmmo[client] = 200;

                g_iMaxSecondaryClip[client] = 6;
                g_iMaxSecondaryAmmo[client] = 32;
            }

            else if (StrEqual(g_sHSWeapon[t], "huntsman"))
            {
                TF2_SetPlayerClass(client, TFClass_Sniper, true, false);
                TF2_GivePlayerWeapon(client, "tf_weapon_club", TF2_KUKRI, WEPSLOT_KNIFE);

                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_smg", TF2_SMG, WEPSLOT_SECONDARY), client, 0, 0);
                SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_compound_bow", TF2_HUNTSMAN, WEPSLOT_PRIMARY), client, 1, 60);

                g_iMaxPrimaryClip[client] = 1;
                g_iMaxPrimaryAmmo[client] = 12;

                g_iMaxSecondaryClip[client] = 25;
                g_iMaxSecondaryAmmo[client] = 75;
            }

            TF2_SetProperModel(client);
            SetEntityHealth(client, TF2_GetMaxHealth(client));
        }
    }

    else
    {
        GivePlayerItem(t, g_sHSWeapon[t]);
        GivePlayerItem(ct, g_sHSWeapon[t]);
    }
}

public Action:HS_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
    if (damagecustom == TF_CUSTOM_HEADSHOT ||
        damagecustom == TF_CUSTOM_PENETRATE_HEADSHOT ||
        damagecustom == TF_CUSTOM_HEADSHOT_DECAPITATION)
        return Plugin_Continue;

    PrintToChat(attacker,
                "%s So close! You hit \x03%N\x04 but it wasn't a headshot",
                MSG_PREFIX, victim);

    return Plugin_Handled;
}

public Action:HS_OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if (hitgroup == 1)
        return Plugin_Continue;

    PrintToChat(attacker,
                "%s So close! You hit \x03%N\x04 but it wasn't a headshot",
                MSG_PREFIX, victim);

    return Plugin_Handled;
}
