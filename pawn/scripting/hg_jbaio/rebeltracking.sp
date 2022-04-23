
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

// Gun Check globals.
new Handle:g_hGunCheckTimers[MAXPLAYERS + 1];               // Store all timer handles for auto declaring a person rebel for having a gun out too long.
new bool:g_bIsRebelFromGun[MAXPLAYERS + 1];                 // Store whether or not the player is a rebel because they held out a gun too long.

// Rebel Status globals.
new g_iLatestAttacker_ForDamage = 0;                        // Stores the latest client who attacked, so we dont spam chat when the same client shoots the same victim over and over again.
new g_iLatestVictim_ForDamage = 0;                          // Same as above, except it stores the victim's client instead of the attacker's.
new g_iLatestVictim_ForKills = 0;                           // Same as above, excelt for kills.

// Auto Freekill Protection globals.
new Handle:g_hFkpTimers[MAXPLAYERS + 1];                    // Hold the FKP tracking timers for each guard.  Even though there wont be 64 Guards, we still need MAXPLAYERS+1 slots because any client (#1-#64) could be a CT.
new g_iFkpKillCounts[MAXPLAYERS + 1];                       // Array to hold how many times a Guard kills a Prisoner.
new g_iNonRebelAt[MAXPLAYERS + 1];

// Declare commonly used ConVars.
new Float:g_fFkpInterval = 0.0;
new g_iFkpLimit = 0;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

RebelTrk_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_fFkpInterval = GetConVarFloat(g_hCvFkpSeconds);
    g_iFkpLimit = GetConVarInt(g_hCvFkpKills);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvFkpSeconds, RebelTrk_OnConVarChange);
    HookConVarChange(g_hCvFkpKills, RebelTrk_OnConVarChange);
}

public RebelTrk_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvFkpSeconds)
        g_fFkpInterval = GetConVarFloat(g_hCvFkpSeconds);
    else if (CVar == g_hCvFkpKills)
        g_iFkpLimit = GetConVarInt(g_hCvFkpKills);
}

RebelTrk_OnClientPutInServer(client)
{
    RebelTrk_ResetTrackers(client);
}

RebelTrk_OnClientDisconnect(client)
{
    RebelTrk_ResetTrackers(client);
}

RebelTrk_OnRndStrt_General()
{
    // Reset trackers.
    g_iLatestAttacker_ForDamage = 0;
    g_iLatestVictim_ForDamage = 0;
}

RebelTrk_OnRndStrt_EachClient(client)
{
    RebelTrk_ResetTrackers(client);
}

RebelTrk_OnRndStrt_EachValid(client)
{
    // Set colors to normal.
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, 255, 255, 255, 255);
}

RebelTrk_OnGuardHurtPrisoner(attacker, victim)
{
    /* This function is only called on if endgame state is ENDGAME_NONE or ENDGAME_LR. */

    // Was victim innocent (not a rebel) when he was injured?
    if (g_hMakeNonRebelTimers[victim] == INVALID_HANDLE &&
       !g_bIsInvisible[victim])
    {
        // Don't spam same thing over and over.
        if ((g_iLatestAttacker_ForDamage != attacker) || (g_iLatestVictim_ForDamage != victim))
        {
            // Record for next time.
            g_iLatestAttacker_ForDamage = attacker;
            g_iLatestVictim_ForDamage = victim;

            /* Do we really need this?
            // Notify users that a guard attacked a NON-REBEL prisoner.
            decl String:attacker_name[MAX_NAME_LENGTH];
            decl String:victim_name[MAX_NAME_LENGTH];
            GetClientName(attacker, attacker_name, sizeof(attacker_name));
            GetClientName(victim, victim_name, sizeof(victim_name));
            for (new i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i))
                    PrintToConsole(i, "**** POSSIBLE FREESHOT **** [%s] attacked NON-REBEL [%s] (BUT HE MAY HAVE BEEN DISOBEYING ORDERS)", attacker_name, victim_name);
            }
            */

            // Notify victim about the guard who possibly freeshot him.
            PrintToChat(victim, "%s Guard \x03%N\x04 attacked you", MSG_PREFIX, attacker);
        }
    }
}

