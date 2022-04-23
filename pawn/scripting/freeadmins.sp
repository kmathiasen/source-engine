#include <sourcemod>

#pragma semicolon 1

#define TEAM_SPEC 1

new String:g_sFreeAdminPath[PLATFORM_MAX_PATH];
new String:g_sIP[MAX_NAME_LENGTH];
new Handle:g_hFreeAdmin = INVALID_HANDLE;


/* ----- Events ----- */


public OnPluginStart()
{
    BuildPath(Path_SM,
              g_sFreeAdminPath, sizeof(g_sFreeAdminPath),
              "configs/free_admins.txt");

    g_hFreeAdmin = CreateTrie();

    RegConsoleCmd("sm_reloadadmins", Command_ReloadAdmins);
    CreateTimer(2.5, RebuildFreeAdmins);
    CreateTimer(5.0, RebuildFreeAdmins);

    new ip = GetConVarInt(FindConVar("hostip"));
    Format(g_sIP, sizeof(g_sIP),
           "%d.%d.%d.%d",
           (ip & 0xFF000000) >> 24,
           (ip & 0x00FF0000) >> 16,
           (ip & 0x0000FF00) >> 8,
           (ip & 0x000000FF));
}

public OnRebuildAdminCache(AdminCachePart:part)
{
    CreateTimer(2.5, RebuildFreeAdmins);
    CreateTimer(10.0, RebuildFreeAdmins);
}

public OnClientPostAdminCheck(client)
{
    decl String:steamid[32];
    decl String:name[MAX_NAME_LENGTH];

    GetClientAuthString(client, steamid, sizeof(steamid));

    if (GetTrieString(g_hFreeAdmin, steamid, name, sizeof(name)))
        GivePlayerAdmin(name, steamid, "Free Admin [Gungame]", g_hFreeAdmin);
}

/* ----- Commands ----- */


public Action:Command_ReloadAdmins(client, args)
{
    if (!client)
        return Plugin_Continue;

    new bits = GetUserFlagBits(client);
    if (bits & ADMFLAG_ROOT || bits & ADMFLAG_CHANGEMAP)
    {
        CreateTimer(2.5, RebuildFreeAdmins);
        CreateTimer(10.0, RebuildFreeAdmins);
    }

    return Plugin_Continue;
}


/* ----- Callbacks ----- */


public EmptyCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
        LogError(error);
}

/* ----- Functions ----- */


stock GivePlayerAdmin(const String:name[], const String:steamid[], const String:group[], Handle:trie)
{
    new AdminId:admin = INVALID_ADMIN_ID;
    SetTrieString(trie, steamid, name);

    if ((admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamid)) != INVALID_ADMIN_ID)
    {
        AdminInheritGroup(admin, FindAdmGroup(group));
        return;
    }

    admin = CreateAdmin(name);
    if (!BindAdminIdentity(admin, AUTHMETHOD_STEAM, steamid))
    {
        LogError("%s can't bind identity (%s)", name, steamid);
        return;
    }

    AdminInheritGroup(admin, FindAdmGroup(group));
}

public Action:RebuildFreeAdmins(Handle:timer)
{
    new Handle:oFile = OpenFile(g_sFreeAdminPath, "r");
    new String:line[MAX_NAME_LENGTH * 2 + 4];

    while (ReadFileLine(oFile, line, sizeof(line)))
    {
        new String:sParts[3][MAX_NAME_LENGTH];
        TrimString(line);

        if (StrEqual(line, ""))
            continue;

        ExplodeString(line, " - ", sParts, 3, MAX_NAME_LENGTH);

        if (StrEqual(sParts[2], "") || StrEqual(sParts[2], g_sIP))
        {
            GivePlayerAdmin(sParts[0], sParts[1], "Free Admin [Gungame]", g_hFreeAdmin);
        }
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            RunAdminCacheChecks(i);
    }

    CloseHandle(oFile);
}

