/*
To Do:
    Make it so that <x> hours of game play per week gives you free effects
    Make it so that presents spawn randomly on the map ever ~30 minutes, and each one of those presents grants VIP for a weekz
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1

#define MSG_PREFIX "\x03[HG Premium]: \x01"
#define DEFAULT_TIMEOUT 60

enum EffectTypes
{
    ET_Particle = 0,
    ET_Color
};

new Handle:g_hValidHats = INVALID_HANDLE;
new Handle:g_hParticleArray = INVALID_HANDLE;
new Handle:g_hParticleTrie = INVALID_HANDLE;
new Handle:g_hColorArray = INVALID_HANDLE;
new Handle:g_hColorTrie = INVALID_HANDLE;
new Handle:g_hActiveParticle = INVALID_HANDLE;
new Handle:g_hActiveColor = INVALID_HANDLE;

new String:g_sParticle[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new String:g_sColor[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new String:g_sConfigPath[PLATFORM_MAX_PATH];
new String:g_sColorConfigPath[PLATFORM_MAX_PATH];
new String:g_sGift[PLATFORM_MAX_PATH] = "models/items/tf_gift.mdl"; // CHANGE ANIMATION TO spin!!!!!!!!!
//new String:g_sGift[PLATFORM_MAX_PATH] = "models/items/currencypack_large.mdl"; CHANGE ANIMATION TO idle!!!!!!!!!

new EffectTypes:g_iChoosingEffect[MAXPLAYERS + 1];

new m_clrRender = -1;

/* ----- Events ----- */


public OnPluginStart()
{
    RegAdminCmd("sm_particles", Command_MainMenu, ADMFLAG_GENERIC);
    RegAdminCmd("sm_effects", Command_MainMenu, ADMFLAG_GENERIC);
    RegAdminCmd("sm_vip", Command_MainMenu, ADMFLAG_GENERIC);

    g_hActiveParticle = RegClientCookie("hg_particle",
                                        "Active Particle", CookieAccess_Protected);

    g_hActiveColor = RegClientCookie("hg_particle_color",
                                     "Active Color", CookieAccess_Protected);

    g_hValidHats = CreateArray();
    g_hParticleArray = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
    g_hColorArray = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
    g_hParticleTrie = CreateTrie();
    g_hColorTrie = CreateTrie();

    BuildPath(Path_SM, g_sConfigPath, sizeof(g_sConfigPath), "configs/particles.cfg");
    BuildPath(Path_SM, g_sColorConfigPath, sizeof(g_sColorConfigPath), "configs/particles_colors.cfg");

    ParseConfig(g_sConfigPath, g_hParticleArray, g_hParticleTrie);
    ParseConfig(g_sColorConfigPath, g_hColorArray, g_hColorTrie);

    GenerateHats();

    CreateTimer(123.456, Timer_Adverts, _, TIMER_REPEAT); 

    m_clrRender = FindSendPropOffs("CAI_BaseNPC", "m_clrRender");

    // Debug
    HookEvent("player_spawn", OnPlayerSpawn);
}

// Debug
public OnPlayerSpawn(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client && IsClientInGame(client) && IsPlayerAlive(client))
    {
        decl Float:origin[3];
        GetClientAbsOrigin(client, origin);

        origin[0] += 70.0;
        origin[2] += 10.0;

        SpawnGift(origin);
    }
}

