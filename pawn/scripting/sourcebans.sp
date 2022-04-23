/**
* sourcebans.sp
*
* This file contains all Source Server Plugin Functions
* @author SourceBans Development Team
* @version 0.0.0.$Rev: 108 $
* @copyright InterWave Studios (www.interwavestudios.com)
* @package SourceBans
* @link http://www.sourcebans.net
*/

#pragma semicolon 1
#include <sourcemod>
#include <socket>
#include <sourcebans>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#define SB_VERSION "1.4.17hg"

#define UPDATE_FREQ 60.0

// Plugin Info
#define PLUGIN_VERSION "1.4.17"

// Updater
#define UPDATE_FILE "sourcebans"

#include "lib/updater.sp"
// End of Updater

//GLOBAL DEFINES
#define YELLOW				0x01
#define NAMECOLOR			0x02
#define TEAMCOLOR			0x03
#define GREEN				0x04

#define DISABLE_ADDBAN		1
#define DISABLE_UNBAN		2

//#define DEBUG

enum State /* ConfigState */
{
    ConfigStateNone = 0,
    ConfigStateConfig,
    ConfigStateReasons,
    ConfigStateHacking
}

new State:ConfigState;
new Handle:ConfigParser;

new const String:Prefix[] = "[SourceBans] ";

new String:ServerIp[24];
new String:ServerPort[7];
new String:DatabasePrefix[10] = "sb";
new String:WebsiteAddress[128];

/* Admin Stuff*/
new g_iCacheFlagBits[MAXPLAYERS + 1];
new String:g_iCacheAdminName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new AdminCachePart:loadPart;
new bool:loadAdmins;
new bool:loadGroups;
new bool:loadOverrides;
new curLoading=0;
new AdminFlag:g_FlagLetters[26];
new Handle:g_hRefreshTimer = INVALID_HANDLE;

/* Admin KeyValues */
new String:groupsLoc[128];
new String:adminsLoc[128];
new String:overridesLoc[128];
    
/* Cvar handle*/
new Handle:CvarHostIp;
new Handle:CvarPort;

/* Database handle */
new Handle:Database;
new Handle:SQLiteDB;

/* Menu file globals */
new Handle:ReasonMenuHandle;
new Handle:HackingMenuHandle;

