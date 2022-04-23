
// Includes.
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

// Definitions.
#define MSG_PREFIX "\x01[Gun Control Law]\x03"
#define PLUGIN_NAME "hg_noguns"
#define PLUGIN_VERSION "0.01"
#define LEN_ITEMNAMES 32

// Team definitions.
#define TEAM_UNASSIGNED 0
#define TEAM_SPEC 1
#define TEAM_PRISONERS 2
#define TEAM_GUARDS 3

// Globals.
new bool:g_bGunsAllowed;
new Handle:g_hWepsAndItems = INVALID_HANDLE;

// Plugin display info.
public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "HG No Guns (for Terrorists)",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

public OnPluginStart()
{
    // Hook events.
    HookEvent("round_start", OnRoundStart);
    HookEvent("item_pickup", OnItemPickup);

    // Register commands.
    RegAdminCmd("sm_allowguns", Cmd_AllowGuns, ADMFLAG_ROOT, "Allows Terrorists picking up guns");
    RegAdminCmd("sm_denyguns", Cmd_DenyGuns, ADMFLAG_ROOT, "Denys Terrorists picking up guns");

    // Fill weapon and item Trie.
    PopulateWeaponsAndItems();

    // Initial state.
    g_bGunsAllowed = true;
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_bGunsAllowed = true;
}

public Action:Cmd_AllowGuns(adminClient, args)
{
    g_bGunsAllowed = true;
    for(new i = 0; i < 3; i++)
        PrintToChatAll("%s Terrorists may own guns", MSG_PREFIX);
    PrintToChatAll("%s (this is for HnS games -- don't abuse it)", MSG_PREFIX);
    return Plugin_Handled;
}

public Action:Cmd_DenyGuns(adminClient, args)
{
    g_bGunsAllowed = false;
    for(new i = 0; i < 3; i++)
        PrintToChatAll("%s Terrorists may \x04NOT\x03 own guns", MSG_PREFIX);
    PrintToChatAll("%s (this is for HnS games -- don't abuse it)", MSG_PREFIX);

    // Strip all current guns.
    for(new i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        if(GetClientTeam(i) != TEAM_PRISONERS)
            continue;
        StripWeps(i);
    }

    return Plugin_Handled;
}

public OnItemPickup(Handle:event, const String:eventname[], bool:dontBroadcast)
{
    // We only check this if guns are supposed to be denied.
    if(g_bGunsAllowed)
        return;

    // Get client from event args.
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // Exit if client is not valid.
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    // We only care about checking Terrorists.
    if(GetClientTeam(client) != TEAM_PRISONERS)
        return;

    // Get which item was picked up from event args.
    new String:itemname[LEN_ITEMNAMES];
    GetEventString(event, "item", itemname, sizeof(itemname));

    // Get type (slot) of weapon,
    /*
        0 = primary
        1 = secondary
        2 = knife
        3 = nade(s)
        4 = c4
        5 = other items
    */
    new slot;
    if(!GetTrieValue(g_hWepsAndItems, itemname, slot)) return;

    // Find out ID of weapon.  Its not an event arg that we can just extract.
    // We need to check the client's weapon slot.
    // If he has it, then we can get the ID from the weapon in his slot.
    new wepid = GetPlayerWeaponSlot(client, slot);
    if(wepid != -1)
    {
        // We only care if it's a primary or secondary slot item (a weapon).
        if((slot != 0) && (slot!= 1))
            return;

        // Strip this weapon from the Terrorist on a delay.
        new Handle:data = CreateDataPack();
        WritePackCell(data, client && IsClientInGame(client) ? GetClientUserId(client) : 0);
        WritePackCell(data, wepid);
        CreateTimer(0.1, DelayedStripWep, data);
    }
    return;
}

public Action:DelayedStripWep(Handle:timer, any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    new client = GetClientOfUserId(ReadPackCell(Handle:data));
    new wepid = ReadPackCell(Handle:data);

    // Is player and weapon valid?
    if(client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsValidEntity(wepid))
        return Plugin_Stop;

    // Strip it.
    RemovePlayerItem(client, wepid);

    // Notify player.
    for(new i = 0; i < 3; i++)
        PrintToChat(client, "%s Terrorists can't own guns right now", MSG_PREFIX);

    // Done.
    return Plugin_Stop;
}

