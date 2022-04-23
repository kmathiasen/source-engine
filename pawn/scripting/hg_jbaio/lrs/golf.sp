#define HOLE_RADIUS 35.0

new g_iGolfCount;
new g_iGolfPlayerThrowing[MAXPLAYERS + 1];

new bool:g_bGolfTrackingPlayer[MAXPLAYERS + 1];

new Handle:g_hGolfTrackingWeapons[MAXPLAYERS + 1];
new Handle:g_hGolfShowLasers[MAXPLAYERS + 1];

new Float:g_fGolfWeaponLocation[MAXPLAYERS + 1][3];
new Float:g_fGolfCachePlayerSpeed[MAXPLAYERS + 1];

new Float:g_fGolfHole[3] = {1195.0, -1503.0, 5.0};

/* ----- Events ----- */

public Golf_OnPluginStart()
{
    RegConsoleCmd("drop", Golf_OnItemDrop);
    CreateTimer(5.0, Timer_ShowGolfHole, _, TIMER_REPEAT);
}

public Golf_OnLRStart(t, ct, const String:arg[])
{
    g_iGolfCount++;
    CountDownLR(t, ct, 3, Golf_OnCountedDown);
    Timer_ShowGolfHole(INVALID_HANDLE, 0);

    Tele_DoClient(0, t, "Deagle Cage", false);
    Tele_DoClient(0, ct, "Deagle Cage", false);

    DisplayMSay(t, "Golf Rules", 30, "First player to get their gun in the hole wins!\nThere is no order, start immediately!");
    DisplayMSay(ct, "Golf Rules", 30, "First player to get their gun in the hole wins!\nThere is no order, start immediately!");
}

public Golf_OnCountedDown(t, ct)
{
    Golf_SetupPlayer(t, "weapon_deagle");
    Golf_SetupPlayer(ct, "weapon_deagle");
}

stock Golf_SetupPlayer(client, const String:arg[])
{
    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_SaveClassData(client);
        StripWeps(client);

        if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
        {
            TF2_SetPlayerClass(client, TFClass_Scout, true, false);
            TF2_GivePlayerWeapon(client, "tf_weapon_bat", TF2_BAT, WEPSLOT_KNIFE);

            SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_scattergun", TF2_SCATTERGUN, WEPSLOT_PRIMARY), client, 0, 0);
            SetWeaponAmmo(TF2_GivePlayerWeapon(client, "tf_weapon_pistol", TF2_SCOUT_PISTOL, WEPSLOT_SECONDARY), client, 0, 0);
        }

        SetWeaponAmmo(GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY), client, -1, 3);

        PrintToChat(client, "%s Careful, if you use all your ammo, you can't throw your gun and you lose!", MSG_PREFIX);
        PrintCenterText(client, "T goes first. Taunt to drop your gun");

        g_iGolfPlayerThrowing[client] = -1;
        EquipPlayerWeapon(client, GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY));

        g_fGolfCachePlayerSpeed[client] = g_fPlayerSpeed[client];
        g_fPlayerSpeed[client] = 300.0;

        SetEntProp(client, Prop_Send, "m_CollisionGroup", 2);
    }

    else
    {
        StripWeps(client);
        g_iGolfPlayerThrowing[client] = GivePlayerItem(client, arg);

        SetEntData(g_iGolfPlayerThrowing[client], m_iClip1, 0);
        SetEntData(client, m_iAmmo +
                   GetEntProp(g_iGolfPlayerThrowing[client], Prop_Send, "m_iPrimaryAmmoType") * 4,
                   1, _, true);
    }

    g_bGolfTrackingPlayer[client] = true;
    g_fGolfWeaponLocation[client] = Float:{0.0, 0.0, 0.0};
}

public Golf_OnLREnd(t, ct)
{
    g_iGolfCount--;

    Golf_OnLREnd_Each(t);
    Golf_OnLREnd_Each(ct);
}

stock Golf_OnLREnd_Each(client)
{
    if (g_iGame == GAMETYPE_CSS)
    {
        if (g_iGolfPlayerThrowing[client] > 0 && IsValidEntity(g_iGolfPlayerThrowing[client]))
            SetEntityRenderColor(g_iGolfPlayerThrowing[client], 255, 255, 255, 255);
    }

    else if (g_iGame == GAMETYPE_CSS)
    {
        g_fPlayerSpeed[client] = g_fGolfCachePlayerSpeed[client];

        if (IsClientInGame(client) && JB_IsPlayerAlive(client))
            SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);

        TF2_LoadClassData(client);
    }

    g_iGolfPlayerThrowing[client] = -1;
    g_bGolfTrackingPlayer[client] = false;

    if (g_hGolfTrackingWeapons[client] != INVALID_HANDLE)
        CloseHandle(g_hGolfTrackingWeapons[client]);
    g_hGolfTrackingWeapons[client] = INVALID_HANDLE;

    if (g_hGolfShowLasers[client] != INVALID_HANDLE)
        CloseHandle(g_hGolfShowLasers[client]);
    g_hGolfShowLasers[client] = INVALID_HANDLE;
}