public Action:TF2Items_OnGiveNamedItem(client, String:classname[], iItemDefinitionIndex, &Handle:hItemOverride)
{
    if (GetUserFlagBits(client) &&
        StrEqual(classname, "tf_wearable") &&
        FindValueInArray(g_hValidHats, iItemDefinitionIndex) != -1 &&
        (!StrEqual(g_sParticle[client], "") || !StrEqual(g_sColor[client], "")))
    {
        new curr_index;

        new Handle:hItem = TF2Items_CreateItem(OVERRIDE_ALL);
        new flags = OVERRIDE_ATTRIBUTES|OVERRIDE_ITEM_QUALITY|PRESERVE_ATTRIBUTES;

        TF2Items_SetItemIndex(hItem, iItemDefinitionIndex);
        TF2Items_SetClassname(hItem, "tf_wearable");

        TF2Items_SetQuality(hItem, 6);

        if (!StrEqual(g_sParticle[client], ""))
        {
            decl String:index[8];

            if (!GetTrieString(g_hParticleTrie, g_sParticle[client], index, sizeof(index)))
            {
                PrintToChat(client, "%s Error grabbing data for \x04\"%s\" \x01 :(", MSG_PREFIX, g_sParticle[client]);
                return Plugin_Continue;
            }

            TF2Items_SetAttribute(hItem, curr_index++, 134, StringToFloat(index));
            TF2Items_SetAttribute(hItem, curr_index++, 370, StringToFloat(index));
        }

        if (!StrEqual(g_sColor[client], ""))
        {
            decl String:index[16];

            if (!GetTrieString(g_hColorTrie, g_sColor[client], index, sizeof(index)))
            {
                PrintToChat(client, "%s Error grabbing data for \x04\"%s\" \x01 :(", MSG_PREFIX, g_sColor[client]);
                return Plugin_Continue;
            }

            TF2Items_SetAttribute(hItem, curr_index++, 142, StringToFloat(index));
        }

        TF2Items_SetNumAttributes(hItem, curr_index);
        TF2Items_SetFlags(hItem, flags);

        hItemOverride = hItem;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public OnClientCookiesCached(client)
{
    CacheParticle(client);
}

public OnClientPostAdminCheck(client)
{
    CacheParticle(client);
}

public OnClientPutInServer(client)
{
    g_sParticle[client][0] = '\0';
    g_sColor[client][0] = '\0';
}

public OnMapStart()
{
    PrecacheModel(g_sGift);
}

public OnStartTouch(ent, client)
{
    PrintToChatAll("%d %d", ent, client);
}


/* ----- Functions ----- */


stock SpawnGift(Float:origin[3])
{
    new parent = CreateEntityByName("prop_physics_override");
    new gift = CreateEntityByName("prop_dynamic_override");

    decl String:targetname[MAX_NAME_LENGTH];
    Format(targetname, sizeof(targetname), "hg_gift_%d", parent);

    DispatchKeyValue(parent, "model", g_sGift);
    DispatchKeyValue(parent, "spawnflags", "8");
    DispatchKeyValue(parent, "targetname", targetname);

    DispatchSpawn(parent);

    SetEntData(parent, m_clrRender + 3, 0, 1, true);
    SetEntityRenderMode(parent, RENDER_TRANSTEXTURE);

    SetEntProp(parent, Prop_Send, "m_usSolidFlags", 8);
    SetEntProp(parent, Prop_Send, "m_CollisionGroup", 1);

    TeleportEntity(parent, origin, NULL_VECTOR, NULL_VECTOR);

    DispatchKeyValueVector(gift, "origin", origin);
    DispatchKeyValue(gift, "targetname", targetname);
    DispatchKeyValue(gift, "model", g_sGift);

    DispatchSpawn(gift);
    SetVariantString("!activator");

    AcceptEntityInput(gift, "SetParent", parent, parent);
    AcceptEntityInput(gift, "TurnOn");

    SetVariantString("spin");
    AcceptEntityInput(gift, "SetAnimation");

    SDKHook(parent, SDKHook_StartTouch, OnStartTouch);
}

stock CacheParticle(client)
{
    decl String:particle[MAX_NAME_LENGTH];
    GetClientCookie(client, g_hActiveParticle, particle, sizeof(particle));

    decl String:color[MAX_NAME_LENGTH];
    GetClientCookie(client, g_hActiveColor, color, sizeof(color));

    if (!StrEqual(particle, ""))
        Format(g_sParticle[client], MAX_NAME_LENGTH, particle);

    if (!StrEqual(color, ""))
        Format(g_sColor[client], MAX_NAME_LENGTH, color);
}

stock GenerateHats()
{
    ClearArray(g_hValidHats);

    new Handle: hKV = CreateKeyValues("");
    FileToKeyValues(hKV, "scripts/items/items_game.txt");

    KvRewind(hKV);
    KvJumpToKey(hKV, "items");

    KvGotoFirstSubKey(hKV, false);
    do
    {
        decl String:index[8];
        KvGetSectionName(hKV, index, sizeof(index));

        decl String:item_class[MAX_NAME_LENGTH];
        KvGetString(hKV, "item_class", item_class, sizeof(item_class));

        if (StrEqual(item_class, "tf_wearable"))
        {
            decl String:item_slot[MAX_NAME_LENGTH];
            KvGetString(hKV, "item_slot", item_slot, sizeof(item_slot));

            if (StrEqual(item_slot, "head", false))
                PushArrayCell(g_hValidHats, StringToInt(index));

            continue;
        }

        decl String:prefab[MAX_NAME_LENGTH];
        KvGetString(hKV, "prefab", prefab, sizeof(prefab));

        if (StrEqual(prefab, "hat", false))
            PushArrayCell(g_hValidHats, StringToInt(index));

    } while (KvGotoNextKey(hKV, false));
}

stock ParseConfig(const String:path[], Handle:arr, Handle:trie)
{
    ClearArray(arr);
    ClearTrie(trie);

    PushArrayString(arr, "None");
    SetTrieString(trie, "None", "");

    new Handle:oFile = OpenFile(path, "r");
    decl String:line[MAX_NAME_LENGTH * 2 + 4];
    decl String:sParts[2][MAX_NAME_LENGTH];

    while (ReadFileLine(oFile, line, sizeof(line)))
    {
        TrimString(line);
        if (StrEqual(line, ""))
            continue;

        ExplodeString(line, " - ", sParts, 2, MAX_NAME_LENGTH);

        PushArrayString(arr, sParts[0]);
        SetTrieString(trie, sParts[0], sParts[1]);
    }

    CloseHandle(oFile);
}

stock PopulateMenu(client, const String:title[], Handle:arr, Handle:trie, String:key[], EffectTypes:choosing)
{
    new Handle:menu = CreateMenu(EffectMenuSelect);

    SetMenuTitle(menu, title);
    SetMenuExitBackButton(menu, true);

    g_iChoosingEffect[client] = choosing;

    for (new i = 0; i < GetArraySize(arr); i++)
    {
        decl String:name[MAX_NAME_LENGTH];
        decl String:display[MAX_NAME_LENGTH + 9];

        GetArrayString(arr, i, name, sizeof(name));
        if (StrEqual(name, key[client]))
        {
            Format(display, sizeof(display), "%s [Active]", name);
            AddMenuItem(menu, name, display, ITEMDRAW_DISABLED);
        }

        else
        {
            Format(display, sizeof(display), name);
            AddMenuItem(menu, name, display);
        }

    }

    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}


/* ----- Timers ----- */


public Action:Timer_Adverts(Handle:timer, any:data)
{
    PrintToChatAll("%s VIP members and Top 20 can type \x04!vip\x01 to enable particle effects on ANY hat!", MSG_PREFIX);
    PrintToChatAll("%s Visit \x04http://hellsgamers.com/premium\x01 to sign up!", MSG_PREFIX);
    return Plugin_Continue;
}


/* ----- Commands ----- */


public Action:Command_MainMenu(client, args)
{
    new Handle:menu = CreateMenu(MainMenuSelect);
    SetMenuTitle(menu, "HG TF2 VIP");

    AddMenuItem(menu, "", "Choose Particle Effect");
    AddMenuItem(menu, "", "Choose Hat Color");

    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}


/* ----- Menu Callbacks ----- */


public MainMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Select:
        {
            switch (selected)
            {
                // Choose Particle Effect
                case 0:
                    PopulateMenu(client, "HG Particle Effects", g_hParticleArray, g_hParticleTrie, g_sParticle[client], ET_Particle);

                // Choose Hat Color
                case 1:
                    PopulateMenu(client, "HG Hat Colors", g_hColorArray, g_hColorTrie, g_sColor[client], ET_Color);
            }
        }
    }
}

public EffectMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                Command_MainMenu(client, 0);
        }

        case MenuAction_Select:
        {
            decl String:effect[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, effect, sizeof(effect));


            switch (g_iChoosingEffect[client])
            {
                case ET_Particle:
                {
                    PrintToChat(client, "%s Your particle effect is now \x04%s", MSG_PREFIX, effect);
                    Format(g_sParticle[client], MAX_NAME_LENGTH, effect);
                    SetClientCookie(client, g_hActiveParticle, effect);
                }

                case ET_Color:
                {
                    PrintToChat(client, "%s Your hat color is now \x04%s", MSG_PREFIX, effect);
                    Format(g_sColor[client], MAX_NAME_LENGTH, effect);
                    SetClientCookie(client, g_hActiveColor, effect);
                }
            }

            PrintToChat(client, "%s It will become active when you change your hat or class", MSG_PREFIX);
        }
    }
}