stock PopulateWeaponsAndItems()
{
    if(g_hWepsAndItems != INVALID_HANDLE)
        return;
    g_hWepsAndItems = CreateTrie();

    // The value is which slot it goes in.
    /*
        0 = primary
        1 = secondary
        2 = knife
        3 = nade(s)
        4 = c4
        5 = other items
    */

    // Shotguns.
    SetTrieValue(g_hWepsAndItems, "m3", 0);
    SetTrieValue(g_hWepsAndItems, "xm1014", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_m3", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_xm1014", 0);

    // Submachine guns.
    SetTrieValue(g_hWepsAndItems, "mac10", 0);
    SetTrieValue(g_hWepsAndItems, "tmp", 0);
    SetTrieValue(g_hWepsAndItems, "mp5navy", 0);
    SetTrieValue(g_hWepsAndItems, "ump45", 0);
    SetTrieValue(g_hWepsAndItems, "p90", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_mac10", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_tmp", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_mp5navy", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_ump45", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_p90", 0);

    // Rifles.
    SetTrieValue(g_hWepsAndItems, "galil", 0);
    SetTrieValue(g_hWepsAndItems, "ak47", 0);
    SetTrieValue(g_hWepsAndItems, "scout", 0);
    SetTrieValue(g_hWepsAndItems, "sg552", 0);
    SetTrieValue(g_hWepsAndItems, "awp", 0);
    SetTrieValue(g_hWepsAndItems, "g3sg1", 0);
    SetTrieValue(g_hWepsAndItems, "famas", 0);
    SetTrieValue(g_hWepsAndItems, "m4a1", 0);
    SetTrieValue(g_hWepsAndItems, "aug", 0);
    SetTrieValue(g_hWepsAndItems, "sg550", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_galil", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_ak47", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_scout", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_sg552", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_awp", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_g3sg1", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_famas", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_m4a1", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_aug", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_sg550", 0);

    // Machine guns.
    SetTrieValue(g_hWepsAndItems, "m249", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_m249", 0);

    // Pistols.
    SetTrieValue(g_hWepsAndItems, "glock", 1);
    SetTrieValue(g_hWepsAndItems, "usp", 1);
    SetTrieValue(g_hWepsAndItems, "p228", 1);
    SetTrieValue(g_hWepsAndItems, "deagle", 1);
    SetTrieValue(g_hWepsAndItems, "elite", 1);
    SetTrieValue(g_hWepsAndItems, "fiveseven", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_glock", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_usp", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_p228", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_deagle", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_elite", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_fiveseven", 1);

    // Knife.
    SetTrieValue(g_hWepsAndItems, "knife", 2);
    SetTrieValue(g_hWepsAndItems, "weapon_knife", 2);

    // Nades.
    SetTrieValue(g_hWepsAndItems, "flashbang", 3);
    SetTrieValue(g_hWepsAndItems, "hegrenade", 3);
    SetTrieValue(g_hWepsAndItems, "smokegrenade", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_flashbang", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_hegrenade", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_smokegrenade", 3);

    // Bomb.
    SetTrieValue(g_hWepsAndItems, "c4", 4);
    SetTrieValue(g_hWepsAndItems, "weapon_c4", 4);

    // Items.
    SetTrieValue(g_hWepsAndItems, "vest", 5);
    SetTrieValue(g_hWepsAndItems, "vesthelm", 5);
    SetTrieValue(g_hWepsAndItems, "defuser", 5);
    SetTrieValue(g_hWepsAndItems, "nvgs", 5);
    SetTrieValue(g_hWepsAndItems, "item_vest", 5);
    SetTrieValue(g_hWepsAndItems, "item_vesthelm", 5);
    SetTrieValue(g_hWepsAndItems, "item_defuser", 5);
    SetTrieValue(g_hWepsAndItems, "item_nvgs", 5);
}

stock StripWeps(client, bool:giveknife=true)
{
    if(IsClientInGame(client) && (IsPlayerAlive(client)))
    {
        new wepid = 0;
        for(new i = 0; i <= 4; i++)
        {
            if((wepid = GetPlayerWeaponSlot(client, i)) != -1)
            {
                RemovePlayerItem(client, wepid);
                RemoveEdict(wepid);
            }
        }
        if(giveknife) GivePlayerItem(client, "weapon_knife");
    }
}