bool:Golf_OnWeaponCanUse(client, weapon)
{
    // It's their weapon, let them use it
    if (g_iGolfPlayerThrowing[client] == weapon || weapon <= 0)
        return true;

    // It's someone elses weapon, don't let them use it
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_iGolfPlayerThrowing[i] == weapon && i != client)
            return false;
    }

    return true;
}


/* ----- Commands ----- */


public Action:Golf_OnItemDrop(client, args)
{
    if (g_iEndGame != ENDGAME_LR || !g_bGolfTrackingPlayer[client])
        return Plugin_Continue;

    decl String:weapon[LEN_ITEMNAMES];
    GetClientWeapon(client, weapon, sizeof(weapon));

    new slot;
    GetTrieValue(g_hWepsAndItems, weapon[7], slot);

    if (GetPlayerWeaponSlot(client, slot) == g_iGolfPlayerThrowing[client] ||
        g_iGame == GAMETYPE_TF2)
    {
        decl Float:loc[3];
        GetClientAbsOrigin(client, loc);

        if (loc[0] > DEAGLE_LINE_X + 95.0 ||    // They threw significantly above the caution line
            loc[1] < DEAGLE_WALL_Y ||           // They threw to the right of the glass
            loc[1] > DEAGLE_CAGE_Y ||           // They threw to the left of the cage
            loc[2] > 80.0)                      // They threw from above the deagle fence
        {
            if (GetClientTeam(client) == TEAM_PRISONERS)
            {
                PrintToChatAll("%s \x03%N\x04 was made a rebel for cheating",
                               MSG_PREFIX, client);

                MakeWinner(GetPartner(client), false);
                Golf_OnLREnd(client, GetPartner(client));
            }

            else
            {
                PrintToChatAll("%s \x03%N\x04 was slayed for cheating in an LR",
                               MSG_PREFIX, client);
                SlapPlayer(client, GetClientHealth(client) + 101);
            }

            return Plugin_Continue;
        }

        g_hGolfTrackingWeapons[client] = CreateTimer(0.1,
                                                 Timer_MonitorGolfWeapon,
                                                 client,
                                                 TIMER_REPEAT);

        g_bGolfTrackingPlayer[client] = false;
        SetEntityRenderMode(g_iGolfPlayerThrowing[client], RENDER_TRANSCOLOR);

        if (g_iGame == GAMETYPE_CSS)
        {
            if (GetClientTeam(client) == TEAM_PRISONERS)
                SetEntityRenderColor(g_iGolfPlayerThrowing[client], 255, 0, 0, 255);

            else
                SetEntityRenderColor(g_iGolfPlayerThrowing[client], 0, 0, 255, 255);
        }
    }

    return Plugin_Continue;
}


/* ----- Timers ----- */


