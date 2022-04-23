
new g_iRRCount;
new g_iRRBullets[MAXPLAYERS + 1];

/* ----- Events ----- */

public RR_OnPluginStart()
{
    RegConsoleCmd("drop", RR_OnItemDrop);
}

public RR_OnLRStart(t, ct, const String:arg[])
{
    StripWeps(t, false);
    StripWeps(ct, false);

    new start_client = GetRandomInt(0, 1) ? t : ct;
    GivePlayerItem(start_client, "weapon_deagle");

    Tele_DoClient(0, t, "rr1", false);
    Tele_DoClient(0, ct, "rr2", false);

    SetEntityMoveType(t, MOVETYPE_NONE);
    SetEntityMoveType(ct, MOVETYPE_NONE);

    SetEntityHealth(t, 10);
    SetEntityHealth(ct, 10);

    g_iRRBullets[t] = 1;
    g_iRRBullets[ct] = 1;

    if (++g_iRRCount == 1)
        HookEvent("weapon_fire", RR_OnWeaponFire, EventHookMode_Pre);
}

public RR_OnLREnd(t, ct)
{
    if (IsClientInGame(t) && JB_IsPlayerAlive(t))
    {
        SetEntityMoveType(t, MOVETYPE_WALK);
        SetEntityHealth(t, 100);
    }

    if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
    {
        SetEntityMoveType(ct, MOVETYPE_WALK);
        SetEntityHealth(ct, 100);
    }

    if (--g_iRRCount == 0)
        UnhookEvent("weapon_fire", RR_OnWeaponFire, EventHookMode_Pre);
}

public Action:RR_OnWeaponFire(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsInLR(client, "Russian Roulette"))
    {
        decl String:weapon[MAX_NAME_LENGTH];
        GetEventString(event, "weapon", weapon, sizeof(weapon));

        if (StrEqual(weapon, "deagle"))
        {
            if (GetRandomInt(1, 7) > g_iRRBullets[client])
            {
                new partner = GetPartner(client);

                g_iRRBullets[client]++;
                g_iRRBullets[partner]++;

                StripWeps(client, false);
                StripWeps(partner, false);

                PrintToChatAll("%s BANG BANG BANG. Oh wait, it's a dud!", MSG_PREFIX);

                GivePlayerItem(partner, "weapon_deagle");

                return Plugin_Stop;
            }

            else
            {
                // Let the damage go through.
                MakeWinner(client, false);
                new victim = GetPartner(client);
                SetEntProp(victim, Prop_Send, "m_ArmorValue", 0);
                DealDamage(victim, GetClientHealth(victim) + 1, client);

                new extraRepToGive = g_iRRBullets[client] * 2;
                PrisonRep_AddPoints(client, extraRepToGive);
                PrintToChat(client, "%s You recieved an extra \x03%d\x04 rep for surviving \x03%d\x04 bullet(s)",
                            MSG_PREFIX, extraRepToGive, g_iRRBullets[client]);
                StopLR(client);
            }
        }
    }

    return Plugin_Continue;
}

public Action:RR_OnItemDrop(client, args)
{
    if (g_iEndGame == ENDGAME_LR &&
        IsInLR(client, "Russian Roulette"))
    {
        PrintToChat(client, "%s Meow, why would you drop that?", MSG_PREFIX);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

// Credit to pimpinjuice ( https://forums.alliedmods.net/showthread.php?t=111684&highlight=point_Hurt )
//#define DMG_BULLET			(1 << 1)

stock DealDamage(victim,damage,attacker=0,dmg_type=DMG_BULLET,String:weapon[]="weapon_deagle")
{
	if (victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && JB_IsPlayerAlive(victim) && damage>0)
	{
		new String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new pointHurt=CreateEntityByName("point_hurt");
		if (pointHurt)
		{
			DispatchKeyValue(victim,"targetname","war3_hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","war3_hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if (!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","war3_donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}
