
// ###################### GLOBALS ######################

new Handle:g_hClientTModel = INVALID_HANDLE;
new Handle:g_hClientCTModel = INVALID_HANDLE;

new String:g_sDefaultModel[2][PLATFORM_MAX_PATH] = {"", ""};
new String:g_sPublicModel[2][PLATFORM_MAX_PATH] = {"", ""};
new String:g_sPlayerModelNames[MAXPLAYERS + 1][2][LEN_NAMES];

new Handle:g_hPlayerModels[MAXPLAYERS + 1];
new Handle:g_hPlayerModelPaths = INVALID_HANDLE;
new Handle:g_hModelTeam = INVALID_HANDLE;
new Handle:g_hSkinIds = INVALID_HANDLE;

// ###################### EVENTS ######################


stock Models_OnPluginStart()
{
    // Register client cookies.
    g_hClientTModel = RegClientCookie("hg_premium_tmodel",
                                      "Terrorist Premium Model",
                                      CookieAccess_Protected);

    g_hClientCTModel = RegClientCookie("hg_premium_ctmodel",
                                      "Counter-Terrorist Premium Model",
                                      CookieAccess_Protected);

    g_hPlayerModelPaths = CreateTrie();
    g_hModelTeam = CreateTrie();
    g_hSkinIds = CreateTrie();

    // Register Commands.
    RegConsoleCmd("sm_models", Command_Models, "Open up HG Items model menu.");
    RegConsoleCmd("sm_model", Command_Models, "Open up HG Items model menu.");
}

stock Models_OnDBConnect()
{
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT name, filepath, filepath_ct, default_model, public_model, skinid FROM items WHERE (servertype & %d) and (type = %d) and (servertype > 0)",
           g_iServerType, ITEMTYPE_MODEL);

    SQL_TQuery(g_hDbConn, LoadModelsCallback, query);
}

stock Models_OnClientDisconnect(client)
{
    if (g_hPlayerModels[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hPlayerModels[client]);
        g_hPlayerModels[client] = INVALID_HANDLE;
    }
}

stock Models_OnClientFullyAuthorized(client)
{
    g_hPlayerModels[client] = CreateArray(ByteCountToCells(LEN_NAMES));

    // Using new over decl here 'cause I don't know if GetClientCookie
    //  will set the string to "" if it isn't set for that client

    new String:tModelName[LEN_NAMES];
    new String:ctModelName[LEN_NAMES];
    decl String:dummy[8];

    GetClientCookie(client, g_hClientTModel, tModelName, sizeof(tModelName));
    GetClientCookie(client, g_hClientCTModel, ctModelName, sizeof(ctModelName));

    g_sPlayerModelNames[client][0][0] = '\0';
    g_sPlayerModelNames[client][1][0] = '\0';

    if (tModelName[0] != '\0' &&
        GetTrieString(g_hPlayerModelPaths, tModelName, dummy, sizeof(dummy)))
        Format(g_sPlayerModelNames[client][TEAM_T - 2], LEN_NAMES, tModelName);

    if (ctModelName[0] != '\0' &&
        GetTrieString(g_hPlayerModelPaths, ctModelName, dummy, sizeof(dummy)))
        Format(g_sPlayerModelNames[client][TEAM_CT - 2], LEN_NAMES, ctModelName);
}

stock Models_OnPlayerSpawn(client)
{
    new team_index = GetClientTeam(client) - 2;
    decl String:path[PLATFORM_MAX_PATH];

    if (team_index < 0)
        return;

    if (!g_bClientEquippedItem[client][Item_StealthMode] &&
        g_sPlayerModelNames[client][team_index][0] != '\0' &&
        IsAuthed(client, g_sPlayerModelNames[client][team_index], false) &&
        GetTrieString(g_hPlayerModelPaths,
                      g_sPlayerModelNames[client][team_index],
                      path, sizeof(path)))
        SetPlayerModel(client, path, g_sPlayerModelNames[client][team_index]);

    else if (GetUserFlagBits(client) &&
             g_sDefaultModel[team_index][0] != '\0' &&
             GetTrieString(g_hPlayerModelPaths,
                           g_sDefaultModel[team_index],
                           path, sizeof(path)))
        SetPlayerModel(client, path, g_sDefaultModel[team_index]);

    else if (g_sPublicModel[team_index][0] != '\0' &&
             GetTrieString(g_hPlayerModelPaths,
                           g_sPublicModel[team_index],
                           path, sizeof(path)))
             SetPlayerModel(client, path, g_sPublicModel[team_index]);

    else if (g_sPublicModel[team_index][0] != '\0' &&
            GetTrieString(g_hPlayerModelPaths,
                          g_sPublicModel[team_index],
                          path, sizeof(path)))
            SetPlayerModel(client, path, g_sPublicModel[team_index]);
}


