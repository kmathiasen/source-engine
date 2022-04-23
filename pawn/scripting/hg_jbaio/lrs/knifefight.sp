
new bool:g_bIsDizzy[MAXPLAYERS + 1];
new bool:g_bBackStab[MAXPLAYERS + 1];
new bool:g_bSuddenDeath[MAXPLAYERS + 1];

/* ----- Events ----- */


public KF_OnLRStart(t, ct, const String:arg[])
{
    if (g_iGame != GAMETYPE_TF2)
    {
        StripWeps(t);
        StripWeps(ct);

        SetEntityHealth(t, 100);
        SetEntityHealth(ct, 100);

        SetEntProp(t, Prop_Send, "m_ArmorValue", 0);
        SetEntProp(ct, Prop_Send, "m_ArmorValue", 0);
    }

    else
    {
        for (new j = 0; j < 2; j++)
        {
            new i = j ? t : ct;

            TF2_SaveClassData(i);

            if (StrEqual(arg, "tank"))
            {
                TF2_SetPlayerClass(i, TFClass_Heavy, true, false);
                TF2_SetProperModel(i);

                SetEntityHealth(i, 500);

                TF2_GivePlayerWeapon(i, "tf_weapon_minigun", TF2_BRASS_BEAST, WEPSLOT_PRIMARY);
                TF2_GivePlayerWeapon(i, "tf_weapon_shotgun", TF2_SHOTGUN, WEPSLOT_SECONDARY);
                TF2_GivePlayerWeapon(i, "tf_weapon_fists", TF2_APOCO_FISTS, WEPSLOT_KNIFE);

                SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_PRIMARY), i, -1, 0);
                SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_SECONDARY), i, 0, 0);
            }

            else
            {
                TF2_SetPlayerClass(i, TFClass_Scout, true, false);
                TF2_SetProperModel(i);

                SetEntityHealth(i, 140);

                TF2_GivePlayerWeapon(i, "tf_weapon_scattergun", TF2_SCATTERGUN, WEPSLOT_PRIMARY);
                TF2_GivePlayerWeapon(i, "tf_weapon_pistol", TF2_SCOUT_PISTOL, WEPSLOT_SECONDARY);
                TF2_GivePlayerWeapon(i, "tf_weapon_bat_fish", TF2_MACKEREL, WEPSLOT_KNIFE);

                SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_PRIMARY), i, 0, 0);
                SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_SECONDARY), i, 0, 0);
            }
        }
    }

    if (StrEqual(arg, "speedy"))
    {
        SetEntPropFloat(t, Prop_Data, "m_flLaggedMovementValue", 2.0);
        SetEntPropFloat(ct, Prop_Data, "m_flLaggedMovementValue", 2.0);

        if (g_iGame == GAMETYPE_TF2)
        {
            g_fPlayerSpeed[t] = 520.0;
            g_fPlayerSpeed[ct] = 520.0;
        }
    }

    else if (StrEqual(arg, "acid"))
    {
        if (g_iGame == GAMETYPE_CSGO)
        {
            ClientCommand(t, "r_screenoverlay effects/fisheyelens_normal.vmt");
            ClientCommand(ct, "r_screenoverlay effects/fisheyelens_normal.vmt");

            ClientCommand(t, "r_screenoverlay effects/strider_pinch_dudv");
            ClientCommand(ct, "r_screenoverlay effects/strider_pinch_dudv");

            ClientCommand(t, "r_screenoverlay models/effects/portalfunnel_sheet");
            ClientCommand(ct, "r_screenoverlay models/effects/portalfunnel_sheet");
        }

        else
        {
            ClientCommand(t, "r_screenoverlay effects/tp_eyefx/tp_eyefx.vmt");
            ClientCommand(ct, "r_screenoverlay effects/tp_eyefx/tp_eyefx.vmt");
        }
    }

    else if (StrEqual(arg, "tank"))
    {
        SetEntityHealth(t, 500);
        SetEntityHealth(ct, 500);
    }

    else if (StrEqual(arg, "sudden death"))
    {
        SetEntityHealth(t, 1);
        SetEntityHealth(ct, 1);

        g_bSuddenDeath[t] = true;
        g_bSuddenDeath[ct] = true;
    }

    else if (StrEqual(arg, "dizzy"))
    {
        ServerCommand("sm_dizzy #%d 100", GetClientUserId(t));
        ServerCommand("sm_dizzy #%d 100", GetClientUserId(ct));

        g_bIsDizzy[t] = true;
        g_bIsDizzy[ct] = true;
    }

    else if (StrEqual(arg, "blind"))
    {
        PerformBlind(t, 253);
        PerformBlind(ct, 253);
    }

    else if (StrEqual(arg, "thirdperson"))
    {
        SetThirdPersonView(t, true);
        SetThirdPersonView(ct, true);
    }

    else if (StrEqual(arg, "scout"))
    {
        if (g_iGame == GAMETYPE_CSS)
        {
            GivePlayerItem(t, "weapon_scout");
            GivePlayerItem(ct, "weapon_scout");
        }

        else
        {
            GivePlayerItem(t, "weapon_ssg08");
            GivePlayerItem(ct, "weapon_ssg08");
        }

        SetEntityGravity(t, 0.3);
        SetEntityGravity(ct, 0.3);
    }

    else if (StrEqual(arg, "backstab"))
    {
        g_bBackStab[t] = true;
        g_bBackStab[ct] = true;
    }
}

