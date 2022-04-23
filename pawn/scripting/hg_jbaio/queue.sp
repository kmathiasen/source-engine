
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_QUEUE_MENUCHOICE_ENTERQUEUE -1111
#define LOCALDEF_QUEUE_MENUCHOICE_LEAVEQUEUE -2222

// Array to store who wants to be CT.
new Handle:g_hQueueArray = INVALID_HANDLE;

// The last time someone was moved from the queue, so things don't fuck up.
new g_iLastChange;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

stock Queue_OnPluginStart()
{
    RegConsoleCmd("ctqueue", Command_QueueMenu);
    RegConsoleCmd("queue", Command_QueueMenu);
    RegConsoleCmd("guardqueue", Command_JoinQueue);
    RegConsoleCmd("enterqueue", Command_JoinQueue);
    RegConsoleCmd("leavequeue", Command_LeaveQueue);

    HookEvent("player_team", Queue_OnJoinTeam); // Instead of hooking, can this function call be moved into hg_jbaio.sp OnJoinTeam() or OnPlayerTeamPost()?
    g_hQueueArray = CreateArray();
}

stock Queue_OnClientDisconnect(client)
{
    new index = FindValueInArray(g_hQueueArray, client);
    if (index > -1)
        RemoveFromArray(g_hQueueArray, index);

    CheckMoveToCT();
}