// ###################### Callbacks ######################


public Action:Command_Models(client, args)
{
    if (IsAuthed(client))
        BuildModelMenu(client);
    return Plugin_Handled;
}

public ModelMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                MainMenu(client);
        }

        case MenuAction_Select:
        {
            new team_index = GetClientTeam(client) - 2;
            new model_team;

            if (team_index < 0)
            {
                PrintToChat(client, "%s You aren't on a team.", MSG_PREFIX);
                return;
            }

            decl String:modelName[LEN_NAMES];

            GetMenuItem(menu, selected, modelName, sizeof(modelName));
            GetTrieValue(g_hModelTeam, modelName, model_team);

            if (StrContains(modelName, " [Active]") > -1 || 
                StrContains(modelName, " [Default]") > -1)
            {
                Format(g_sPlayerModelNames[client][team_index],
                       LEN_NAMES,
                       g_sDefaultModel[team_index]);

                SetClientCookie(client,
                                team_index ? g_hClientCTModel : g_hClientTModel,
                                g_sDefaultModel[team_index]);
            }

            else
            {
                Format(g_sPlayerModelNames[client][model_team - 2],
                       LEN_NAMES,
                       modelName);

                SetClientCookie(client,
                                model_team - 2 ? g_hClientCTModel : g_hClientTModel,
                                modelName);
            }

            FakeClientCommand(client, "sm_models");
        }
    }
}


// ###################### Functions ######################


stock BuildModelMenu(client)
{
    new bool:any;
    new Handle:menu = CreateMenu(ModelMenuSelect);
    new team_index = GetClientTeam(client) - 2;
    new model_team;

    SetMenuTitle(menu, "Choose Your Model");
    SetMenuExitBackButton(menu, true);

    decl String:display[LEN_NAMES + 10];     // Enough for " [Active]"
    decl String:model[LEN_NAMES];

    for (new i = 0; i < GetArraySize(g_hPlayerModels[client]); i++)
    {
        GetArrayString(g_hPlayerModels[client], i, model, sizeof(model));
    
        GetTrieValue(g_hModelTeam, model, model_team);
        if (model_team - 2 != team_index)
            continue;

        any = true;

        if (StrEqual(model, g_sDefaultModel[team_index]))
                Format(display, sizeof(display), "%s [Default]", model);

        else if (StrEqual(model, g_sPlayerModelNames[client][team_index]))
            Format(display, sizeof(display), "%s [Active]", model);

        else
            Format(display, sizeof(display), model);

        AddMenuItem(menu, display, display);
    }

    if (!any)
    {
        AddMenuItem(menu, "", "NO MODELS FOUND", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "For the team you are on", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Type !shop", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Or press back twice", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "And select shop", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "To purchase models", ITEMDRAW_DISABLED);
    }

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

stock SetPlayerModel(client, const String:model[], const String:modelname[])
{
    if (CanUseModel(client, model))
    {
        PrecacheModel(model);
        SetEntityModel(client, model);

        new skinid;
        GetTrieValue(g_hSkinIds, modelname, skinid);

        if (skinid > 0)
            SetEntProp(client, Prop_Send, "m_nSkin", skinid);

        g_bCanUseHats[client] = true;
    }
}


// ###################### Callbacks ######################


public LoadModelsCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!CheckConnection(hndl, error))
        return;

    decl String:name[LEN_NAMES];
    decl String:filepath[PLATFORM_MAX_PATH];
    decl String:filepath_ct[PLATFORM_MAX_PATH];

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, name, sizeof(name));
        SQL_FetchString(hndl, 1, filepath, sizeof(filepath));
        SQL_FetchString(hndl, 2, filepath_ct, sizeof(filepath_ct));

        new default_model = SQL_FetchInt(hndl, 3);
        new public_model = SQL_FetchInt(hndl, 4);
        new skinid = SQL_FetchInt(hndl, 5);

        SetTrieValue(g_hSkinIds, name, skinid);

        if (!StrEqual(filepath, ""))
        {
            SetTrieValue(g_hModelTeam, name, TEAM_T);
            SetTrieString(g_hPlayerModelPaths, name, filepath);

            if (default_model)
                Format(g_sDefaultModel[TEAM_T - 2], LEN_NAMES, name);
    
            if (public_model)
                Format(g_sPublicModel[TEAM_T - 2], LEN_NAMES, name);
        }

        else
        {
            SetTrieValue(g_hModelTeam, name, TEAM_CT);
            SetTrieString(g_hPlayerModelPaths, name, filepath_ct);

            if (default_model)
                Format(g_sDefaultModel[TEAM_CT - 2], LEN_NAMES, name);
    
            if (public_model)
                Format(g_sPublicModel[TEAM_CT - 2], LEN_NAMES, name);
        }
    }
}
