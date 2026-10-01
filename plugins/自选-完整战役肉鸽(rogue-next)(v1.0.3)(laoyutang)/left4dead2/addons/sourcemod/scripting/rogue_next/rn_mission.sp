#if defined _rn_mission_included
 #endinput
#endif
#define _rn_mission_included

/** 在游戏虚拟文件系统中解析coop战役；每个KV/目录句柄都在本调用内释放。 */
bool RN_Mission_Resolve(const char[] current, char[] mission, int missionLength,
                        char[] firstMap, int firstLength, int &chapter)
{
    DirectoryListing directory = OpenDirectory("missions", true);
    if (directory == null) return false;
    char filename[PLATFORM_MAX_PATH], path[PLATFORM_MAX_PATH];
    bool found;
    while (!found && directory.GetNext(filename, sizeof(filename)))
    {
        int length = strlen(filename);
        if (length < 5 || !StrEqual(filename[length - 4], ".txt", false)) continue;
        FormatEx(path, sizeof(path), "missions/%s", filename);
        KeyValues kv = new KeyValues("");
        if (!kv.ImportFromFile(path) || !kv.JumpToKey("modes") ||
            !kv.JumpToKey("coop") || !kv.GotoFirstSubKey())
        {
            delete kv;
            continue;
        }
        char map[PLATFORM_MAX_PATH], first[PLATFORM_MAX_PATH];
        int position;
        do
        {
            kv.GetString("Map", map, sizeof(map), "");
            if (!RN_Common_SafeMapName(map)) continue;
            position++;
            if (position == 1) strcopy(first, sizeof(first), map);
            if (StrEqual(map, current, false))
            {
                found = true;
                chapter = position;
                strcopy(mission, missionLength, filename);
                strcopy(firstMap, firstLength, first);
            }
        }
        while (!found && kv.GotoNextKey());
        delete kv;
    }
    delete directory;
    return found && RN_Common_SafeMapName(firstMap);
}

/** 只有确认过关且同战役的紧接下一章节保留；首图、手动换图建立新局。 */
bool RN_Mission_Continue(bool known, const char[] mission, const char[] firstMap, int chapter)
{
    if (!g_Run_HasCampaign || !g_Run_Transition || g_Run_Phase != RN_TRANSITION) return false;
    if (!known)
    {
        LogError("[rogue-next] 正常过关但无法识别mission，保留本次成长；当前地图%s。", g_Run_Map);
        return !StrEqual(g_Run_Map, g_Run_FirstMap, false);
    }
    return StrEqual(mission, g_Run_Mission, false) && !StrEqual(g_Run_Map, firstMap, false) &&
        (g_Run_Chapter < 0 || chapter == g_Run_Chapter + 1);
}

/** 失败重启目标优先使用快照首图；实际changelevel前仍需再次验证。 */
bool RN_Mission_RestartMap(char[] target, int maxlength)
{
    if (RN_Common_SafeMapName(g_Run_FirstMap) && IsMapValid(g_Run_FirstMap))
    {
        strcopy(target, maxlength, g_Run_FirstMap);
        return true;
    }
    if (IsMapValid("c1m1_hotel"))
    {
        strcopy(target, maxlength, "c1m1_hotel");
        LogError("[rogue-next] 首图元数据无效，失败重启回退c1m1_hotel。");
        return true;
    }
    LogError("[rogue-next] 首图和默认回退地图均不可用；等待地图管理员处理。");
    return false;
}

