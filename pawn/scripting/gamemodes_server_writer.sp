#include <sourcemod>



public OnPluginStart()
{

}

stock WriteGameModesFile()
{
    /*
    decl String:sKeyName[MAX_NAME_LENGTH];
    decl String:title[MAX_NAME_LENGTH + 12];

    hKV = CreateKeyValues("gamemodes_server.txt");
    FileToKeyValues(hKV, "/gamemodes_server.txt");

    KvRewind(hKV);
    KvJumpToKey(hKV, "mapgroups");

    do
    {
        KvGetSectionName(hPerks, sKeyName, sizeof(sKeyName));

        Format(title, sizeof(title),
               "%s - %d", sKeyName, KvGetNum(hPerks, "cost"));

        AddMenuItem(hPerksMenu, sKeyName, title);
    } while (KvGotoNextKey(hPerks));
    */
    
    Might need to use SMC...
}