public Queue_OnJoinTeam(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new team = GetEventInt(event, "team");

    if (!client)
        return;

    if (team == TEAM_GUARDS)
    {
        new index = FindValueInArray(g_hQueueArray, client);
        if (index > -1)
            RemoveFromArray(g_hQueueArray, index);
    }

    CreateTimer(0.1, Timer_CheckMoveToCT);
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_QueueMenu(client, args)
{
    // Is this player already in the queue?  (If FindValueInArray() is zero or positive, he *IS* in the queue).
    new bool:isInQueue = FindValueInArray(g_hQueueArray, client) >= 0;

    // Create menu.
    new Handle:menu = CreateMenu(Queue_MenuSelect);
    SetMenuTitle(menu, "Guard Queue");
    g_iCmdMenuCategories[client] = -1; // Category not applicable
    g_iCmdMenuDurations[client] = -1; // Duration not applicable
    Format(g_sCmdMenuReasons[client], LEN_CONVARS, ""); // Reason not applicable
    decl String:sUserid[LEN_INTSTRING];
    decl String:name[MAX_NAME_LENGTH];

    // Add enter & leave choices.
    if (!isInQueue && GetClientTeam(client) != TEAM_GUARDS)
    {
        IntToString(LOCALDEF_QUEUE_MENUCHOICE_ENTERQUEUE, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "Enter Queue");
    }
    else if (isInQueue)
    {
        IntToString(LOCALDEF_QUEUE_MENUCHOICE_LEAVEQUEUE, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "Leave Queue");
    }

    // Add spacer and list players currently in queue.
    AddMenuItem(menu, "9999", "~~~ Current Queue ~~~", ITEMDRAW_DISABLED);
    new queueSize = GetArraySize(g_hQueueArray);
    if (queueSize <= 0)
        AddMenuItem(menu, "9991", "[None]", ITEMDRAW_DISABLED);
    else
    {
        for (new i = 0; i < queueSize; i++)
        {
            new thisClient = GetArrayCell(g_hQueueArray, i);
            if (!IsClientInGame(thisClient))
                continue;
            GetClientName(thisClient, name, sizeof(name));
            IntToString(GetClientUserId(thisClient), sUserid, sizeof(sUserid));
            AddMenuItem(menu, sUserid, name, thisClient == client ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
        }
    }
    DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
    return Plugin_Handled;
}

public Action:Command_JoinQueue(client, args)
{
    if (!client)
        return Plugin_Handled;

    if (GetClientTeam(client) == TEAM_GUARDS)
    {
        PrintToChat(client,
                    "%s WTF, You're already a Guard...", MSG_PREFIX);
        return Plugin_Handled;
    }

    new index = FindValueInArray(g_hQueueArray, client);

    if (index < 0)
    {
        if (!Tlock_AllowedToJoinGuards(client) || !Tlist_AllowedToJoinGuards(client))
        {
            EmitSoundToClient(client, g_sSoundDeny);
            PrintToChat(client, "%s Freekillers may not join Guards", MSG_PREFIX, client);
            return Plugin_Handled;
        }

        PrintToChat(client,
                    "%s You have been added to the queue at position \x03%d",
                    MSG_PREFIX, GetArraySize(g_hQueueArray) + 1);

        PrintToChat(client,
                    "%s Type \x03!leavequeue \x04 to leave the queue and \x03!queue\x04 to check your position",
                    MSG_PREFIX);

        PushArrayCell(g_hQueueArray, client);
        CheckMoveToCT();
    }

    else
    {
        PrintToChat(client,
                    "%s You are currently in position \x03%d\x04 type \x03!leavequeue\x04 to leave the queue",
                    MSG_PREFIX, index + 1);
    }

    return Plugin_Handled;
}

public Action:Command_LeaveQueue(client, args)
{
    if (!client)
        return Plugin_Handled;

    new index = FindValueInArray(g_hQueueArray, client);
    if (index < 0)
        PrintToChat(client,
                    "%s You are not in the queue. Type \x03!queue\x04 to be added",
                    MSG_PREFIX);

    else
    {
        RemoveFromArray(g_hQueueArray, index);
        PrintToChat(client,
                    "%s You have left the queue. Type \x03!queue\x04 to rejoin",
                    MSG_PREFIX);
    }

    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

stock CheckMoveToCT()
{
    if (!CTSlotOpen(false))
        return;

    if ((GetTime() - g_iLastChange) < 3)
        return;

    for (new i = 0; i < GetArraySize(g_hQueueArray); i++)
    {
        new client = GetArrayCell(g_hQueueArray, i);
        new team = GetClientTeam(client);

        if (!IsClientInGame(client) || team == TEAM_GUARDS)
        {
            RemoveFromArray(g_hQueueArray, i--);
            continue;
        }

        if (!CTSlotOpen(team == TEAM_PRISONERS))
            break;

        PrintToChat(client,
                    "%s Checking to see if you can join the CT team...",
                    MSG_PREFIX);

        if (CanJoinTeam(client, TEAM_GUARDS) != Plugin_Continue)
        {
            PrintToChat(client,
                        "%s You were denied a position on CT and removed from the CT Queue",
                        MSG_PREFIX);

            RemoveFromArray(g_hQueueArray, i--);
            continue;
        }

        StripWeps(client);
        g_bHasBomb[client] = false;

        PrintToChat(client,
                    "%s All's clear with your record! Moving you to CT",
                    MSG_PREFIX);

        g_iLastChange = GetTime();
        RemoveFromArray(g_hQueueArray, i--);

        g_bWasAuthedToJoin[client] = true;

        ChangeClientTeam(client, TEAM_GUARDS);
        break;
    }
}

// ####################################################################################
// ################################### MENU CALLBACKS #################################
// ####################################################################################

public Queue_MenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new iUserid = StringToInt(sUserid);
        if (iUserid < 0)
        {
            // Is this player already in the queue?  (If FindValueInArray() is zero or positive, he *IS* in the queue).
            new bool:isInQueue = FindValueInArray(g_hQueueArray, client) >= 0;

            // Whas the choice to enter the queue or leave the queue?
            if (iUserid == LOCALDEF_QUEUE_MENUCHOICE_ENTERQUEUE)
            {
                if (isInQueue)
                    ReplyToCommandGood(client, "%s You are already in the queue", MSG_PREFIX);
                else
                    FakeClientCommandEx(client, "enterqueue");
            }
            else if (iUserid == LOCALDEF_QUEUE_MENUCHOICE_LEAVEQUEUE)
            {
                if (!isInQueue)
                    ReplyToCommandGood(client, "%s You were not even in the queue...", MSG_PREFIX);
                else
                    FakeClientCommandEx(client, "leavequeue");
            }
            else
                ReplyToCommandGood(client, "%s Invalid selection for respawn", MSG_PREFIX);
        }
        else
        {
            /*  WE DON'T DO ANYTHING FOR ANY OF THE USER SELECTIONS IN THIS MENU.
                THEY ARE JUST FOR LISTING THE QUEUE.
                THEY ARE DUMMY BUTTONS.

            new target = GetClientOfUserId(iUserid);
            if (!target)
                ReplyToCommandGood(client, "%s Target has left the server", MSG_PREFIX);
            else
                // Do something with this client.

            */
        }
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}

// ####################################################################################
// ################################## TIMER CALLBACKS #################################
// ####################################################################################

public Action:Timer_CheckMoveToCT(Handle:timer)
{
    CheckMoveToCT();
}