/* Datapack and Timer handles */
new Handle:PlayerRecheck[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
new Handle:PlayerDataPack[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};

/* Player ban check status */
new bool:PlayerStatus[MAXPLAYERS + 1];

/* Disable of addban and unban */
new CommandDisable;
new bool:backupConfig = true;
new bool:enableAdmins = true;

/* Require a lastvisited from SB site */
new bool:requireSiteLogin = false;

/* Log Stuff */
new String:logFile[256];

/* Own Chat Reason */
new g_ownReasons[MAXPLAYERS+1] = {false, ...};

new Float:RetryTime = 15.0;
new bool:LateLoaded;
new bool:AutoAdd;
new bool:g_bConnecting = false;

new serverID = -1;

public Plugin:myinfo =
{
    name = "SourceBans",
    author = "SourceBans Development Team",
    description = "Advanced ban management for the Source engine",
    version = SB_VERSION,
    url = "http://www.sourcebans.net"
};

#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 3
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
#else
public bool:AskPluginLoad(Handle:myself, bool:late, String:error[], err_max)
#endif
{
    RegPluginLibrary("sourcebans");
    //CreateNative("SBBanPlayer", Native_SBBanPlayer);
    LateLoaded = late;
    
    #if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 3
        return APLRes_Success;
    #else
        return true;
    #endif
}

public OnPluginStart()
{	
    LoadTranslations("common.phrases");
    LoadTranslations("plugin.basecommands");
    LoadTranslations("sourcebans.phrases");
    LoadTranslations("basebans.phrases");
    loadAdmins = loadGroups = loadOverrides = false;
    
    CvarHostIp = FindConVar("hostip");
    CvarPort = FindConVar("hostport");
    CreateConVar("sb_version", SB_VERSION, _, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    RegServerCmd("sm_rehash",sm_rehash,"Reload SQL admins");
    //RegAdminCmd("sm_ban", CommandBan, ADMFLAG_BAN, "sm_ban <#userid|name> <minutes|0> [reason]", "sourcebans");
    //RegAdminCmd("sm_banip", CommandBanIp, ADMFLAG_BAN, "sm_banip <ip|#userid|name> <time> [reason]", "sourcebans");
    //RegAdminCmd("sm_addban", CommandAddBan, ADMFLAG_RCON, "sm_addban <time> <steamid> [reason]", "sourcebans");
    //RegAdminCmd("sm_unban", CommandUnban, ADMFLAG_UNBAN, "sm_unban <steamid|ip> [reason]", "sourcebans");
    RegAdminCmd("sb_reload",
                _CmdReload,
                ADMFLAG_RCON,
                "Reload sourcebans config and ban reason menu options",
                "sourcebans");
    
    //RegConsoleCmd("say", ChatHook);
    //RegConsoleCmd("say_team", ChatHook);
    
    g_FlagLetters['a'-'a'] = Admin_Reservation;
    g_FlagLetters['b'-'a'] = Admin_Generic;
    g_FlagLetters['c'-'a'] = Admin_Kick;
    g_FlagLetters['d'-'a'] = Admin_Ban;
    g_FlagLetters['e'-'a'] = Admin_Unban;
    g_FlagLetters['f'-'a'] = Admin_Slay;
    g_FlagLetters['g'-'a'] = Admin_Changemap;
    g_FlagLetters['h'-'a'] = Admin_Convars;
    g_FlagLetters['i'-'a'] = Admin_Config;
    g_FlagLetters['j'-'a'] = Admin_Chat;
    g_FlagLetters['k'-'a'] = Admin_Vote;
    g_FlagLetters['l'-'a'] = Admin_Password;
    g_FlagLetters['m'-'a'] = Admin_RCON;
    g_FlagLetters['n'-'a'] = Admin_Cheats;
    g_FlagLetters['o'-'a'] = Admin_Custom1;
    g_FlagLetters['p'-'a'] = Admin_Custom2;
    g_FlagLetters['q'-'a'] = Admin_Custom3;
    g_FlagLetters['r'-'a'] = Admin_Custom4;
    g_FlagLetters['s'-'a'] = Admin_Custom5;
    g_FlagLetters['t'-'a'] = Admin_Custom6;
    g_FlagLetters['z'-'a'] = Admin_Root;
    
    
    BuildPath(Path_SM, logFile, sizeof(logFile), "logs/sourcebans.log");
    g_bConnecting = true;
    
    // Catch config error and show link to FAQ
    if(!SQL_CheckConfig("sourcebans"))
    {
        if(ReasonMenuHandle != INVALID_HANDLE)
            CloseHandle(ReasonMenuHandle);
        if(HackingMenuHandle != INVALID_HANDLE)
            CloseHandle(HackingMenuHandle);
        LogToFile(logFile, "Database failure: Could not find Database conf \"sourcebans\". See FAQ: http://sourcebans.net/node/19");
        SetFailState("Database failure: Could not find Database conf \"sourcebans\"");
        return;
    }
    SQL_TConnect(GotDatabase, "sourcebans");
    
    BuildPath(Path_SM,groupsLoc,sizeof(groupsLoc),"configs/admin_groups.cfg");
    
    BuildPath(Path_SM,adminsLoc,sizeof(adminsLoc),"configs/admins.cfg");
    
    BuildPath(Path_SM,overridesLoc,sizeof(overridesLoc),"configs/sourcebans/overrides_backup.cfg");
    
    InitializeBackupDB();
    
    // This timer is what processes the SQLite queue when the database is unavailable
    //CreateTimer(float(ProcessQueueTime * 60), ProcessQueue);
    
    /* Account for late loading */
    if(LateLoaded)
    {
        decl String:auth[30];
        for(new i = 1; i <= GetMaxClients(); i++)
        {
            if(IsClientConnected(i) && !IsFakeClient(i))
            {
                PlayerStatus[i] = false;
            }
            if(IsClientInGame(i) && IsClientAuthorized(i) && !IsFakeClient(i))
            {
                GetClientAuthString(i, auth, sizeof(auth));
                //OnClientAuthorized(i, auth);
            }
        }
    }

    // Initialize Updater
    InitializeUpdater();
}

public Action:RefreshAdmins(Handle:timer)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        g_iCacheFlagBits[i] = 0;

        if (IsClientInGame(i))
        {
            new AdminId:admin = GetUserAdmin(i);
            if (admin != INVALID_ADMIN_ID)
            {
                g_iCacheFlagBits[i] = GetUserFlagBits(i);
                GetAdminUsername(admin, g_iCacheAdminName[i], MAX_NAME_LENGTH);
            }
        }
    }

    ServerCommand("sm_reloadadmins");

    // Setup repeating refresh admins from db.
    if (g_hRefreshTimer == INVALID_HANDLE)
        g_hRefreshTimer = CreateTimer(UPDATE_FREQ, RefreshAdmins, _, TIMER_REPEAT);
    return Plugin_Continue;
}

public OnConfigsExecuted()
{
    decl String:filename[200];
    BuildPath(Path_SM, filename, sizeof(filename), "plugins/basebans.smx");
    if(FileExists(filename))
    {
        decl String:newfilename[200];
        BuildPath(Path_SM, newfilename, sizeof(newfilename), "plugins/disabled/basebans.smx");
        ServerCommand("sm plugins unload basebans");
        if(FileExists(newfilename))
            DeleteFile(newfilename);
        RenameFile(newfilename, filename);
        LogToFile(logFile, "plugins/basebans.smx was unloaded and moved to plugins/disabled/basebans.smx");
    }

    // This timer will reload admins every N seconds.
    CreateTimer(UPDATE_FREQ, RefreshAdmins);
}

public OnMapStart()
{
    ResetSettings();
}

public OnMapEnd()
{
    for(new i = 0; i <= MaxClients; i++)
    {
        if(PlayerDataPack[i] != INVALID_HANDLE)
        {
            /* Need to close reason pack */
            CloseHandle(PlayerDataPack[i]);
            PlayerDataPack[i] = INVALID_HANDLE;
        }
    }
}

// CLIENT CONNECTION FUNCTIONS //

