#define DEAGLE_LINE_X 790.0
#define DEAGLE_CAGE_X 1440.0

#define DEAGLE_CAGE_Y -1423.0
#define DEAGLE_WALL_Y -1623.0

new g_iPlayerThrowing[MAXPLAYERS + 1];

new bool:g_bTrackingPlayer[MAXPLAYERS + 1];

new Handle:g_hTrackingWeapons[MAXPLAYERS + 1];
new Handle:g_hShowLasers[MAXPLAYERS + 1];

new Float:g_fWeaponLocation[MAXPLAYERS + 1][3];
new Float:g_fCachePlayerSpeed[MAXPLAYERS + 1];

/* ----- Events ----- */

public DT_OnPluginStart()
{
    RegConsoleCmd("drop", DT_OnItemDrop);
}

public DT_OnLRStart(t, ct, const String:arg[])
{
    DT_SetupPlayer(t, arg);
    DT_SetupPlayer(ct, arg);
}

stock DT_SetupPlayer(client, const String:arg[])
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

        g_iPlayerThrowing[client] = -1;
        EquipPlayerWeapon(client, GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY));

        g_fCachePlayerSpeed[client] = g_fPlayerSpeed[client];
        g_fPlayerSpeed[client] = 300.0;

        SetEntProp(client, Prop_Send, "m_CollisionGroup", 2);
    }

    else
    {
        StripWeps(client);
        g_iPlayerThrowing[client] = GivePlayerItem(client, arg);

        SetEntData(g_iPlayerThrowing[client], m_iClip1, 0);
        SetEntData(client, m_iAmmo +
                   GetEntProp(g_iPlayerThrowing[client], Prop_Send, "m_iPrimaryAmmoType") * 4,
                   1, _, true);
    }

    g_bTrackingPlayer[client] = true;
    g_fWeaponLocation[client] = Float:{0.0, 0.0, 0.0};

    Tele_DoClient(0, client, "Deagle Cage", false);
}

public DT_OnLREnd(t, ct)
{
    DT_OnLREnd_Each(t);
    DT_OnLREnd_Each(ct);
}

stock DT_OnLREnd_Each(client)
{
    if (g_iGame == GAMETYPE_CSS)
    {
        if (g_iPlayerThrowing[client] > 0 && IsValidEntity(g_iPlayerThrowing[client]))
            SetEntityRenderColor(g_iPlayerThrowing[client], 255, 255, 255, 255);
    }

    else if (g_iGame == GAMETYPE_TF2)
    {
        g_fPlayerSpeed[client] = g_fCachePlayerSpeed[client];

        if (IsClientInGame(client) && JB_IsPlayerAlive(client))
            SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);

        TF2_LoadClassData(client);
    }

    g_iPlayerThrowing[client] = -1;
    g_bTrackingPlayer[client] = false;

    if (g_hTrackingWeapons[client] != INVALID_HANDLE)
        CloseHandle(g_hTrackingWeapons[client]);
    g_hTrackingWeapons[client] = INVALID_HANDLE;

    if (g_hShowLasers[client] != INVALID_HANDLE)
        CloseHandle(g_hShowLasers[client]);
    g_hShowLasers[client] = INVALID_HANDLE;
}

bool:DT_OnWeaponCanUse(client, weapon)
{
    // It's their weapon, let them use it
    if (g_iPlayerThrowing[client] == weapon || weapon <= 0)
        return true;

    // It's someone elses weapon, don't let them use it
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_iPlayerThrowing[i] == weapon && i != client)
            return false;
    }

    return true;
}


/* ----- Commands ----- */


public Action:DT_OnItemDrop(client, args)
{
    if (g_iEndGame != ENDGAME_LR || !g_bTrackingPlayer[client])
        return Plugin_Continue;

    decl String:weapon[LEN_ITEMNAMES];
    GetClientWeapon(client, weapon, sizeof(weapon));

    new slot;
    GetTrieValue(g_hWepsAndItems, weapon[7], slot);

    if (GetPlayerWeaponSlot(client, slot) == g_iPlayerThrowing[client] ||
        g_iGame == GAMETYPE_TF2)
    {
        if (GetClientTeam(client) == TEAM_GUARDS)
        {
            if (g_bTrackingPlayer[GetPartner(client)])
            {
                PrintToChat(client, "%s The T goes first in this game", MSG_PREFIX);
                return Plugin_Handled;
            }
        }

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
                DT_OnLREnd(client, GetPartner(client));
            }

            else
            {
                PrintToChatAll("%s \x03%N\x04 was slayed for cheating in an LR",
                               MSG_PREFIX, client);
                SlapPlayer(client, GetClientHealth(client) + 101);
            }

            return Plugin_Continue;
        }

        if (g_iGame == GAMETYPE_TF2)
        {
            PrintToChatAll("%s \x03%N\x04 has thrown their weapon!", MSG_PREFIX, client);
            PrintCenterText(GetPartner(client), "Your turn, taunt to throw your weapon!");
        }

        else
            PrintToChatAll("%s \x03%N\x04 has thrown their \x03%s",
                           MSG_PREFIX, client, weapon[7]);

        g_hTrackingWeapons[client] = CreateTimer(0.1,
                                                 Timer_MonitorWeapon,
                                                 client,
                                                 TIMER_REPEAT);

        g_bTrackingPlayer[client] = false;
        SetEntityRenderMode(g_iPlayerThrowing[client], RENDER_TRANSCOLOR);

        if (g_iGame == GAMETYPE_CSS)
        {
            if (GetClientTeam(client) == TEAM_PRISONERS)
                SetEntityRenderColor(g_iPlayerThrowing[client], 255, 0, 0, 255);

            else
                SetEntityRenderColor(g_iPlayerThrowing[client], 0, 0, 255, 255);
        }
    }

    return Plugin_Continue;
}


