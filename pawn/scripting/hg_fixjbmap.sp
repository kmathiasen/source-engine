
/* PURPOSE OF THIS PLUGIN.
    It finds entities in the map that need to be fixed because of epic fail mapping.
    Entities that are fixed:
        * It unparents several env_sprite entities.
        * It disables 2 func_brush entities (pdaclip and pdbclip).
        * It removes unnamed flashbangs (specifically the 2 near dungeon).
*/

// Includes.
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

// Definitions.
#define MSG_PREFIX "\x01\x03"
#define PLUGIN_NAME "hg_fixjbmap"
#define PLUGIN_VERSION "0.01"

// Entities.
new Handle:g_hSpritesToUnparent = INVALID_HANDLE;
new Handle:g_hBrushesToDisable = INVALID_HANDLE;

// Plugin display info.
public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "HeLLsGamers",
    description = "HG Fix JB Map",
    version = PLUGIN_VERSION,
    url = "http://www.hellsgamers.com/"
};

public OnPluginStart()
{
    // Names of the sprites to unparent.
    g_hSpritesToUnparent = CreateTrie();
    SetTrieValue(g_hSpritesToUnparent, "pdat1", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdat2", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdat3", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdas1", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdas2", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdas3", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdbt1", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdbt2", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdbt3", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdbs1", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdbs2", 0);
    SetTrieValue(g_hSpritesToUnparent, "pdbs3", 0);
    SetTrieValue(g_hSpritesToUnparent, "knife_wall_target1", 0);
    SetTrieValue(g_hSpritesToUnparent, "knife_wall_target2", 0);
    SetTrieValue(g_hSpritesToUnparent, "knife_wall_target3", 0);
    SetTrieValue(g_hSpritesToUnparent, "knife_wall_source1", 0);
    SetTrieValue(g_hSpritesToUnparent, "knife_wall_source2", 0);
    SetTrieValue(g_hSpritesToUnparent, "knife_wall_source3", 0);

    // Names of the brushes to disable.
    g_hBrushesToDisable = CreateTrie();
    SetTrieValue(g_hBrushesToDisable, "pdaclip", 0);
    SetTrieValue(g_hBrushesToDisable, "pdbclip", 0);

    // Hook events.
    HookEvent("round_start", OnRoundStart);
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Holders.
    new entindex = INVALID_ENT_REFERENCE;
    decl String:namebuf[32];
    namebuf[0] = '\0';
    new foo;

    // We need to find the brushes to disable.
    while((entindex = FindEntityByClassname(entindex, "func_brush")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(entindex, Prop_Data, "m_iName", namebuf, sizeof(namebuf));
        if(GetTrieValue(g_hBrushesToDisable, namebuf, foo))
            AcceptEntityInput(entindex, "Disable");
    }

    // We need to find the sprites to unparent.
    while((entindex = FindEntityByClassname(entindex, "env_sprite")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(entindex, Prop_Data, "m_iName", namebuf, sizeof(namebuf));
        if(GetTrieValue(g_hSpritesToUnparent, namebuf, foo))
            AcceptEntityInput(entindex, "SetParent", -1, -1);
    }

    // We need to find the flashbangs to delete.
    while((entindex = FindEntityByClassname(entindex, "weapon_flashbang")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(entindex, Prop_Data, "m_iName", namebuf, sizeof(namebuf));
        if(StrEqual(namebuf, ""))
            AcceptEntityInput(entindex, "Kill");
    }
}