public Action:OnClientPreAdminCheck(client)
{
    if(!Database)
        return Plugin_Continue;
    
    if(GetUserAdmin(client) != INVALID_ADMIN_ID)
        return Plugin_Continue;
    
    if (curLoading > 0)
        return Plugin_Handled;
    
    return Plugin_Continue;
}

public OnClientDisconnect(client)
{
    if(PlayerRecheck[client] != INVALID_HANDLE)
    {
        KillTimer(PlayerRecheck[client]);
        PlayerRecheck[client] = INVALID_HANDLE;
    }
    g_ownReasons[client] = false;
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
    PlayerStatus[client] = false;
    return true;
}

public OnRebuildAdminCache(AdminCachePart:part)
{
    loadPart = part;
    switch(loadPart)
    {
        case AdminCache_Overrides:
            loadOverrides = true;
        case AdminCache_Groups:
            loadGroups = true;
        case AdminCache_Admins:
        {
            loadAdmins = true;

            for (new i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i) || IsFakeClient(i) || g_iCacheFlagBits[i] == 0)
                    continue;

                new AdminId:admin = INVALID_ADMIN_ID;
                decl String:steamid[32];

                GetClientAuthString(i, steamid, sizeof(steamid));
                if ((admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamid)) == INVALID_ADMIN_ID)
                {
                    admin = CreateAdmin(g_iCacheAdminName[i]);
                }

                if (!BindAdminIdentity(admin, AUTHMETHOD_STEAM, steamid))
                {
                    LogError("%s can't bind identity (%s)", g_iCacheAdminName[i], steamid);
                    continue;
                }

                new AdminFlag:flag;
                new bit;

                for (new b = 0; b < 31; b++)
                {
                    bit = 1 << b;
                    if (g_iCacheFlagBits[i] & bit && BitToFlag(bit, flag))
                    {
                        SetAdminFlag(admin, flag, true);
                    }
                }
    
                RunAdminCacheChecks(i);
            }
        }
    }
    if(Database == INVALID_HANDLE) {
        if(!g_bConnecting) {
            g_bConnecting = true;
            SQL_TConnect(GotDatabase,"sourcebans");
        }
    }
    else {
        GotDatabase(Database,Database,"",0);
    }
}

// COMMAND CODE //

public Action:_CmdReload(client, args)
{
    ResetSettings();
    return Plugin_Handled;
}

public Action:sm_rehash(args)
{
    if(enableAdmins)
        DumpAdminCache(AdminCache_Groups,true);
    DumpAdminCache(AdminCache_Overrides, true);
    return Plugin_Handled;   
}



// MENU CODE //

stock ResetMenu()
{
    if(ReasonMenuHandle != INVALID_HANDLE)
    {
        RemoveAllMenuItems(ReasonMenuHandle);
    }
}

// QUERY CALL BACKS //

public GotDatabase(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        LogToFile(logFile, "Database failure: %s. See FAQ: http://www.sourcebans.net/node/20", error);
        g_bConnecting = false;
        
        // Parse the overrides backup!
        ParseBackupConfig_Overrides();
        return;
    }

    Database = hndl;

    decl String:query[1024];
    FormatEx(query, sizeof(query), "SET NAMES \"UTF8\"");
    SQL_TQuery(Database, ErrorCheckCallback, query);

    InsertServerInfo();

    //CreateTimer(900.0, PruneBans);

    if(loadOverrides)
    {
        Format(query, 1024, "SELECT type, name, flags FROM %s_overrides", DatabasePrefix);
        SQL_TQuery(Database, OverridesDone, query);
        loadOverrides = false;
    }

    if(loadGroups && enableAdmins)
    {
        FormatEx(query,1024,"SELECT name, flags, immunity, groups_immune   \
                    FROM %s_srvgroups ORDER BY id",DatabasePrefix);
        curLoading++;
        SQL_TQuery(Database,GroupsDone,query);
        
#if defined DEBUG
    LogToFile(logFile, "Fetching Group List");
#endif
        loadGroups = false;
    }

    if(loadAdmins && enableAdmins)
    {
        new String:queryLastLogin[50] = "";

        if (requireSiteLogin)
            queryLastLogin = "lastvisit IS NOT NULL AND lastvisit != '' AND";

        if( serverID == -1 )
        {
            FormatEx(query,2048,"SELECT authid, srv_password, (SELECT srvg.name FROM %s_admins as aa \
                            INNER JOIN %s_admins_servers_groups as gg ON (aa.aid=gg.admin_id) \
                            INNER JOIN %s_srvgroups as srvg ON (gg.group_id=srvg.id) \
                            WHERE srvg.flags != '' \
                            AND authid = a.authid \
                            AND (gg.server_id = (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0,1)  \
                                OR gg.srv_group_id = ANY (SELECT group_id FROM %s_servers_groups WHERE server_id = (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0,1))) \
                            ORDER BY srvg.power DESC LIMIT 1) AS srv_group, srv_flags, user, immunity \
                        FROM %s_admins_servers_groups AS asg \
                        LEFT JOIN %s_admins AS a ON a.aid = asg.admin_id \
                        WHERE %s (server_id = (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0,1) \
                            OR srv_group_id = ANY (SELECT group_id FROM %s_servers_groups WHERE server_id = (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0,1))) \
                        GROUP BY authid",
                    DatabasePrefix, DatabasePrefix, DatabasePrefix, DatabasePrefix, ServerIp, ServerPort, DatabasePrefix, DatabasePrefix, ServerIp, ServerPort,
                    DatabasePrefix, DatabasePrefix, queryLastLogin, DatabasePrefix, ServerIp, ServerPort,DatabasePrefix, DatabasePrefix, ServerIp, ServerPort);
        }else{
            FormatEx(query,2048,"SELECT authid, srv_password, (SELECT srvg.name FROM %s_admins as aa \
                            INNER JOIN %s_admins_servers_groups as gg ON (aa.aid=gg.admin_id) \
                            INNER JOIN %s_srvgroups as srvg ON (gg.group_id=srvg.id) \
                            WHERE srvg.flags != '' \
                            AND authid = a.authid \
                            AND (gg.server_id = %d \
                                OR gg.srv_group_id = ANY (SELECT group_id FROM %s_servers_groups WHERE server_id = %d)) \
                            ORDER BY srvg.power DESC LIMIT 1) AS srv_group, srv_flags, user, immunity \
                        FROM %s_admins_servers_groups AS asg \
                        LEFT JOIN %s_admins AS a ON a.aid = asg.admin_id \
                        WHERE %s server_id = %d  \
                        OR srv_group_id = ANY (SELECT group_id FROM %s_servers_groups WHERE server_id = %d) \
                        GROUP BY authid",
                    DatabasePrefix, DatabasePrefix, DatabasePrefix, serverID, DatabasePrefix, serverID,
                    DatabasePrefix, DatabasePrefix, queryLastLogin, serverID, DatabasePrefix, serverID);
        }
        curLoading++;
        SQL_TQuery(Database,AdminsDone,query);

#if defined DEBUG
        LogToFile(logFile, "Fetching Admin List");
        LogToFile(logFile, query);
#endif
        loadAdmins = false;
    }
    g_bConnecting = false;
}

public ServerInfoCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if(error[0])
    {
        LogToFile(logFile, "Server Select Query Failed: %s", error);
        return;
    }

    if(hndl	== INVALID_HANDLE || SQL_GetRowCount(hndl)==0)
    {	
        // get the game folder name used to determine the mod
        decl String:desc[64], String:query[200];
        GetGameFolderName(desc, sizeof(desc));
        FormatEx(query, sizeof(query), "INSERT INTO %s_servers (ip, port, rcon, modid) VALUES ('%s', '%s', '', (SELECT mid FROM %s_mods WHERE modfolder = '%s'))", DatabasePrefix, ServerIp, ServerPort, DatabasePrefix, desc);
        SQL_TQuery(Database, ErrorCheckCallback, query);
    }
}

public ErrorCheckCallback(Handle:owner, Handle:hndle, const String:error[], any:data)
{
    if(error[0])
    {
        LogToFile(logFile, "Query Failed: %s", error);
    }
}

public AdminsDone(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    //SELECT authid, srv_password , srv_group, srv_flags, user
    if (hndl == INVALID_HANDLE || strlen(error) > 0)
    {
        --curLoading;
        CheckLoadAdmins();
        LogToFile(logFile, "Failed to retrieve admins from the database, %s", error);
        return;
    }
    decl String:authType[] = "steam";
    decl String:identity[66];
    decl String:password[66];
    decl String:groups[256];
    decl String:flags[32];
    decl String:name[66];
    new admCount=0;
    new Immunity=0;
    new AdminId:curAdm = INVALID_ADMIN_ID;
    new Handle:adminsKV = CreateKeyValues("Admins");
    
    while (SQL_MoreRows(hndl))
    {
        SQL_FetchRow(hndl);
        if(SQL_IsFieldNull(hndl, 0))
            continue;  // Sometimes some rows return NULL due to some setups
            
        SQL_FetchString(hndl,0,identity,66);
        SQL_FetchString(hndl,1,password,66);
        SQL_FetchString(hndl,2,groups,256);
        SQL_FetchString(hndl,3,flags,32);
        SQL_FetchString(hndl,4,name,66);

        Immunity = SQL_FetchInt(hndl,5);
        
        TrimString(name);
        TrimString(identity);
        TrimString(groups);
        TrimString(flags);

        // Disable writing to file if they chose to
        if(backupConfig)
        {
            KvJumpToKey(adminsKV, name, true);
            
            KvSetString(adminsKV, "auth", authType);
            KvSetString(adminsKV, "identity", identity);
            
            if(strlen(flags) > 0)
                KvSetString(adminsKV, "flags", flags);
            
            if(strlen(groups) > 0)
                KvSetString(adminsKV, "group", groups);
        
            if(strlen(password) > 0)
                KvSetString(adminsKV, "password", password);
            
            if(Immunity > 0)
                KvSetNum(adminsKV, "immunity", Immunity);
            
            KvRewind(adminsKV);
        }
        
        // find or create the admin using that identity
        if((curAdm = FindAdminByIdentity(authType, identity)) == INVALID_ADMIN_ID)
        {
            curAdm = CreateAdmin(name);
            // That should never happen!
            if(!BindAdminIdentity(curAdm, authType, identity))
            {
                LogToFile(logFile, "Unable to bind admin %s to identity %s", name, identity);
                RemoveAdmin(curAdm);
                continue;
            }
        }
        
#if defined DEBUG
        LogToFile(logFile, "Given %s (%s) admin", name, identity);
#endif
        
        new curPos = 0;
        new GroupId:curGrp = INVALID_GROUP_ID;
        new numGroups;
        decl String:iterGroupName[64];
        
        // Who thought this comma seperated group parsing would be a good idea?!
        /*
        decl String:grp[64];
        new nextPos = 0;
        while ((nextPos = SplitString(groups[curPos],",",grp,64)) != -1)
        {
            curPos += nextPos;
            curGrp = FindAdmGroup(grp);
            if (curGrp == INVALID_GROUP_ID)
            {
                LogToFile(logFile, "Unknown group \"%s\"",grp);
            }
            else
            {
                // Check, if he's not in the group already.
                numGroups = GetAdminGroupCount(curAdm);
                for(new i=0;i<numGroups;i++)
                {
                    GetAdminGroup(curAdm, i, iterGroupName, sizeof(iterGroupName));
                    // Admin is already part of the group, so don't try to inherit its permissions.
                    if(StrEqual(iterGroupName, grp))
                    {
                        numGroups = -2;
                        break;
                    }
                }
                // Only try to inherit the group, if it's a new one.
                if (numGroups != -2 && !AdminInheritGroup(curAdm,curGrp))
                {
                    LogToFile(logFile, "Unable to inherit group \"%s\"",grp);
                }
            }
        }*/
        
        if (strcmp(groups[curPos], "") != 0)
        {
            curGrp = FindAdmGroup(groups[curPos]);
            if (curGrp == INVALID_GROUP_ID)
            {
                LogToFile(logFile, "Unknown group \"%s\"",groups[curPos]);
            }
            else
            {
                // Check, if he's not in the group already.
                numGroups = GetAdminGroupCount(curAdm);
                for(new i=0;i<numGroups;i++)
                {
                    GetAdminGroup(curAdm, i, iterGroupName, sizeof(iterGroupName));
                    // Admin is already part of the group, so don't try to inherit its permissions.
                    if(StrEqual(iterGroupName, groups[curPos]))
                    {
                        numGroups = -2;
                        break;
                    }
                }
                
                // Only try to inherit the group, if it's a new one.
                if (numGroups != -2 && !AdminInheritGroup(curAdm,curGrp))
                {
                    LogToFile(logFile, "Unable to inherit group \"%s\"",groups[curPos]);
                }
                
                if (GetAdminImmunityLevel(curAdm) < Immunity)
                {
                    SetAdminImmunityLevel(curAdm, Immunity);
                }
#if defined DEBUG
                LogToFile(logFile, "Admin %s (%s) has %d immunity", name, identity, Immunity);
#endif
            }
        }
        
        if (strlen(password) > 0)
            SetAdminPassword(curAdm, password);
        
        for (new i=0;i<strlen(flags);++i)
        {
            if (flags[i] < 'a' || flags[i] > 'z')
                continue;
                
            if (g_FlagLetters[flags[i] - 'a'] < Admin_Reservation)
                continue;
                
            SetAdminFlag(curAdm, g_FlagLetters[flags[i] - 'a'], true);
        }
        ++admCount;
    }
    
    if(backupConfig)
        KeyValuesToFile(adminsKV, adminsLoc);
    CloseHandle(adminsKV);
    
#if defined DEBUG
    LogToFile(logFile, "Finished loading %i admins.",admCount);
#endif
    
    --curLoading;
    CheckLoadAdmins();
}

