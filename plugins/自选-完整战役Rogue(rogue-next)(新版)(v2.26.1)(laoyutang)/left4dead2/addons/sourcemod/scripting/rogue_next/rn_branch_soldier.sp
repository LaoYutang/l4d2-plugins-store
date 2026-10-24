#if defined _rn_branch_soldier_included
 #endinput
#endif
#define _rn_branch_soldier_included

/** 逐武器保存弹夹奖励；拥有者和完整生命周期防止丢枪转交后继承。 */
enum struct RN_BranchSoldierWeapon
{
    int ref;
    int client;
    int serial;
    int life;
    int run;
    int map;
    int branch;
    int clip;
    bool clipKnown;
    int reserve;
    int capacity;
    int sampleTick;
    int command;
    bool pendingReload;
    bool observedReload;
    bool reloadCommitted;
    int reloadClip;
    int pendingFires;
    float magazineFactor;
    int shotTick;
    int shotCommand;
    bool shotBeforeEvent;
    float shotFactor;
}
ArrayList g_BranchSoldier_Weapons;
int g_BranchSoldier_Command[MAXPLAYERS + 1];
int g_BranchSoldier_Buttons[MAXPLAYERS + 1];

/** 比例直接映射为独立倍率；不读取上一个弹夹已经获得的倍率。 */
float RN_BranchSoldier_ReloadFactor(int remaining, int capacity)
{
    if (capacity <= 0 || remaining < 0 || remaining > capacity) return 1.0;
    return 1.0 + float(remaining) / float(capacity);
}

/** 容量只读当前武器脚本，双持手枪使用其真实双倍弹夹。 */
int RN_BranchSoldier_Capacity(int weapon)
{
    char name[64];
    GetEntityClassname(weapon, name, sizeof(name));
    int capacity = L4D2_GetIntWeaponAttribute(name, L4D2IWA_ClipSize);
    if (StrEqual(name, "weapon_pistol") && HasEntProp(weapon, Prop_Send, "m_isDualWielding")
        && GetEntProp(weapon, Prop_Send, "m_isDualWielding") != 0)
    {
        if (capacity > RN_MAX_INT / 2) return 0;
        capacity *= 2;
    }
    return capacity;
}

/** 备用弹量只作为实际装入的独立证据，不从开火后的空夹反猜末弹。 */
int RN_BranchSoldier_Reserve(int client, int weapon)
{
    if (!HasEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType")
        || !HasEntProp(client, Prop_Send, "m_iAmmo")) return -1;
    int ammo = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    // L4D2的m_iAmmo为32项；失效的外部弹药类型不允许越界读取。
    if (ammo < 0 || ammo >= 32) return -1;
    return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammo);
}

/** 仅普通十八种枪械并要求当前拥有者；不修改弹夹容量或弹药。 */
bool RN_BranchSoldier_Source(int client, int weapon)
{
    int branch = RN_Branch_Get(client);
    return (branch == RN_BRANCH_TACTIC || branch == RN_BRANCH_FINALE)
        && IsPlayerAlive(client) && !RN_Common_Incapacitated(client)
        && RN_Weapons_Index(weapon) >= 0
        && HasEntProp(weapon, Prop_Send, "m_iClip1")
        && HasEntProp(weapon, Prop_Send, "m_hOwnerEntity")
        && GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == client;
}

/** 记录仅在同一枪、同一人和同一生命有效，切换仍持有的枪不会删除奖励。 */
bool RN_BranchSoldier_Valid(RN_BranchSoldierWeapon state)
{
    int weapon = EntRefToEntIndex(state.ref), client = state.client;
    return RN_Common_Client(client) && state.serial == GetClientSerial(client)
        && state.life == g_Common_Life[client] && state.run == g_Run_Epoch
        && state.map == g_Run_MapEpoch && state.branch == RN_Branch_Get(client)
        && RN_BranchSoldier_Source(client, weapon);
}

