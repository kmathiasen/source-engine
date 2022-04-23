
/* ----- Events ----- */


public RBL_OnLRStart(t, ct, const String:arg[])
{
    // make them permanently a rebel
    g_bIsInvisible[t] = true;

    SetEntityRenderMode(t, RENDER_TRANSCOLOR);
    SetEntityRenderColor(t, 255, 0, 0, 255);

    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_SetPlayerClass(t, TFClass_Heavy, true, false);
        TF2_SetProperModel(t);

        SetEntityHealth(t, 555);

        TF2_GivePlayerWeapon(t, "tf_weapon_minigun", TF2_BRASS_BEAST, WEPSLOT_PRIMARY);
        TF2_GivePlayerWeapon(t, "tf_weapon_shotgun", TF2_SHOTGUN, WEPSLOT_SECONDARY);
        TF2_GivePlayerWeapon(t, "tf_weapon_fists", TF2_APOCO_FISTS, WEPSLOT_KNIFE);

        SetWeaponAmmo(GetPlayerWeaponSlot(t, WEPSLOT_PRIMARY), t, 9999, 9999);
        SetWeaponAmmo(GetPlayerWeaponSlot(t, WEPSLOT_SECONDARY), t, 9999, 9999);
    }

    else
    {
        StripWeps(t);
        SetEntityHealth(t, GetConVarInt(g_hCvLrRebelHealth));

        GivePlayerItem(t, "weapon_m249");
        GivePlayerItem(t, "weapon_deagle");

        SetEntProp(t, Prop_Send, "m_ArmorValue", 100);
        SetEntProp(t, Prop_Send, "m_bHasHelmet", 1);
    }
}

public RBL_OnLREnd(t, ct)
{
    // Pass
}