public GroupsDone(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        curLoading--;
        CheckLoadAdmins();
        LogToFile(logFile, "Failed to retrieve groups from the database, %s",error);
        return;
    }
    decl String:grpName[128], String:immuneGrpName[128];
    decl String:grpFlags[32];
    new Immunity;
    new grpCount = 0;
    new Handle:groupsKV = CreateKeyValues("Groups");
    
    new GroupId:curGrp = INVALID_GROUP_ID;
    while (SQL_MoreRows(hndl))
    {
        SQL_FetchRow(hndl);
        if(SQL_IsFieldNull(hndl, 0))
            continue;  // Sometimes some rows return NULL due to some setups
        SQL_FetchString(hndl,0,grpName,128);
        SQL_FetchString(hndl,1,grpFlags,32);
        Immunity = SQL_FetchInt(hndl,2);
        SQL_FetchString(hndl,3,immuneGrpName,128);

        TrimString(grpName);
        TrimString(grpFlags);
        TrimString(immuneGrpName);
        
        // Ignore empty rows..
        if(!strlen(grpName))
            continue;
        
        curGrp = CreateAdmGroup(grpName);
        
        if(backupConfig)
        {
            KvJumpToKey(groupsKV, grpName, true);
            if(strlen(grpFlags) > 0)
                KvSetString(groupsKV, "flags", grpFlags);
            if(Immunity > 0)
                KvSetNum(groupsKV, "immunity", Immunity);
            
            KvRewind(groupsKV);
        }
        
        if (curGrp == INVALID_GROUP_ID)
        {   //This occurs when the group already exists
            curGrp = FindAdmGroup(grpName);   
        }
        
        for (new i=0;i<strlen(grpFlags);++i)
        {
            if (grpFlags[i] < 'a' || grpFlags[i] > 'z')
                continue;
                
            if (g_FlagLetters[grpFlags[i] - 'a'] < Admin_Reservation)
                continue;
                
            SetAdmGroupAddFlag(curGrp, g_FlagLetters[grpFlags[i] - 'a'], true);
        }
        
        // Set the group immunity.
        if(Immunity > 0)
        {
            SetAdmGroupImmunityLevel(curGrp, Immunity);
            #if defined DEBUG
            LogToFile(logFile, "Group %s has %d immunity", grpName, Immunity);
            #endif
        }
        
        grpCount++;
    }
    
    if(backupConfig)
        KeyValuesToFile(groupsKV, groupsLoc);
    CloseHandle(groupsKV);
    
    #if defined DEBUG
    LogToFile(logFile, "Finished loading %i groups.",grpCount);
    #endif
    
    // Load the group overrides
    decl String:query[512];
    FormatEx(query, 512, "SELECT sg.name, so.type, so.name, so.access FROM %s_srvgroups_overrides so LEFT JOIN %s_srvgroups sg ON sg.id = so.group_id ORDER BY sg.id", DatabasePrefix, DatabasePrefix);
    SQL_TQuery(Database, LoadGroupsOverrides, query);
    
    /*if (reparse)
    {
        decl String:query[512];
        FormatEx(query,512,"SELECT name, immunity, groups_immune FROM %s_srvgroups ORDER BY id",DatabasePrefix);
        SQL_TQuery(Database,GroupsSecondPass,query);
    }
    else
    {
        curLoading--;
        CheckLoadAdmins();
    }*/
}

