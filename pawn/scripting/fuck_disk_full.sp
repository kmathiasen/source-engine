#include <sourcemod>

#pragma semicolon 1

#define DELETE_AFTER 60 * 60 * 24 * 3

new Float:g_fStartTime;

new Handle:g_hExcludedNames = INVALID_HANDLE;
new Handle:g_hSearchDirectories = INVALID_HANDLE;

public OnPluginStart()
{
    g_hExcludedNames = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
    g_hSearchDirectories = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));

    PushArrayString(g_hExcludedNames, "admin_giveplayer.log");
    PushArrayString(g_hExcludedNames, "buymenu.log");
    PushArrayString(g_hExcludedNames, "gangchat.log");
    PushArrayString(g_hExcludedNames, "hg_premium.log");
    PushArrayString(g_hExcludedNames, "hg_premium_admingive.log");
    PushArrayString(g_hExcludedNames, "hg_premium_admingiveitems.log");
    PushArrayString(g_hExcludedNames, "hg_premium_give.log");
    PushArrayString(g_hExcludedNames, "macrodox.log");

    PushArrayString(g_hSearchDirectories, "/logs/");
    PushArrayString(g_hSearchDirectories, "/download/user_custom/");
    PushArrayString(g_hSearchDirectories, "/addons/sourcemod/logs/");
    PushArrayString(g_hSearchDirectories, "/addons/sourcemod/scripting/");

    Timer_DeleteShit(INVALID_HANDLE, 0);
    CreateTimer(3600.0, Timer_DeleteShit, _, TIMER_REPEAT);
}

public Action:Timer_DeleteShit(Handle:timer, any:data)
{
    g_fStartTime = GetEngineTime();

    decl String:dir[PLATFORM_MAX_PATH];

    for (new i = 0; i < GetArraySize(g_hSearchDirectories); i++)
    {
        GetArrayString(g_hSearchDirectories, i, dir, sizeof(dir));

        if (!Cleanup(dir, true))
            return Plugin_Continue;
    }

    return Plugin_Continue;
}

bool:Cleanup(const String:dir[], bool:first)
{
    new Handle:hDir = OpenDirectory(dir);
    new FileType:ftype;

    if (hDir == INVALID_HANDLE)
        return true;

    decl String:fp[PLATFORM_MAX_PATH];
    decl String:exclude[PLATFORM_MAX_PATH];

    while (ReadDirEntry(hDir, fp, sizeof(fp), ftype))
    {
        if (ftype == FileType_Directory)
        {
            if (StrEqual(fp, ".") || StrEqual(fp, ".."))
                continue;

            decl String:cat[PLATFORM_MAX_PATH];

            Format(cat, sizeof(cat), "%s/%s/", dir, fp);
            ReplaceString(cat, sizeof(cat), "//", "/");

            if (!Cleanup(cat, false))
            {
                CloseHandle(hDir);
                return false;
            }
        }
    
        else if (ftype == FileType_File)
        {
            new bool:del = true;

            for (new i = 0; i < GetArraySize(g_hExcludedNames); i++)
            {
                GetArrayString(g_hExcludedNames, i, exclude, sizeof(exclude));

                if (StrEqual(fp, exclude, false))
                {
                    del = false;
                    break;
                }
            }

            if (del)
            {
                decl String:cat[PLATFORM_MAX_PATH];

                Format(cat, sizeof(cat), "%s/%s", dir, fp);
                ReplaceString(cat, sizeof(cat), "//", "/");

                if (FileExists(cat) &&
                    GetTime() - GetFileTime(cat, FileTime_LastChange) > DELETE_AFTER)
                {
                    DeleteFile(cat);
                }
            }

            // Who knows how long deleting file could take.
            if (GetEngineTime() - g_fStartTime > 0.5)
            {
                CloseHandle(hDir);
                return false;
            }
        }
    }

    CloseHandle(hDir);
    hDir = OpenDirectory(dir);

    // Now delete the folder if there's nothing left
    // But only if it's not the original search directory
    if (!first)
    {
        new bool:del = true;
        while (ReadDirEntry(hDir, fp, sizeof(fp)))
        {
            if (!StrEqual(fp, ".") && !StrEqual(fp, ".."))
                del = false;
        }

        if (del)
        {
            RemoveDir(dir);
        }
    }

    CloseHandle(hDir);
    return true;
}

