
new g_iLRT;
new bool:g_bAlreadyLR;

new Handle:g_hAcceptedLR = INVALID_HANDLE;
new Handle:g_hDeclinedLR = INVALID_HANDLE;

/* ----- Events ----- */

stock CL_OnPluginStart()
{
    g_hAcceptedLR = CreateArray();
    g_hDeclinedLR = CreateArray();

    RegConsoleCmd("sm_endcustomlr", Command_EndCustomLR);
}

CL_OnClientDisconnect()
{
    CL_ShouldEndLR();
}

CL_OnTakeDamage(victim, attacker, victimIsInCustomLr, attackerIsInCustomLr, bool:kill)
{
    /*  Possible return values:

        * LOCALDEF_LR_ALL_INTERFERENCE_HANDLED      --- All necessary tasks (such as stopping LRs, making rebels, etc)
                                                        already got taken care of inside this function.  There is
                                                        nothing else for the calling code to do.
        * LOCALDEF_LR_ATTACKER_INTERFERED           --- The attacker interfered with this Custom LR, and therefore the
                                                        calling code should stop the attacker's own LR (if he is in one)
                                                        due to interference.
        * LOCALDEF_LR_VICTIM_GOT_INTERFERED_WITH    --- The victim in ths Custom LR got interfered with, and therefore,
                                                        if the the victim's LR should be stopped because it was unfairly
                                                        interfered with.
    */

    // If someone in a CUSTOM LR died, check participation...
    if (kill)
        CL_ShouldEndLR();

    // If BOTH attacker & victim are in a CUSTOM LR...
    if (attackerIsInCustomLr && victimIsInCustomLr)
        return LOCALDEF_LR_ALL_INTERFERENCE_HANDLED;

    // If ONLY the attacker is in a CUSTOM LR...
    if (attackerIsInCustomLr)
    {
        // If the attacker is a Prisoner...
        if (attacker == g_iLRT)
        {
            // The attacker should not have shot the victim.
            PrintToChatAll("%s \x03%N\x04's ruined his LR by interfering with \x03%N",
                           MSG_PREFIX, attacker, victim);
            StopLR(attacker);

            // He is rebelling.
            MakeRebel(attacker, kill);
        }

        // If the attacker is a Guard...
        else
        {
            // He is freeshooting.
            if (kill)
                RebelTrk_OnGuardKilledPrisoner(attacker, victim);
            else
                RebelTrk_OnGuardHurtPrisoner(attacker, victim);
        }

        // Try to prevent further damage by this mean person.
        StripWeps(attacker, false);

        // The victim may be in a regular LR, which may need to be stopped for interference by this attacker.
        return LOCALDEF_LR_VICTIM_GOT_INTERFERED_WITH;
    }

    // If ONLY the victim is in a CUSTOM LR...
    else
    {
        // The attacker may be in a regular LR, which may need to be stopped because he interfered with this victim.
        return LOCALDEF_LR_ATTACKER_INTERFERED;
    }
}

public CL_OnLRStart(t, ct, const String:arg[])
{
    g_bAlreadyLR = true;
    g_iLRT = t;

    ClearArray(g_hAcceptedLR);
    ClearArray(g_hDeclinedLR);

    decl String:title[64];
    Format(title, sizeof(title), "Accept %N's Custom LR?", t);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsElligibleCT(i))
        {
            PushArrayCell(g_hDeclinedLR, i);
            continue;
        }

        new Handle:menu = CreateMenu(AcceptCustomLRRequest);

        SetMenuTitle(menu, title);
        SetMenuExitButton(menu, false);

        AddMenuItem(menu, "", "Yes");
        AddMenuItem(menu, "", "No");

        DisplayMenu(menu, i, MENU_TIMEOUT_NORMAL);
    }

    PrintToChat(t,
                "%s Type \x01!\x03endcustomlr\x04 to end your Custom LR early",
                MSG_PREFIX);
}

public CL_OnLREnd(t, ct)
{
    g_bAlreadyLR = false;
    g_iLRT = 0;

    for (new i = 0; i < GetArraySize(g_hAcceptedLR); i++)
    {
        new client = GetArrayCell(g_hAcceptedLR, i);
        if (IsClientInGame(client) && JB_IsPlayerAlive(client))
        {
            SetEntityRenderMode(client, RENDER_TRANSCOLOR);
            SetEntityRenderColor(client, 255, 255, 255, 255);
        }
    }

    ClearArray(g_hAcceptedLR);
    ClearArray(g_hDeclinedLR);
}