// Reparse to apply inherited immunity
public GroupsSecondPass(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        curLoading--;
        CheckLoadAdmins();
        LogToFile(logFile, "Failed to retrieve groups from the database, %s",error);
        return;
    }
    decl String:grpName[128], String:immunityGrpName[128];
    
    new GroupId:curGrp = INVALID_GROUP_ID;
    new GroupId:immuneGrp = INVALID_GROUP_ID;
    while (SQL_MoreRows(hndl))
    {
        SQL_FetchRow(hndl);
        if(SQL_IsFieldNull(hndl, 0))
            continue;  // Sometimes some rows return NULL due to some setups
        
        SQL_FetchString(hndl,0,grpName,128);
        TrimString(grpName);
        if(strlen(grpName) == 0)
            continue;

        SQL_FetchString(hndl, 2, immunityGrpName, sizeof(immunityGrpName));
        TrimString(immunityGrpName);
        
        curGrp = FindAdmGroup(grpName);
        if (curGrp == INVALID_GROUP_ID)
            continue;
        
        immuneGrp = FindAdmGroup(immunityGrpName);
        if (immuneGrp == INVALID_GROUP_ID)
            continue;
        
        SetAdmGroupImmuneFrom(curGrp, immuneGrp);
        
        #if defined DEBUG
        LogToFile(logFile, "Group %s inhertied immunity from group %s", grpName, immunityGrpName);
        #endif
    }
    --curLoading;
    CheckLoadAdmins();
}

public LoadGroupsOverrides(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        curLoading--;
        CheckLoadAdmins();
        LogToFile(logFile, "Failed to retrieve group overrides from the database, %s",error);
        return;
    }
    decl String:sGroupName[128], String:sType[16], String:sCommand[64], String:sAllowed[16];
    decl OverrideRule:iRule, OverrideType:iType;

    new Handle:groupsKV = CreateKeyValues("Groups");
    FileToKeyValues(groupsKV, groupsLoc);
    
    new GroupId:curGrp = INVALID_GROUP_ID;
    while (SQL_MoreRows(hndl))
    {
        SQL_FetchRow(hndl);
        if(SQL_IsFieldNull(hndl, 0))
            continue;  // Sometimes some rows return NULL due to some setups
        
        SQL_FetchString(hndl, 0, sGroupName,sizeof(sGroupName));
        TrimString(sGroupName);
        if(strlen(sGroupName) == 0)
            continue;
        
        SQL_FetchString(hndl, 1, sType, sizeof(sType));
        SQL_FetchString(hndl, 2, sCommand, sizeof(sCommand));
        SQL_FetchString(hndl, 3, sAllowed, sizeof(sAllowed));
        
        curGrp = FindAdmGroup(sGroupName);
        if (curGrp == INVALID_GROUP_ID)
            continue;
        
        iRule = StrEqual(sAllowed,"allow") ? Command_Allow         : Command_Deny;
        iType = StrEqual(sType,   "group") ? Override_CommandGroup : Override_Command;
        
        #if defined DEBUG
        PrintToServer("AddAdmGroupCmdOverride(%i, %s, %i, %i)", curGrp, sCommand, iType, iRule);
        #endif
        
        // Save overrides into admin_groups.cfg backup
        if(KvJumpToKey(groupsKV, sGroupName))
        {
            KvJumpToKey(groupsKV, "Overrides", true);
            if(iType == Override_Command)
                KvSetString(groupsKV, sCommand, sAllowed);
            else
            {
                Format(sCommand, sizeof(sCommand), "@%s", sCommand);
                KvSetString(groupsKV, sCommand, sAllowed);
            }
            KvRewind(groupsKV);
        }
        
        AddAdmGroupCmdOverride(curGrp, sCommand, iType, iRule);
    }
    curLoading--;
    CheckLoadAdmins();
    
    if(backupConfig)
        KeyValuesToFile(groupsKV, groupsLoc);
    CloseHandle(groupsKV);
}