/** 惰性删除已失效的武器记录；只为拥有分支且实际使用的枪创建记录。 */
int RN_BranchSoldier_Find(int client, int weapon, bool create = true)
{
    if (!RN_BranchSoldier_Source(client, weapon)) return -1;
    if (g_BranchSoldier_Weapons == null)
    {
        if (!create) return -1;
        g_BranchSoldier_Weapons = new ArrayList(sizeof(RN_BranchSoldierWeapon));
    }
    RN_BranchSoldierWeapon state;
    int ref = EntIndexToEntRef(weapon);
    for (int index = g_BranchSoldier_Weapons.Length - 1; index >= 0; index--)
    {
        g_BranchSoldier_Weapons.GetArray(index, state, sizeof(state));
        if (!RN_BranchSoldier_Valid(state))
        {
            g_BranchSoldier_Weapons.Erase(index);
            continue;
        }
        if (state.ref == ref && state.client == client) return index;
    }
    if (!create) return -1;
    RN_BranchSoldierWeapon empty;
    state = empty;
    state.ref = ref;
    state.client = client;
    state.serial = GetClientSerial(client);
    state.life = g_Common_Life[client];
    state.run = g_Run_Epoch;
    state.map = g_Run_MapEpoch;
    state.branch = RN_Branch_Get(client);
    state.clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
    state.clipKnown = true;
    state.reserve = RN_BranchSoldier_Reserve(client, weapon);
    state.capacity = RN_BranchSoldier_Capacity(weapon);
    state.magazineFactor = 1.0;
    state.shotFactor = 1.0;
    state.sampleTick = -1;
    state.shotTick = -1;
    return g_BranchSoldier_Weapons.PushArray(state, sizeof(state));
}

/** 只捕获一次换弹起点；逐发装填中的重复事件不能不断改写剩弹比例。 */
void RN_BranchSoldier_BeginReload(RN_BranchSoldierWeapon state)
{
    if (state.pendingReload) return;
    int weapon = EntRefToEntIndex(state.ref);
    if (weapon <= MaxClients || !IsValidEntity(weapon)) return;
    state.capacity = RN_BranchSoldier_Capacity(weapon);
    if (state.clip < 0 || state.capacity <= 0 || state.clip >= state.capacity) return;
    state.pendingReload = true;
    state.observedReload = false;
    state.reloadCommitted = false;
    state.reloadClip = state.clip;
    state.pendingFires = 0;
    state.reserve = RN_BranchSoldier_Reserve(state.client, weapon);
}

/** 只有原枪实际补入弹药才提交新比例，未完成或取消不覆盖旧奖励。 */
void RN_BranchSoldier_Observe(RN_BranchSoldierWeapon state, int clip, bool reloading)
{
    // 上个命令已经完成时，实际弹量加上真实开火次数可证明被射掉的补入弹药。
    bool loaded = state.pendingReload && (clip > state.reloadClip
        || (state.pendingFires > 0 && clip >= 0 && clip <= RN_MAX_INT - state.pendingFires
            && clip + state.pendingFires > state.reloadClip));
    if (loaded)
    {
        state.reloadCommitted = true;
        if (state.branch == RN_BRANCH_TACTIC)
            state.magazineFactor = RN_BranchSoldier_ReloadFactor(state.reloadClip, state.capacity);
    }
    if (state.pendingReload)
    {
        if (reloading) state.observedReload = true;
        else if (state.observedReload || clip >= state.capacity || state.pendingFires > 0)
        {
            state.pendingReload = false;
            state.observedReload = false;
            state.pendingFires = 0;
        }
    }
    state.clip = clip;
    state.clipKnown = true;
}