/* ----- Timers ----- */


public Action:Timer_MonitorWeapon(Handle:timer, any:client)
{
    new index = g_iPlayerThrowing[client];
    new lr_index = GetIndex(client);
    new t = GetArrayCell(g_hLRTs, lr_index);
    new ct = GetArrayCell(g_hLRCTs, lr_index);
    new interupt;

    if (g_iGame != GAMETYPE_TF2)
        interupt = GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity");

    if (interupt > 0)
    {
        g_hTrackingWeapons[client] = INVALID_HANDLE;
        PrintToChatAll("%s Buddayyyy! \x03%N\x04 interfered with \x03%N\x04's LR... Restarting",
                       MSG_PREFIX, interupt, client);

        decl String:wep[MAX_NAME_LENGTH];
        GetEntityClassname(index, wep, sizeof(wep));

        DT_OnLREnd(t, ct);
        DT_OnLRStart(t, ct, wep);

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
            g_hTrackingWeapons[client] = INVALID_HANDLE;
            PrintToChatAll("%s Buddayyyy! \x03%N\x04's LR was interfered with... Restarting.", MSG_PREFIX, client);

            DT_OnLREnd(t, ct);
            DT_OnLRStart(t, ct, "");

            return Plugin_Stop;
        }
    }

    decl Float:loc[3];
    GetEntPropVector(index, Prop_Send, "m_vecOrigin", loc);

    if (GetVectorDistance(g_fWeaponLocation[client], loc) < 0.5)
    {
        g_bTrackingPlayer[client] = false;
        g_hTrackingWeapons[client] = INVALID_HANDLE;

        Timer_ShowLasers(INVALID_HANDLE, client);
        g_hShowLasers[client] = CreateTimer(5.0, Timer_ShowLasers, client, TIMER_REPEAT);

        new other = client == t ? ct : t;

        if (loc[0] < DEAGLE_LINE_X || loc[0] > DEAGLE_CAGE_X ||
            loc[1] < DEAGLE_WALL_Y || loc[1] > DEAGLE_CAGE_Y)
        {
            PrintToChatAll("%s \x03%N\x04 has lost the gun toss due to an invalid throw",
                           MSG_PREFIX, client);

            PushArrayCell(g_hLRWinners, other);
            DT_OnLREnd(t, ct);
        }

        else if (g_hShowLasers[other] != INVALID_HANDLE)
        {
            new winner = g_fWeaponLocation[t][0] > g_fWeaponLocation[ct][0] ? t : ct;

            PrintToChatAll("%s \x03%N\x04 has won the \x03gun toss\x04 by a distance of \x03%.2f",
                           MSG_PREFIX, winner,
                           FloatAbs(g_fWeaponLocation[t][0] - g_fWeaponLocation[ct][0]));

            MakeWinner(winner, false);
        }

        return Plugin_Stop;
    }

    g_fWeaponLocation[client][0] = loc[0];
    g_fWeaponLocation[client][1] = loc[1];
    g_fWeaponLocation[client][2] = loc[2];

    decl String:message[256];
    Format(message, sizeof(message),
           "     Caution Line Distance\n%N: %.2f\n%N:%.2f",
           t, g_fWeaponLocation[t][0] ? g_fWeaponLocation[t][0] - DEAGLE_LINE_X : 0.0,
           ct, g_fWeaponLocation[ct][0] ? g_fWeaponLocation[ct][0] - DEAGLE_LINE_X : 0.0);

    PrintHintText(t, message);
    PrintHintText(ct, message);

    return Plugin_Continue;
}

public Action:Timer_ShowLasers(Handle:timer, any:client)
{
    new lr_index = GetIndex(client);

    if (lr_index < 0)
    {
        g_hShowLasers[client] = INVALID_HANDLE;
        return Plugin_Continue;
    }

    new t = GetArrayCell(g_hLRTs, lr_index);
    new ct = GetArrayCell(g_hLRCTs, lr_index);

    decl Float:top[3];

    decl String:message[256];
    Format(message, sizeof(message),
           "     Caution Line Distance\n%N: %.2f\n%N:%.2f",
           t, g_fWeaponLocation[t][0] ? g_fWeaponLocation[t][0] - DEAGLE_LINE_X : 0.0,
           ct, g_fWeaponLocation[ct][0] ? g_fWeaponLocation[ct][0] - DEAGLE_LINE_X : 0.0);

    PrintHintText(t, message);
    PrintHintText(ct, message);

    top[0] = g_fWeaponLocation[client][0];
    top[1] = g_fWeaponLocation[client][1];
    top[2] = g_fWeaponLocation[client][2] + 30.0;

    TE_SetupBeamPoints(g_fWeaponLocation[client], top,
                       g_iSpriteBeam, g_iSpriteRing,
                       0, 0, 5.0, 5.0, 5.0, 0, 0.0,
                       g_iLRTeamColors[GetClientTeam(client) - 2], 0);

    TE_SendToAll();
    return Plugin_Continue;
}