public OverridesDone(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        LogToFile(logFile, "Failed to retrieve overrides from the database, %s",error);
        ParseBackupConfig_Overrides();
        return;
    }
    
    new Handle:hKV = CreateKeyValues("SB_Overrides");
    
    decl String:sFlags[32], String:sName[64], String:sType[64];
    while(SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, sType, sizeof(sType));
        SQL_FetchString(hndl, 1, sName, sizeof(sName));
        SQL_FetchString(hndl, 2, sFlags, sizeof(sFlags));
        
        // KeyValuesToFile won't add that key, if the value is ""..
        if(sFlags[0] == '\0')
        {
            sFlags[0] = ' ';
            sFlags[1] = '\0';
        }
        
        #if defined DEBUG
        LogToFile(logFile, "Adding override (%s, %s, %s)", sType, sName, sFlags);
        #endif
        
        if(StrEqual(sType, "command"))
        {
            AddCommandOverride(sName, Override_Command,      ReadFlagString(sFlags));
            KvJumpToKey(hKV, "override_commands", true);
            KvSetString(hKV, sName, sFlags);
            KvGoBack(hKV);
        }
        else if(StrEqual(sType, "group"))
        {
            AddCommandOverride(sName, Override_CommandGroup, ReadFlagString(sFlags));
            KvJumpToKey(hKV, "override_groups", true);
            KvSetString(hKV, sName, sFlags);
            KvGoBack(hKV);
        }
    }
    
    KvRewind(hKV);
    
    if(backupConfig)
        KeyValuesToFile(hKV, overridesLoc);
    CloseHandle(hKV);
}

// TIMER CALL BACKS //

public Action:ClientRecheck(Handle:timer, any:client)
{
    if(!PlayerStatus[client] && IsClientConnected(client))
    {
        decl String:Authid[64];
        GetClientAuthString(client, Authid, sizeof(Authid));
        //OnClientAuthorized(client, Authid);
    }

    PlayerRecheck[client] =  INVALID_HANDLE;
    return Plugin_Stop;
}

// PARSER //

static InitializeConfigParser()
{
    if (ConfigParser == INVALID_HANDLE)
    {
        ConfigParser = SMC_CreateParser();
        SMC_SetReaders(ConfigParser, ReadConfig_NewSection, ReadConfig_KeyValue, ReadConfig_EndSection);
    }
}

static InternalReadConfig(const String:path[])
{
    ConfigState = ConfigStateNone;

    new SMCError:err = SMC_ParseFile(ConfigParser, path);

    if (err != SMCError_Okay)
    {
        decl String:buffer[64];
        if (SMC_GetErrorString(err, buffer, sizeof(buffer)))
        {
            PrintToServer(buffer);
        } else {
            PrintToServer("Fatal parse error");
        }
    }
}

public SMCResult:ReadConfig_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
    if(name[0])
    {
        if(strcmp("Config", name, false) == 0)
        {
            ConfigState = ConfigStateConfig;
        } else if(strcmp("BanReasons", name, false) == 0) {
            ConfigState = ConfigStateReasons;
        } else if(strcmp("HackingReasons", name, false) == 0) {
            ConfigState = ConfigStateHacking;
        }
    }
    return SMCParse_Continue;
}

public SMCResult:ReadConfig_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
    if(!key[0])
        return SMCParse_Continue;

    switch(ConfigState)
    {
        case ConfigStateConfig:
        {
            if(strcmp("website", key, false) == 0)
            {
                strcopy(WebsiteAddress, sizeof(WebsiteAddress), value);
            } else if(strcmp("Addban", key, false) == 0) 
            {
                if(StringToInt(value) == 0)
                {
                    CommandDisable |= DISABLE_ADDBAN;
                }
            }
            else if(strcmp("AutoAddServer", key, false) == 0)
            {
                if(StringToInt(value) == 1)
                    AutoAdd = true;
                else
                    AutoAdd = false;
            } else if(strcmp("Unban", key, false) == 0) 
            {
                if(StringToInt(value) == 0)
                {
                    CommandDisable |= DISABLE_UNBAN;
                }
            }
            else if(strcmp("DatabasePrefix", key, false) == 0) 
            {
                strcopy(DatabasePrefix, sizeof(DatabasePrefix), value);

                if(DatabasePrefix[0] == '\0')
                {
                    DatabasePrefix = "sb";
                }
            } 
            else if(strcmp("RetryTime", key, false) == 0) 
            {
                RetryTime	= StringToFloat(value);
                if(RetryTime < 15.0)
                {
                    RetryTime = 15.0;
                } else if(RetryTime > 60.0) {
                    RetryTime = 60.0;
                }
            } 
            else if(strcmp("BackupConfigs", key, false) == 0)
            {
                if(StringToInt(value) == 1)
                    backupConfig = true;
                else
                    backupConfig = false;
            }
            else if(strcmp("EnableAdmins", key, false) == 0)
            {
                if(StringToInt(value) == 1)
                    enableAdmins = true;
                else
                    enableAdmins = false;
            }
            else if(strcmp("RequireSiteLogin", key, false) == 0)
            {
                if(StringToInt(value) == 1)
                    requireSiteLogin = true;
                else
                    requireSiteLogin = false;
            }
            else if(strcmp("ServerID", key, false) == 0)
            {
                serverID = StringToInt(value);
            }
        }

        case ConfigStateReasons:
        {
            if(ReasonMenuHandle != INVALID_HANDLE)
            {
                AddMenuItem(ReasonMenuHandle, key, value);
            }
        }
        case ConfigStateHacking:
        {
            if(HackingMenuHandle != INVALID_HANDLE)
            {
                AddMenuItem(HackingMenuHandle, key, value);
            }
        }
    }
    return SMCParse_Continue;
}

