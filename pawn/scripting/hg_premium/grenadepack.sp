// ###################### GLOBALS ######################

#define HEGRENADE_COST 300

new Handle:g_hGrenadeLimit;
new g_iGrenadeLimit;

new g_offsAccount;
new g_offsInBuyZone;

// ###################### EVENTS ######################

public GrenadePack_OnPluginStart()
{
    g_hGrenadeLimit = CreateConVar("hg_premium_hegrenade_limit", "3", "Max amount of grenades a player can carry ['0' = Unlimited]");

    HookConVarChange(g_hGrenadeLimit, GrenadePack_OnConVarChanged);

    if (g_iGame != GAMETYPE_TF2)
    {
        g_offsAccount = FindSendPropInfo("CCSPlayer", "m_iAccount");

        if (g_offsAccount == -1)
            SetFailState("Couldn't find offset \"m_iAccount\"!");

        g_offsInBuyZone = FindSendPropInfo("CCSPlayer", "m_bInBuyZone");
        if (g_offsInBuyZone == -1)
            SetFailState("Couldn't find offset \"m_bInBuyZone\"!");

        AddCommandListener(GrenadePack_Listener_Buy, "buy");
    }
}

public GrenadePack_OnConVarChanged(Handle:CVar, const String:oldV[], const String:newV[])
{
    if (CVar == g_hGrenadeLimit)
        g_iGrenadeLimit = GetConVarInt(g_hGrenadeLimit);
}

public GrenadePack_OnMapStart()
{
    g_iGrenadeLimit = GetConVarInt(g_hGrenadeLimit);
}

public GrenadePack_OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_Touch, GrenadePack_Hook_Touch);
}

public GrenadePack_OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_Touch, GrenadePack_Hook_Touch);
}

// ###################### ACTIONS ######################

public Action:GrenadePack_Listener_Buy(client, const String:command[], argc)
{
    if (!IsClientInGame(client))
        return Plugin_Continue;

    decl String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));

    // They don't have the multi grenade feature, ignore.
    if (!g_bClientEquippedItem[client][Item_MultiNade])
        return Plugin_Continue;

    // If client isn't buying a grenade, then ignore.
    if (!StrEqual(arg1, "hegrenade", false))
        return Plugin_Continue;

    // If client isn't in a buyzone, then ignore.
    if (!GetEntData(client, g_offsInBuyZone, 1))
        return Plugin_Continue;

    // If client doesn't have enough money, then ignore.
    new money = GetEntData(client, g_offsAccount);
    if (money < HEGRENADE_COST)
        return Plugin_Continue;

    // If the client has no grenades then allow the game to buy the grenade for the client.
    if (GrenadePack_GetClientGrenades(client) == 0)
        return Plugin_Continue;

    // Check if the client is under the grenade limit, or if there is no limit.
    new count = GrenadePack_GetClientGrenades(client);
    if (count < g_iGrenadeLimit || g_iGrenadeLimit <= 0)
    {
        SetEntData(client, g_offsAccount, money - HEGRENADE_COST);

        new entity = GivePlayerItem(client, "weapon_hegrenade");
        GrenadePack_PickupGrenade(client, entity);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action:GrenadePack_RemoveGrenade(Handle:timer, any:grenade)
{
    if (IsValidEdict(grenade))
        RemoveEdict(grenade);
}

public Action:GrenadePack_Hook_Touch(client, entity)
{
    if (!IsValidEntity(entity))
        return;

    decl String:classname[32];
    GetEdictClassname(entity, classname, sizeof(classname));

    if (!g_bClientEquippedItem[client][Item_MultiNade])
        return;

    if (StrEqual(classname, "weapon_hegrenade", false))
    {
        new count = GrenadePack_GetClientGrenades(client);

        if (count < g_iGrenadeLimit || g_iGrenadeLimit <= 0)
            GrenadePack_PickupGrenade(client, entity);
    }
}

// ###################### FUNCTIONS ######################

GrenadePack_PickupGrenade(client, entity)
{
    new Handle:event = CreateEvent("item_pickup");
    if (event != INVALID_HANDLE)
    {
        SetEventInt(event, "userid", GetClientUserId(client));
        SetEventString(event, "item", "hegrenade");
        FireEvent(event);
    }

    new Float:loc[3] = {0.0,0.0,0.0};
    TeleportEntity(entity, loc, NULL_VECTOR, NULL_VECTOR);

    CreateTimer(0.1, GrenadePack_RemoveGrenade, entity);

    GrenadePack_GiveClientGrenade(client);

    EmitSoundToClient(client, "items/itempickup.wav");
}

GrenadePack_GetClientGrenades(client)
{
    new offsNades = FindDataMapOffs(client, "m_iAmmo") + (11 * 4);

    return GetEntData(client, offsNades);
}

GrenadePack_GiveClientGrenade(client)
{
    new offsNades = FindDataMapOffs(client, "m_iAmmo") + (11 * 4);

    new count = GetEntData(client, offsNades);
    SetEntData(client, offsNades, ++count);
}