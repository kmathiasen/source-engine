
/* ----- Events ----- */


public HM_OnLRStart(t, ct, const String:arg[])
{

    TF2_SaveClassData(t);
    TF2_SaveClassData(ct);

    PrintToChat(t, "%s Watch out! You will become the \x03Headless Horseman", MSG_PREFIX);
    PrintToChat(ct, "%s Watch out! You will become the \x03Headless Horseman", MSG_PREFIX);

    CountDownLR(t, ct, 3, HM_OnCountedDown);
}

public HM_OnCountedDown(t, ct)
{
    if (IsClientInGame(t) && IsClientInGame(ct))
    {
        ServerCommand("sm_behhh #%d", GetClientUserId(t));
        ServerCommand("sm_behhh #%d", GetClientUserId(ct));
    }
}

public HM_OnLREnd(t, ct)
{
    StopHorseman(t);
    StopHorseman(ct);
}

stock StopHorseman(client)
{
    if (!IsClientInGame(client) || !JB_IsPlayerAlive(client))
        return;

    // Tell bethehorsemann.smx that they should stop being a HHH.
    new Handle:event = CreateEvent("post_inventory_application");

    if (event != INVALID_HANDLE)
    {
        SetEventInt(event, "userid", GetClientUserId(client));
        FireEvent(event);
    }

    // Reload their old class data
    TF2_LoadClassData(client);
}

