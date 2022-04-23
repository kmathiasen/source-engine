
new g_iWallCount;
new g_iWallIndex = -1;
new g_iWall2Index = -1;

/* ----- Events ----- */


public OR_OnLRStart(t, ct, const String:arg[])
{
    if (++g_iWallCount == 1)
    {
        g_iWallIndex = CreateWall(Float:{-894.4, -2625.0, 100.0}, NULL_VECTOR);
        g_iWall2Index = CreateWall(Float:{-894.4, -2458.0, 100.0}, NULL_VECTOR);
    }

    Tele_DoClient(0, t, "OR T", false);
    Tele_DoClient(0, ct, "OR CT", false);

    CountDownLR(t, ct, 3, OR_OnLRCountedDown);

    PrintToChatAll("%s T wins by pushing the button, CT wins by making it back to the start, Go Go Go!", MSG_PREFIX);
    PrintToChatAll("%s And to spice things up, let's throw in a few grenades", MSG_PREFIX);
}

public OR_OnLRCountedDown(t, ct)
{
    SetEntProp(t, Prop_Send, "m_ArmorValue", 0);
    SetEntProp(ct, Prop_Send, "m_ArmorValue", 0);

    SetEntityHealth(t, 1);
    SetEntityHealth(ct, 1);

    StripWeps(t, false);
    StripWeps(ct, false);

    GivePlayerItem(t, "weapon_flashbang");
    GivePlayerItem(ct, "weapon_flashbang");

    GivePlayerItem(t, "weapon_smokegrenade");
    GivePlayerItem(ct, "weapon_smokegrenade");
}

public OR_OnLREnd(t, ct)
{
    if (--g_iWallCount == 0 && IsValidEntity(g_iWallIndex) && IsValidEntity(g_iWall2Index))
    {
        AcceptEntityInput(g_iWallIndex, "kill");
        AcceptEntityInput(g_iWall2Index, "kill");

        g_iWallIndex = -1;
        g_iWall2Index = -1;
    }

    if (IsClientInGame(t) && JB_IsPlayerAlive(t))
        SetEntityHealth(t, 100);

    if (IsClientInGame(ct) && JB_IsPlayerAlive(ct))
        SetEntityHealth(ct, 100);
}