RebelTrk_OnGuardKilledPrisoner(attacker, victim)
{
    /* This function is only called on if endgame state is ENDGAME_NONE or ENDGAME_LR. */


    // When a T is in NOCLIP and gets shot (in the head, mostly) he actually dies -- and this
    // function is called.  But he does not really die because NOCLIP keeps him alive.  So his
    // head is in the same spot and the CT can just spray his head easilly.  This means the T
    // in NOCLIP is getting killed over-and-over again by the CT.  These kills count against
    // the CT's freekilling number and he will get auto-T-Listed very easilly.  The below line
    // will keep the same death from being considered by this function multiple times in a row.
    if (g_iLatestVictim_ForKills == victim)
        return;
    g_iLatestVictim_ForKills = victim;

    // Since there is no longer a hgjbcp, I can't add new rooms easily...
    // The database file manager is complete shit, and doesn't work.
    // So hard coding it is...

    decl Float:origin[3];
    GetClientAbsOrigin(victim, origin);

    // Was victim innocent (not a rebel) when he died?
    if (g_hMakeNonRebelTimers[victim] == INVALID_HANDLE &&
       !g_bIsInvisible[victim] &&
       (!MapCoords_IsInRoomEz(victim, "Armory") || g_iEndGame != ENDGAME_NONE) &&
       !(g_bIsRebelFromEChair[victim] &&
         origin[0] < -20.0 && origin[0] > -150.0 &&
         origin[1] < -3100.0 && origin[1] > -3300.0 &&
         origin[2] < 100.0))
    {
        // Notify users that a guard killed a NON-REBEL prisoner.
        decl String:attacker_name[MAX_NAME_LENGTH];
        decl String:victim_name[MAX_NAME_LENGTH];
        GetClientName(attacker, attacker_name, sizeof(attacker_name));
        GetClientName(victim, victim_name, sizeof(victim_name));

        // There's no lead, there's no end game, and they didn't recently turn back to normal color.
        // And, the lead died at least 3 seconds ago.

        if (g_iEndGame == ENDGAME_NONE &&
            g_iLeadGuard <= 0 &&
            (GetTime() - g_iLeadDiedAt) > 2 &&
            (GetTime() - g_iNonRebelAt[victim]) > 2)
        {
            PrintToChatAll("%s There is no lead/orders and \x03%N\x04 freekilled \x03%N\x04. Booo!",
                           MSG_PREFIX, attacker, victim);

            decl String:title[64];
            Format(title, sizeof(title), "You just freekilled %N", victim);

            DisplayMSay(attacker,
                        title,
                        60,
                        "If there is NO LEAD, there is NO ORDERS\nYou may only kill red people\nor people in armory");

            ForcePlayerSuicide(attacker);
        }

        else
            PrintToConsoleAll("**** POSSIBLE FREEKILL **** [%s] killed NON-REBEL [%s]", attacker_name, victim_name);

        // It's LR, so we only want to display possible freekills.
        if (g_iEndGame != ENDGAME_NONE)
            return;

        /******* AUTO FREEKILL PROTECTION STUFF *******/

        // Ensure guard does not already have a timer running.
        if (g_hFkpTimers[attacker] != INVALID_HANDLE)
            CloseHandle(g_hFkpTimers[attacker]);
        g_hFkpTimers[attacker] = INVALID_HANDLE;

        // Increase how many free kills the attacker has done
        g_iFkpKillCounts[attacker] += 1;

        if (g_iFkpKillCounts[attacker] >= g_iFkpLimit)
        {
            /* Automatic Free-Kill Protection (FKP) triggered. */

            // Reset the attacker's kill count.
            g_iFkpKillCounts[attacker] = 0;

            // T-List.
            new admin = 0; // 0 for CONSOLE;
            new fkpDuration = GetConVarInt(g_hCvFkpDuration);
            new cmdType = 0; // 0 for T-List; 1 for Un-T-List;

            Tlist_DoClient(admin,
                           attacker,
                           fkpDuration,
                           cmdType,
                           "Triggered Automatic Free Kill Protection\nVisit http://hellsgamers.com/topic/101477-for-the-auto-tlist-or-tarp-kings/ for details");

            // Display messages.
            PrintToChatAll("%s \x03%s\x04 triggered automatic Free Kill Protection and was T-Listed for \x03%i\x04 minutes",
                MSG_PREFIX, attacker_name, fkpDuration);
        }

        else
        {
            // Create a timer for him.  The interval should be divided by how many kills he already has (don't divide by zero).
            new Float:interval = g_fFkpInterval;
            if (g_iFkpKillCounts[attacker] > 0)
                interval = g_fFkpInterval / (g_iFkpKillCounts[attacker] + (GetAdminLevel(attacker) / 2));

            if (interval < 0.5 - (GetAdminLevel(attacker) / 50.0))
                interval = 0.5 - (GetAdminLevel(attacker) / 50.0);

            g_hFkpTimers[attacker] = CreateTimer(interval, RebelTrk_DecKillCount, GetClientUserId(attacker));
        }
    }

    else
        PrisonRep_OnGuardKillRebel(attacker);
}

