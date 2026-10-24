#if defined _rn_sword_damage_included
 #endinput
#endif
#define _rn_sword_damage_included

int g_Sword_DamageVictim, g_Sword_DamageOwner;

/** 内部SDK作用域只跳过本插件重复加成，外部SDKHooks仍正常执行。 */
bool RN_Sword_Internal(int victim, int attacker, int inflictor, int weapon, int type)
{
    return victim == g_Sword_DamageVictim && attacker == g_Sword_DamageOwner && victim > 0
        && inflictor == attacker && weapon == -1 && (type & DMG_SLASH) != 0;
}

/** EntRef、玩家serial及生命共同识别目标，死亡复活不会沿用旧刀命中。 */
void RN_Sword_TargetKey(int ref, int life, int serial, char[] key, int maxlength)
{
    FormatEx(key, maxlength, "%d:%d:%d", ref, life, serial);
}

/** 剑气独立验证目标生命，近战命中不会排除同一目标或返还剑气名额。 */
int RN_Sword_ContactTarget(RN_SwordContact contact)
{
    int target = EntRefToEntIndex(contact.ref);
    if (!RN_Sword_Enemy(target) || (target <= MaxClients &&
        (contact.serial != GetClientSerial(target) || contact.life != g_Common_Life[target]))) return -1;
    return target;
}

/** 仅清理尚未结算且已失效的接触；已支付的剑气名额不因近战或目标死亡返还。 */
void RN_Sword_Prune(int slot, float now)
{
    RN_SwordContact contact;
    for (int i = g_Sword_Waves[slot].contacts.Length - 1; i >= 0; i--)
    {
        g_Sword_Waves[slot].contacts.GetArray(i, contact, sizeof(contact));
        if (RN_Sword_ContactTarget(contact) == -1) g_Sword_Waves[slot].contacts.Erase(i);
    }
    if (g_Sword_Waves[slot].waiting && g_Sword_Waves[slot].hitCount
        + g_Sword_Waves[slot].contacts.Length < g_Sword_Waves[slot].maxHits)
    {
        g_Sword_Waves[slot].waiting = false;
        g_Sword_Waves[slot].updated = now;
    }
}

/** 当前扫掠步保存独立剑气接触，按目标去重且遮挡只排除本弧段。 */
void RN_Sword_Contact(int slot, int target, const float impact[3], bool visible, int segment)
{
    RN_SwordContact contact;
    contact.ref = EntIndexToEntRef(target);
    if (target <= MaxClients) { contact.life = g_Common_Life[target]; contact.serial = GetClientSerial(target); }
    contact.impact = impact;
    char key[64];
    RN_Sword_TargetKey(contact.ref, contact.life, contact.serial, key, sizeof(key));
    if (visible) g_Sword_Waves[slot].seen.SetValue(key, 1);
    else
    {
        char blocked[72];
        FormatEx(blocked, sizeof(blocked), "%s:%d", key, segment);
        g_Sword_Waves[slot].blocked.SetValue(blocked, 1);
    }
    if (visible && RN_Sword_ContactTarget(contact) != -1
        && g_Sword_Waves[slot].contacts.Length < RN_SWORD_CONTACT_LIMIT)
        g_Sword_Waves[slot].contacts.PushArray(contact, sizeof(contact));
}

/** 接触所在扫掠步立即结算，不等待攻击截止时间；每次SDK后核对身份与槽位。 */
void RN_Sword_Resolve(int slot, float now)
{
    RN_SwordWave wave;
    wave = g_Sword_Waves[slot];
    RN_SwordContact contact;
    while (g_Sword_Waves[slot].contacts.Length > 0 && g_Sword_Waves[slot].hitCount < wave.maxHits)
    {
        g_Sword_Waves[slot].contacts.GetArray(0, contact, sizeof(contact));
        g_Sword_Waves[slot].contacts.Erase(0);
        int target = RN_Sword_ContactTarget(contact);
        if (target == -1) continue;
        float damage = wave.damage;
        if (damage <= 0.0) continue;
        damage *= RN_Combat_CriticalRoll(wave.critChance, wave.critMultiplier);
        damage *= RN_Disaster_DamageFactor(false);
        if (!RN_Math_Finite(damage) || damage <= 0.0) continue;
        g_Sword_Waves[slot].hitCount++;
        int oldVictim = g_Sword_DamageVictim, oldOwner = g_Sword_DamageOwner;
        g_Sword_DamageVictim = target;
        g_Sword_DamageOwner = wave.identity.client;
        SDKHooks_TakeDamage(target, wave.identity.client, wave.identity.client, damage, DMG_SLASH, -1,
            NULL_VECTOR, contact.impact, false);
        g_Sword_DamageVictim = oldVictim;
        g_Sword_DamageOwner = oldOwner;
        if (g_Sword_Waves[slot].token != wave.token) return;
        if (!RN_Sword_Valid(slot, wave.token)) { RN_Sword_Stop(slot); return; }
    }
    if (g_Sword_Waves[slot].hitCount >= wave.maxHits || g_Sword_Waves[slot].finished)
        RN_Sword_Stop(slot);
    else RN_Sword_Prune(slot, now);
}