public Action:Timer_MonitorGolfWeapon(Handle:timer, any:client)
{
    new index = g_iGolfPlayerThrowing[client];
    new lr_index = GetIndex(client);

    // waaaaaaa?
    if (lr_index < 0)
    {
        g_hGolfTrackingWeapons[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    new t = GetArrayCell(g_hLRTs, lr_index);
    new ct = GetArrayCell(g_hLRCTs, lr_index);
    new interupt;

    if (g_iGame != GAMETYPE_TF2)
        interupt = GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity");

    if (interupt > 0)
    {
        g_hGolfTrackingWeapons[client] = INVALID_HANDLE;
        PrintToChatAll("%s Buddayyyy! \x03%N\x04 interfered with \x03%N\x04's LR... Restarting",
                       MSG_PREFIX, interupt, client);

        decl String:wep[MAX_NAME_LENGTH];
        GetEntityClassname(index, wep, sizeof(wep));

        Golf_OnLREnd(t, ct);
        Golf_OnLRStart(t, ct, wep);

        return Plugin_Stop;
    }

    if (index <= 0)
        return Plugin_Continue;

    if (g_iGame == GAMETYPE_TF2)
    {
        decl String:sIndex[8];
        IntToString(index, sIndex, sizeof(sIndex));

        new dummy;

        if (!GetTrieValue(g_hAmmoPackType, sIndex, dummy))
        {
            g_hGolfTrackingWeapons[client] = INVALID_HANDLE;
            PrintToChatAll("%s Buddayyyy! \x03%N\x04's LR was interfered with... Restarting.", MSG_PREFIX, client);

            Golf_OnLREnd(t, ct);
            Golf_OnLRStart(t, ct, "");

            return Plugin_Stop;
        }
    }

    decl Float:loc[3];
    GetEntPropVector(index, Prop_Send, "m_vecOrigin", loc);

    if (GetVectorDistance(g_fGolfWeaponLocation[client], loc) < 0.5)
    {
        g_bGolfTrackingPlayer[client] = false;
        g_hGolfTrackingWeapons[client] = INVALID_HANDLE;

        if (g_hGolfShowLasers[client] == INVALID_HANDLE)
        {
            Timer_ShowGolfLasers(INVALID_HANDLE, client);
            g_hGolfShowLasers[client] = CreateTimer(5.0, Timer_ShowGolfLasers, client, TIMER_REPEAT);
        }

        if (GetVectorDistance(loc, g_fGolfHole) <= HOLE_RADIUS)
        {
            PrintToChatAll("%s \x03%N\x04 has won the \x03golf match", MSG_PREFIX, client);
            MakeWinner(client, false);

            g_bGolfTrackingPlayer[t] = false;
            g_bGolfTrackingPlayer[ct] = false;

            if (g_hGolfTrackingWeapons[t] != INVALID_HANDLE)
            {
                CloseHandle(g_hGolfTrackingWeapons[t]);
                g_hGolfTrackingWeapons[t] = INVALID_HANDLE;
            }

            if (g_hGolfTrackingWeapons[ct] != INVALID_HANDLE)
            {
                CloseHandle(g_hGolfTrackingWeapons[ct]);
                g_hGolfTrackingWeapons[ct] = INVALID_HANDLE;
            }
        }

        else
        {
            g_bGolfTrackingPlayer[client] = true;
            StripWeps(client);

            decl Float:origin[3];
            GetClientAbsOrigin(client, origin);
            TeleportEntity(index, origin, NULL_VECTOR, NULL_VECTOR);
        }

        return Plugin_Stop;
    }

    g_fGolfWeaponLocation[client][0] = loc[0];
    g_fGolfWeaponLocation[client][1] = loc[1];
    g_fGolfWeaponLocation[client][2] = loc[2];

    decl String:message[256];
    Format(message, sizeof(message),
           "     Distance To Center\n%N: %.2f\n%N:%.2f",
           t, g_fGolfWeaponLocation[t][0] ? GetVectorDistance(g_fGolfWeaponLocation[t], g_fGolfHole) : 0.0,
           ct, g_fGolfWeaponLocation[ct][0] ? GetVectorDistance(g_fGolfWeaponLocation[ct], g_fGolfHole) : 0.0);

    PrintHintText(t, message);
    PrintHintText(ct, message);

    return Plugin_Continue;
}

public Action:Timer_ShowGolfLasers(Handle:timer, any:client)
{
    new lr_index = GetIndex(client);

    if (lr_index < 0)
    {
        g_hGolfShowLasers[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    if (g_bGolfTrackingPlayer[client])
        return Plugin_Continue;

    new t = GetArrayCell(g_hLRTs, lr_index);
    new ct = GetArrayCell(g_hLRCTs, lr_index);

    decl Float:top[3];

    decl String:message[256];
    Format(message, sizeof(message),
           "     Distance To Center\n%N: %.2f\n%N:%.2f",
           t, g_fGolfWeaponLocation[t][0] ? GetVectorDistance(g_fGolfWeaponLocation[t], g_fGolfHole) : 0.0,
           ct, g_fGolfWeaponLocation[ct][0] ? GetVectorDistance(g_fGolfWeaponLocation[ct], g_fGolfHole) : 0.0);

    PrintHintText(t, message);
    PrintHintText(ct, message);

    top[0] = g_fGolfWeaponLocation[client][0];
    top[1] = g_fGolfWeaponLocation[client][1];
    top[2] = g_fGolfWeaponLocation[client][2] + 30.0;

    TE_SetupBeamPoints(g_fGolfWeaponLocation[client], top,
                       g_iSpriteBeam, g_iSpriteRing,
                       0, 0, 5.0, 5.0, 5.0, 0, 0.0,
                       g_iLRTeamColors[GetClientTeam(client) - 2], 0);

    TE_SendToAll();
    return Plugin_Continue;
}

public Action:Timer_ShowGolfHole(Handle:timer, any:data)
{
    if (g_iGolfCount > 0)
    {
        TE_SetupBeamRingPoint(g_fGolfHole,
                              HOLE_RADIUS, HOLE_RADIUS + 1.0,
                              g_iSpriteBeam, g_iSpriteRing,
                              0, 15, 5.0, 7.0, 0.0,
                              g_iColorGreen, 1, 0);

        TE_SendToAll();
    }

    return Plugin_Continue;
}