RebelTrk_OnWeaponSwitch(client, weapon)
{
    // On weapon switch executes after someone leaves the server or dies. Strange.
    if (!IsClientInGame(client) || !JB_IsPlayerAlive(client))
        return;

    // Only execute if it's a T and no end game and they're not a rebel already.
    if (GetClientTeam(client) != TEAM_PRISONERS ||
        g_iEndGame > ENDGAME_NONE ||
        g_hMakeNonRebelTimers[client] != INVALID_HANDLE)
        return;

    // Find out if the weapon they are now holding is a GUN or a different type of weapon (like a knife or bomb).
    // We can do this by getting the name of the weapon, and then seeing if it belongs to the primary or secondary gun slot.
    decl String:sWeapon[LEN_ITEMNAMES];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
    new slot = -1;
    GetTrieValue(g_hWepsAndItems, sWeapon, slot);

    // It's a primary, or secondary?
    if (slot == 0 || slot == 1)
    {
        if (g_hGunCheckTimers[client] == INVALID_HANDLE)
        {
            new Float:delay = GetConVarFloat(g_hCvRebelGunAutoRebelSeconds);
            g_hGunCheckTimers[client] = CreateTimer(delay, RebelTrk_MakeTempRebel, GetClientUserId(client));
        }
    }

    // It's something else, stop the timer that's gonna make them a rebel.
    else
    {
        if (g_hGunCheckTimers[client] != INVALID_HANDLE)
            CloseHandle(g_hGunCheckTimers[client]);
        g_hGunCheckTimers[client] = INVALID_HANDLE;
    }
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

RebelTrk_EndGameTime()
{
    // Reset trackers.
    g_iLatestAttacker_ForDamage = 0;
    g_iLatestVictim_ForDamage = 0;

    // Reset rebel's colors to normal.
    for (new i = 1; i <= MaxClients; i++)
    {
        // Reset trackers.
        if (g_hMakeNonRebelTimers[i])
            CloseHandle(g_hMakeNonRebelTimers[i]);

        g_hMakeNonRebelTimers[i] = INVALID_HANDLE;
        g_iFkpKillCounts[i] = 0;
        g_bIsRebelFromGun[i] = false;

        // Set colors to normal.
        if (IsClientInGame(i) && JB_IsPlayerAlive(i))
        {
            // If they are invisible, make them visible.
            if (g_bIsInvisible[i])
                MakeTotalPlayerVisible(i, true);
            else
            {
                // They are not invisible so just worry about their colors; not their visibility.
                SetEntityRenderMode(i, RENDER_TRANSCOLOR);
                SetEntityRenderColor(i, 255, 255, 255, 255);
            }
        }
    }
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

bool:IsRebel(client)
{
    return (g_hMakeNonRebelTimers[client] != INVALID_HANDLE || g_bIsInvisible[client]);
}

stock MakeRebel(attacker, type=REBELTYPE_HURT)
{
    // Get prison rep (the duration of being a rebel is based on his rep).
    new rep = PrisonRep_GetPoints(attacker);
    new Float:rebeltime;

    // Throwback Thursday
    if (g_bIsThursday)
        rep = 0;

    if (type == REBELTYPE_SHOOT)
        rebeltime = GetConVarFloat(g_hCvRebelShoot);

    else
        rebeltime = GetRebelTime(rep, type);

    MakeRebelTime(attacker, rebeltime, type);
}

stock MakeRebelTime(attacker, Float:rebeltime, type=REBELTYPE_HURT)
{
    // If this would make them a rebel for a shorter amount of time than they already are, stop.
    if (g_iNonRebelAt[attacker] &&
        (GetTime() + RoundToNearest(rebeltime)) < g_iNonRebelAt[attacker])
        return;

    g_iNonRebelAt[attacker] = GetTime() + RoundToNearest(rebeltime);

    // Only do if the Prisoner was not already a rebel or invisible (invisible is always considered rebel already).
    if (g_hMakeNonRebelTimers[attacker] == INVALID_HANDLE)
    {
        if (!g_bIsInvisible[attacker])
        {
            // Set red.
            SetEntityRenderMode(attacker, RENDER_TRANSCOLOR);
            SetEntityRenderColor(attacker, g_iColorRed[0], g_iColorRed[1], g_iColorRed[2], 255);

            // Notify that he has rebelled.
            // But only if it's not for shooting (to avoid chat spam).

            if (type != REBELTYPE_SHOOT)
                PrintToChatAll("%s \x03%N\x04 is a rebel for \x03%.1f\x04 seconds", MSG_PREFIX, attacker, rebeltime);
        }
    }
    else
        CloseHandle(g_hMakeNonRebelTimers[attacker]);

    switch(type)
    {
        case REBELTYPE_HURT:
            KeyHintText(attacker, "Rebel Time (Hurt): %.1f", rebeltime);

        case REBELTYPE_KILL:
            KeyHintText(attacker, "Rebel Time (Kill): %.1f", rebeltime);

        case REBELTYPE_SHOOT:
            KeyHintText(attacker, "Rebel Time (Shoot): %.1f", rebeltime);

        case REBELTYPE_TELE:
            KeyHintText(attacker, "Rebel Time (Tele): %.1f", rebeltime);
    }

    // Create a timer to reset his rebel status
    g_hMakeNonRebelTimers[attacker] = CreateTimer(rebeltime,
                                                  RebelTrk_ResetRebelStatus,
                                                  GetClientUserId(attacker));

    // Set their state to not a rebel because of having a gun out.
    // This ensures that they don't become a non-rebel if they drop their gun.
    g_bIsRebelFromGun[attacker] = false;
}

RebelTrk_ResetTrackers(client)
{
    // Kill Gun Check timer.
    if (g_hGunCheckTimers[client] != INVALID_HANDLE)
        CloseHandle(g_hGunCheckTimers[client]);
    g_hGunCheckTimers[client] = INVALID_HANDLE;

    // Kill Rebel Status timer.
    if (g_hMakeNonRebelTimers[client] != INVALID_HANDLE)
        CloseHandle(g_hMakeNonRebelTimers[client]);
    g_hMakeNonRebelTimers[client] = INVALID_HANDLE;

    // Kill Auto Freekill Protection timer.
    if (g_hFkpTimers[client] != INVALID_HANDLE)
        CloseHandle(g_hFkpTimers[client]);
    g_hFkpTimers[client] = INVALID_HANDLE;

    // Reset how many potential freekills this client has.
    g_iFkpKillCounts[client] = 0;

    // Reset whether this client is tracked as a permanent rebel.
    g_bIsInvisible[client] = false;

    // Reset whether the client is tracked as rebel for having gun out.
    g_bIsRebelFromGun[client] = false;
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public Action:RebelTrk_DecKillCount(Handle:timer, any:userid)
{
    /**** BEGIN STANDARD TIMER STUFF ****/

    // Always pass userids instead of clients when sending to a delayed callback.
    new client = GetClientOfUserId(userid);

    // Invalidate global timer handles as first as possible
    // so we don't forget or return early without doing it.
    g_hFkpTimers[client] = INVALID_HANDLE;

    // Ensure player is still in game, since this is a delayed callback.
    if (client <= 0)
        return Plugin_Stop;

    /**** END STANDARD TIMER STUFF ****/

    // Decrease their free kill count by 1
    if (g_iFkpKillCounts[client] > 0)
        g_iFkpKillCounts[client]--;

    // In case they still have free kills agains them, decrease again
    if (g_iFkpKillCounts[client] > 0)
        g_hFkpTimers[client] = CreateTimer(g_fFkpInterval / g_iFkpKillCounts[client],
                                           RebelTrk_DecKillCount, userid);

    return Plugin_Stop;
}

public Action:RebelTrk_CheckNonRebel(Handle:timer, any:userid)
{
    /**** BEGIN STANDARD TIMER STUFF ****/

    // Always pass userids instead of clients when sending to a delayed callback.
    new client = GetClientOfUserId(userid);

    // Ensure player is still in game, since this is a delayed callback.
    if (client <= 0)
        return Plugin_Stop;

    /**** END STANDARD TIMER STUFF ****/

    // We would only make them a non-rebel if they are alive and on the prisoner team, of course.
    if (GetClientTeam(client) != TEAM_PRISONERS || !JB_IsPlayerAlive(client))
        return Plugin_Stop;

    // We would only make them a non-rebel if they are visible (because invisible prisoners are always considered rebels).
    if (g_bIsInvisible[client])
        return Plugin_Stop;

    // Find out if the weapon they are now holding is a GUN or a different type of weapon (like a knife or bomb).
    // We can do this by getting the name of the weapon, and then seeing if it belongs to the primary or secondary gun slot.
    decl String:sWeapon[LEN_ITEMNAMES];
    GetClientWeapon(client, sWeapon, sizeof(sWeapon));
    new slot = -1;
    if (!GetTrieValue(g_hWepsAndItems, sWeapon, slot))
        return Plugin_Stop;

    // They're still holding a weapon, so don't make them a non rebel.
    if (slot == WEPSLOT_PRIMARY || slot == WEPSLOT_SECONDARY)
        return Plugin_Stop;

    // Only reset their rebel status, if they're just a rebel from holding out a gun.
    if (g_bIsRebelFromGun[client])
    {
        if (g_hMakeNonRebelTimers[client] != INVALID_HANDLE)
            CloseHandle(g_hMakeNonRebelTimers[client]);
        RebelTrk_ResetRebelStatus(INVALID_HANDLE, GetClientUserId(client));
    }

    return Plugin_Stop;
}

public Action:RebelTrk_MakeTempRebel(Handle:timer, any:userid)
{
    /**** BEGIN STANDARD TIMER STUFF ****/

    // Always pass userids instead of clients when sending to a delayed callback.
    new client = GetClientOfUserId(userid);

    // Invalidate global timer handles as first as possible
    // so we dont forget or return early without doing it.
    g_hGunCheckTimers[client] = INVALID_HANDLE;

    // Ensure player is still in game, since this is a delayed callback.
    if (client <= 0)
        return Plugin_Stop;

    /**** END STANDARD TIMER STUFF ****/

    if (g_iEndGame > ENDGAME_NONE ||
        !JB_IsPlayerAlive(client) ||
        g_hMakeNonRebelTimers[client] != INVALID_HANDLE ||
        g_bIsInvisible[client])
        return Plugin_Stop;

    decl String:sWeapon[MAX_NAME_LENGTH];
    GetClientWeapon(client, sWeapon, sizeof(sWeapon));

    new slot = -1;
    GetTrieValue(g_hWepsAndItems, sWeapon, slot);

    if (slot != 0 && slot != 1)
        return Plugin_Stop;

    // Store that they're a rebel because they've had a gun out too long.
    // This way, we can make them a non rebel if they drop their gun.
    g_bIsRebelFromGun[client] = true;

    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, g_iColorRed[0], g_iColorRed[1], g_iColorRed[2], 255);

    new ticks = GetConVarInt(g_hCvRebelGunAutoRebelTicks);
    new rebeltime = RoundToNearest(ticks * GetConVarFloat(g_hCvRebelSecondsPerTick));

    PrintToChat(client,
                "%s You were made a rebel for \x03%d\x04 seconds for holding a gun out too long",
                MSG_PREFIX, rebeltime);

    // Make them not a rebel in rebeltime seconds
    g_hMakeNonRebelTimers[client] = CreateTimer(float(rebeltime), RebelTrk_ResetRebelStatus, GetClientUserId(client));

    return Plugin_Stop;
}

public Action:RebelTrk_ResetRebelStatus(Handle:timer, any:userid)
{
    /**** BEGIN STANDARD TIMER STUFF ****/

    // Always pass userids instead of clients when sending to a delayed callback.
    new client = GetClientOfUserId(userid);

    // Invalidate global timer handles as first as possible
    // so we dont forget or return early without doing it.
    g_hMakeNonRebelTimers[client] = INVALID_HANDLE; // Doing this also allow them to become a rebel again, if they rebel.

    // Ensure player is still in game, since this is a delayed callback.
    if (client <= 0)
        return Plugin_Stop;

    /**** END STANDARD TIMER STUFF ****/

    decl String:sWeapon[32];
    GetClientWeapon(client, sWeapon, sizeof(sWeapon));

    // Get the current slot of the weapon.
    new slot = -1;
    GetTrieValue(g_hWepsAndItems, sWeapon, slot);
    if (slot == 0 || slot == 1)
    {
        g_hMakeNonRebelTimers[client] = CreateTimer(1.0, RebelTrk_ResetRebelStatus, GetClientUserId(client));
        return Plugin_Stop;
    }
    if (!g_bIsInvisible[client])
    {
        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
    PrintToChat(client, "%s you have turned back to normal color", MSG_PREFIX);

    // Just in case!
    g_bIsRebelFromGun[client] = false;

    return Plugin_Stop;
}

Float:GetRebelTime(rep, type)
{
    new Float:rebeltime = 95.0 * (1.0 / ((rep + 2800.0) * 0.001));
    if (rebeltime < 5.0)
        rebeltime = 5.0;
    return rebeltime * (type == REBELTYPE_KILL ? 2 : 1);
}