/** 同一命令内先补弹再开火时，先兑现真实补弹，绝不能先清换弹事务。 */
void RN_BranchSoldier_SyncShot(RN_BranchSoldierWeapon state, int weapon)
{
    if (!state.pendingReload) return;
    int actual = GetEntProp(weapon, Prop_Send, "m_iClip1");
    int reserve = RN_BranchSoldier_Reserve(state.client, weapon);
    int inserted = state.reserve >= 0 && reserve >= 0 && reserve < state.reserve
        ? state.reserve - reserve : 0;
    bool loaded = false;
    if (inserted > 0 && state.clip >= 0 && inserted <= state.capacity - state.clip
        && (actual == state.clip + inserted || actual == state.clip + inserted - 1))
    {
        // 备用弹量减少证明装入数量，事件发生在扣弹前/后均能恢复本发开火前弹量。
        state.clip += inserted;
        state.clipKnown = true;
        loaded = true;
    }
    else if (actual > state.clip)
    {
        state.clip = actual;
        // 无备用弹证据时，满夹值可证明尚未扣弹；其余值不能区分扣弹前/后。
        state.clipKnown = actual == state.capacity;
        loaded = true;
    }
    if (loaded)
    {
        state.reloadCommitted = true;
        if (state.branch == RN_BRANCH_TACTIC)
            state.magazineFactor = RN_BranchSoldier_ReloadFactor(state.reloadClip, state.capacity);
        // 该命令可能已经查询过旧弹夹，任何旧快照都必须重新固定。
        state.shotTick = -1;
        state.shotBeforeEvent = false;
    }
    else if (!state.reloadCommitted && state.clip == 1 && actual == 1
        && state.observedReload && HasEntProp(weapon, Prop_Send, "m_bInReload")
        && GetEntProp(weapon, Prop_Send, "m_bInReload") == 0)
    {
        // 装一发即开火与取消换弹在此观测完全相同，不把旧余弹1认作新夹末弹。
        if (state.clipKnown)
        {
            state.shotTick = -1;
            state.shotBeforeEvent = false;
        }
        state.clipKnown = false;
    }
    state.reserve = reserve;
}

/** 每个真实命令在引擎动作前采样；无分支、无枪和无效生命不读取弹药属性。 */
void RN_BranchSoldier_Command(int client, int buttons)
{
    if (client < 1 || client > MaxClients || !RN_Common_Client(client)) return;
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    int index = RN_BranchSoldier_Find(client, weapon);
    if (index < 0) return;
    RN_BranchSoldierWeapon state;
    g_BranchSoldier_Weapons.GetArray(index, state, sizeof(state));
    int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
    bool reloading = HasEntProp(weapon, Prop_Send, "m_bInReload")
        && GetEntProp(weapon, Prop_Send, "m_bInReload") != 0;
    RN_BranchSoldier_Observe(state, clip, reloading);
    state.reserve = RN_BranchSoldier_Reserve(client, weapon);
    if ((buttons & IN_RELOAD) != 0 && (g_BranchSoldier_Buttons[client] & IN_RELOAD) == 0)
        RN_BranchSoldier_BeginReload(state);
    if (g_BranchSoldier_Command[client] == RN_MAX_INT) g_BranchSoldier_Command[client] = 0;
    state.command = ++g_BranchSoldier_Command[client];
    state.sampleTick = GetGameTickCount();
    g_BranchSoldier_Buttons[client] = buttons;
    g_BranchSoldier_Weapons.SetArray(index, state, sizeof(state));
}

/** 原生换弹事件兼容自动换弹，实际装入检查仍由后续采样统一完成。 */
public void RN_BranchSoldier_OnReload(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Client(client)) return;
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    int index = RN_BranchSoldier_Find(client, weapon);
    if (index < 0) return;
    RN_BranchSoldierWeapon state;
    g_BranchSoldier_Weapons.GetArray(index, state, sizeof(state));
    // 本事件尚未补入弹药，读取此刻的真实余弹而不借用上次倍率。
    state.clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
    state.clipKnown = true;
    RN_BranchSoldier_BeginReload(state);
    g_BranchSoldier_Weapons.SetArray(index, state, sizeof(state));
}

/** 开火时固定整发倍率；枪内多颗弹片和穿透命中复用这一份结果。 */
void RN_BranchSoldier_CaptureShot(RN_BranchSoldierWeapon state, bool beforeEvent)
{
    state.shotTick = GetGameTickCount();
    state.shotCommand = state.command;
    state.shotBeforeEvent = beforeEvent;
    state.shotFactor = state.branch == RN_BRANCH_TACTIC ? state.magazineFactor
        : (state.clipKnown && state.clip == 1 ? 1.5 : 1.0);
}