public SMCResult:ReadConfig_EndSection(Handle:smc)
{
    return SMCParse_Continue;
}


/*********************************************************
 * Ban Player from server
 *
 * @param client	The client index of the player to ban
 * @param time		The time to ban the player for (in minutes, 0 = permanent)
 * @param reason	The reason to ban the player from the server
 * @noreturn		
 *********************************************************/

// STOCK FUNCTIONS //

public InitializeBackupDB()
{
    decl String:error[255];
    SQLiteDB = SQLite_UseDatabase("sourcebans-queue", error, sizeof(error));
    if(SQLiteDB == INVALID_HANDLE)
        SetFailState(error);
    
    SQL_LockDatabase(SQLiteDB);
    SQL_FastQuery(SQLiteDB, "CREATE TABLE IF NOT EXISTS queue (steam_id TEXT PRIMARY KEY ON CONFLICT REPLACE, time INTEGER, start_time INTEGER, reason TEXT, name TEXT, ip TEXT, admin_id TEXT, admin_ip TEXT);");
    SQL_UnlockDatabase(SQLiteDB);
}

stock CheckLoadAdmins()
{
    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && IsClientAuthorized(i))
        {
            RunAdminCacheChecks(i);
            NotifyPostAdminCheck(i);
        }
    }    
}

stock InsertServerInfo()
{
    if(Database == INVALID_HANDLE)
    {
        return;
    }
    
    decl String:query[100], pieces[4];
    new longip = GetConVarInt(CvarHostIp);
    pieces[0] = (longip >> 24) & 0x000000FF;
    pieces[1] = (longip >> 16) & 0x000000FF;
    pieces[2] = (longip >> 8) & 0x000000FF;
    pieces[3] = longip & 0x000000FF;
    FormatEx(ServerIp, sizeof(ServerIp), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
    GetConVarString(CvarPort, ServerPort, sizeof(ServerPort));
    
    if(AutoAdd != false)
    {
        FormatEx(query, sizeof(query), "SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s'", DatabasePrefix, ServerIp, ServerPort);
        SQL_TQuery(Database, ServerInfoCallback, query);
    }
}

stock ReadConfig()
{
    InitializeConfigParser();

    if (ConfigParser == INVALID_HANDLE)
    {
        return;
    }

    decl String:ConfigFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFile, sizeof(ConfigFile), "configs/sourcebans/sourcebans.cfg");

    if(FileExists(ConfigFile))
    {
        InternalReadConfig(ConfigFile);
        PrintToServer("%sLoading configs/sourcebans.cfg config file", Prefix);
    } else {
        decl String:Error[PLATFORM_MAX_PATH + 64];
        FormatEx(Error, sizeof(Error), "%sFATAL *** ERROR *** can not find %s", Prefix, ConfigFile);
        LogToFile(logFile, "FATAL *** ERROR *** can not find %s", ConfigFile);
        SetFailState(Error);
    }
}

stock ResetSettings()
{
    CommandDisable = 0;

    ResetMenu();
    ReadConfig();
}

stock ParseBackupConfig_Overrides()
{
    new Handle:hKV = CreateKeyValues("SB_Overrides");
    if(!FileToKeyValues(hKV, overridesLoc))
        return;
    
    if(!KvGotoFirstSubKey(hKV))
        return;
    
    decl String:sSection[16], String:sFlags[32], String:sName[64];
    decl OverrideType:type;
    do
    {
        KvGetSectionName(hKV, sSection, sizeof(sSection));
        if(StrEqual(sSection, "override_commands"))
            type = Override_Command;
        else if(StrEqual(sSection, "override_groups"))
            type = Override_CommandGroup;
        else
            continue;
            
        if(KvGotoFirstSubKey(hKV, false))
        {
            do
            {
                KvGetSectionName(hKV, sName, sizeof(sName));
                KvGetString(hKV, NULL_STRING, sFlags, sizeof(sFlags));
                AddCommandOverride(sName, type, ReadFlagString(sFlags));
                #if defined _DEBUG
                PrintToServer("Adding override (%s, %s, %s)", sSection, sName, sFlags);
                #endif
            } while (KvGotoNextKey(hKV, false));
            KvGoBack(hKV);
        }
    }
    while(KvGotoNextKey(hKV));
    CloseHandle(hKV);
}

//Yarr!