public KF_OnLREnd(t, ct)
{
    if (IsClientInGame(t))
    {
        if (JB_IsPlayerAlive(t))
        {
          //SetEntityHealth(t, 100);
            SetEntityGravity(t, 1.0);
            SetEntPropFloat(t, Prop_Data, "m_flLaggedMovementValue", 1.0);

            if (g_bIsDizzy[t])
                ServerCommand("sm_dizzy #%d 0", GetClientUserId(t));
        }

        PerformBlind(t, 0);
        SetThirdPersonView(t, false);
        ClientCommand(t, "r_screenoverlay \"\"");
    }


    if (IsClientInGame(ct))
    {
        if (JB_IsPlayerAlive(ct))
        {
          //SetEntityHealth(ct, 100);
            SetEntityGravity(ct, 1.0);
            SetEntPropFloat(ct, Prop_Data, "m_flLaggedMovementValue", 1.0);

            if (g_bIsDizzy[ct])
                ServerCommand("sm_dizzy #%d 0", GetClientUserId(ct));
        }

        PerformBlind(ct, 0);
        SetThirdPersonView(ct, false);
        ClientCommand(ct, "r_screenoverlay \"\"");
    }

    g_bIsDizzy[t] = false;
    g_bIsDizzy[ct] = false;

    g_bBackStab[t] = false;
    g_bBackStab[ct] = false;

    g_bSuddenDeath[t] = false;
    g_bSuddenDeath[ct] = false;

    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_LoadClassData(t);
        TF2_LoadClassData(ct);
    }
}

bool:KF_OnTakeDamage(victim, attacker, Float:damage)
{
    // Sudden death, they should dai.
    if (g_bSuddenDeath[victim])
        SetEntityHealth(victim, 1);

    // If they are not doing a back-stab fight, then allow the damage to CONTINUE.
    if (!g_bBackStab[victim] || !g_bBackStab[attacker])
        return true;

    // They ARE doing a back-stab fight --- so --- if it wasn't a back-stab, STOP the damage.
    if (damage <= 65.0)
        return false;

    // It was a back-stab --- allow the damage to CONTINUE.
    return true;
}

/* ----- Functions ----- */


// Taken from funcommands, part of a SM Team project.
PerformBlind(target, amount)
{
	new targets[2];
	targets[0] = target;
	
	new duration = 1536;
	new holdtime = 1536;
	new flags;
	if (amount == 0)
	{
		flags = (0x0001 | 0x0010);
	}
	else
	{
		flags = (0x0002 | 0x0008);
	}
	
	new color[4] = { 0, 0, 0, 0 };
	color[3] = amount;
	
	new Handle:message = StartMessageEx(GetUserMessageId("Fade"), targets, 1);
	if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	}
	else
	{
		BfWriteShort(message, duration);
		BfWriteShort(message, holdtime);
		BfWriteShort(message, flags);		
		BfWriteByte(message, color[0]);
		BfWriteByte(message, color[1]);
		BfWriteByte(message, color[2]);
		BfWriteByte(message, color[3]);
	}

	EndMessage();
}