/** 真实开火划分每一发；伤害先到的引擎顺序只确认已有快照，不重新判定末弹。 */
public void RN_BranchSoldier_OnFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RN_Common_Client(client)) return;
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    int index = RN_BranchSoldier_Find(client, weapon);
    if (index < 0) return;
    RN_BranchSoldierWeapon state;
    g_BranchSoldier_Weapons.GetArray(index, state, sizeof(state));
    int tick = GetGameTickCount();
    // 命令前快照未知时不把开火后空夹误当作末弹，不猜测SDK回调先后。
    if (state.sampleTick != tick) return;
    RN_BranchSoldier_SyncShot(state, weapon);
    if (!(state.shotBeforeEvent && state.shotTick == tick && state.shotCommand == state.command))
        RN_BranchSoldier_CaptureShot(state, false);
    state.shotBeforeEvent = false;
    if (state.clip > 0) state.clip--;
    if (state.pendingReload && !state.reloadCommitted)
    {
        // 不可区分的同命令观测保留到下一个命令核对，不能整夹永久丢失奖励。
        if (state.pendingFires < RN_MAX_INT) state.pendingFires++;
    }
    else
    {
        state.pendingReload = false;
        state.observedReload = false;
        state.pendingFires = 0;
    }
    g_BranchSoldier_Weapons.SetArray(index, state, sizeof(state));
}

/** 只有直接枪伤调用此函数；本发固定倍率与其他增伤相乘一次。 */
float RN_BranchSoldier_Factor(int client, int weapon)
{
    int index = RN_BranchSoldier_Find(client, weapon, false);
    if (index < 0) return 1.0;
    RN_BranchSoldierWeapon state;
    g_BranchSoldier_Weapons.GetArray(index, state, sizeof(state));
    int tick = GetGameTickCount();
    if (state.sampleTick != tick) return 1.0;
    if (state.shotTick != tick || state.shotCommand != state.command)
    {
        // 已固定的同一发不能再次把尚未扣减的clip当成补入的新子弹。
        RN_BranchSoldier_SyncShot(state, weapon);
        if (state.clip <= 0)
        {
            g_BranchSoldier_Weapons.SetArray(index, state, sizeof(state));
            return 1.0;
        }
        RN_BranchSoldier_CaptureShot(state, true);
    }
    g_BranchSoldier_Weapons.SetArray(index, state, sizeof(state));
    return state.shotFactor;
}

/** 丢弃立刻撤销该枪记录，同一玩家随后捡回也不能绕过拥有权中断。 */
public void RN_BranchSoldier_OnDrop(int client, int weapon)
{
    if (g_BranchSoldier_Weapons == null || weapon <= MaxClients) return;
    RN_BranchSoldierWeapon state;
    int ref = EntIndexToEntRef(weapon);
    for (int index = g_BranchSoldier_Weapons.Length - 1; index >= 0; index--)
    {
        g_BranchSoldier_Weapons.GetArray(index, state, sizeof(state));
        if (state.ref == ref && state.client == client) g_BranchSoldier_Weapons.Erase(index);
    }
}

/** 生命、地图、停用或分支提交边界清除临时弹夹/开火记录，档案身份不变。 */
void RN_BranchSoldier_ResetClient(int client)
{
    if (client < 1 || client > MaxClients) return;
    if (g_BranchSoldier_Weapons != null)
    {
        RN_BranchSoldierWeapon state;
        for (int index = g_BranchSoldier_Weapons.Length - 1; index >= 0; index--)
        {
            g_BranchSoldier_Weapons.GetArray(index, state, sizeof(state));
            if (state.client == client) g_BranchSoldier_Weapons.Erase(index);
        }
    }
    g_BranchSoldier_Command[client] = 0;
    g_BranchSoldier_Buttons[client] = 0;
}

/** 全局清理释放容器；不存在遗留属性需要写回引擎。 */
void RN_BranchSoldier_Clear()
{
    delete g_BranchSoldier_Weapons;
    for (int client = 1; client <= MaxClients; client++)
    {
        g_BranchSoldier_Command[client] = 0;
        g_BranchSoldier_Buttons[client] = 0;
    }
}