/* ----- Commands ----- */


public Action:Command_EndCustomLR(client, args)
{
    if (!client)
        return Plugin_Continue;

    if (client != g_iLRT)
    {
        PrintToChat(client, "%s You do not own a Custom LR!", MSG_PREFIX);
        return Plugin_Handled;
    }

    PrintToChatAll("%s \x03%N\x04 has ended his Custom LR", MSG_PREFIX, client);
    StopLR(client);

    return Plugin_Handled;
}


/* ----- Functions ----- */


bool:CL_IsThereACustomLrNow()
{
    return g_bAlreadyLR;
}

bool:CL_IsInCustomLr(client)
{
    if (g_iLRT <= 0)
        return false;

    if (client == g_iLRT)
        return true;

    if (FindValueInArray(g_hAcceptedLR, client) > -1)
        return true;

    return false;
}

bool:CL_CanCustomLR(client)
{
    if (g_bAlreadyLR)
    {
        PrintToChat(client, "%s There may only be 1 custom LR at a time", MSG_PREFIX);
        return false;
    }

    new bool:elligible;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsElligibleCT(i))
            continue;

        elligible = true;
        break;
    }

    if (!elligible)
    {
        PrintToChat(client, "%s There are no elligible guards to have a custom LR with", MSG_PREFIX);
        return false;
    }

    return true;
}

stock CL_ShouldEndLR()
{
    if (g_iLRT <= 0)
        return;

    if (!IsClientInGame(g_iLRT) || !JB_IsPlayerAlive(g_iLRT))
    {
        PrintToChatAll("%s \x03%N\x04's custom LR is over due to he's dead, yo.",
                       MSG_PREFIX, g_iLRT);
        StopLR(g_iLRT);
    }

    for (new i = 0; i < GetArraySize(g_hAcceptedLR); i++)
    {
        new client = GetArrayCell(g_hAcceptedLR, i);
        if (IsClientInGame(client) && JB_IsPlayerAlive(client))
            return;
    }

    new bool:any_left;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsElligibleCT(i) || FindValueInArray(g_hDeclinedLR, i) > -1)
            continue;

        any_left = true;
        break;
    }

    if (!any_left)
    {
        PrintToChatAll("%s \x03%N\x04's Custom LR is over due to lack of participants",
                       MSG_PREFIX, g_iLRT);

        StopLR(g_iLRT);
    }
}


/* ----- Menus ----- */


public AcceptCustomLRRequest(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (IsClientInGame(client) &&
                IsFakeClient(client) &&
                GetRandomInt(0, 1))
            {
                PrintToChatAll("Forcing %N to accept", client);
                PushArrayCell(g_hAcceptedLR, client);

                SetEntityRenderMode(client, RENDER_TRANSCOLOR);
                SetEntityRenderColor(client, 0, 255, 0, 255);
            }

            PushArrayCell(g_hDeclinedLR, client);
            CL_ShouldEndLR();
        }

        case MenuAction_Select:
        {
            // Yes.
            if (selected == 0)
            {
                if (!IsElligibleCT(client))
                {
                    PrintToChat(client, "%s You are no longer elligible to accept this LR", MSG_PREFIX);
                    PushArrayCell(g_hDeclinedLR, client);

                    return;
                }

                if (g_iLRT <= 0)
                {
                    PrintToChat(client, "%s This Custom LR invitation has ended", MSG_PREFIX);
                    return;
                }

                PrintToChatAll("%s \x03%N\x04 has accepted \x03%N\x04's custom LR",
                               MSG_PREFIX, client, g_iLRT);

                PushArrayCell(g_hAcceptedLR, client);

                SetEntityRenderMode(client, RENDER_TRANSCOLOR);
                SetEntityRenderColor(client, 0, 255, 0, 255);
            }

            // No.
            else
            {
                PushArrayCell(g_hDeclinedLR, client);
                CL_ShouldEndLR();
            }
        }
    }
}

