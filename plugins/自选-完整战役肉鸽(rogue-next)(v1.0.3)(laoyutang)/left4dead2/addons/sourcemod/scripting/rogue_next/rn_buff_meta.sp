#if defined _rn_buff_meta_included
 #endinput
#endif
#define _rn_buff_meta_included

static const char g_Buff_Names[MAXBUFFENUM][] = {
  "",
  "先点到40",
  "奶一口",
  "弹药专家",
  "搞快点",
  "连射狂人",
  "认真一拳",
  "普通一拳",
  "因为怕痛",
  "下次一定",
  "破万法",
  "火之高兴",
  "霜之哀伤",
  "读档战神",
  "风行者",
  "罗烟步",
  "玻璃大炮",
  "纵火狂",
  "多冻症",
  "达摩之剑",
  "不动如山",
  "多宝仙人",
  "十连保底",
  "双生花",
  "生生不息",
  "天行健",
  "蛇形走位",
  "自在极意",
  "一键三连",
  "再来一瓶",
  "还有三杯",
  "辛辣天塞",
  "激发",
  "颠人",
  "致命一鸡",
  "哎呦喂",
  "剑圣",
  "幻影刺客",
  "强运",
  "招灾",
  "D4",
  "包甜吗",
  "三刀流",
  "界王拳",
  "繁星",
  "业力",
  "薄葬",
  "风光大葬"
};

static const int g_Buff_Rarities[MAXBUFFENUM] = {
  RARITY_COMMON,     // PLAYBUFF_NULL - 普通
  RARITY_COMMON,     // 先点到40 - 普通
  RARITY_COMMON,     // 奶一口 - 普通
  RARITY_COMMON,     // 弹药专家 - 普通
  RARITY_COMMON,     // 搞快点 - 普通
  RARITY_COMMON,     // 连射狂人 - 普通
  RARITY_RARE,       // 认真一拳 - 稀有
  RARITY_COMMON,     // 普通一拳 - 普通
  RARITY_COMMON,     // 因为怕痛 - 普通
  RARITY_COMMON,     // 下次一定 - 普通
  RARITY_LEGENDARY,  // 破万法 - 传说
  RARITY_COMMON,     // 火之高兴 - 普通
  RARITY_COMMON,     // 霜之哀伤 - 普通
  RARITY_RARE,       // 读档战神 - 稀有
  RARITY_EPIC,       // 风行者 - 史诗
  RARITY_RARE,       // 罗烟步 - 稀有
  RARITY_EPIC,       // 玻璃大炮 - 史诗
  RARITY_RARE,       // 纵火狂 - 稀有
  RARITY_RARE,       // 多冻症 - 稀有
  RARITY_LEGENDARY,  // 达摩之剑 - 传说
  RARITY_EPIC,       // 不动如山 - 史诗
  RARITY_RARE,       // 多宝仙人 - 稀有
  RARITY_EPIC,       // 十连保底 - 史诗
  RARITY_LEGENDARY,  // 双生花 - 传说
  RARITY_LEGENDARY,  // 生生不息 - 传说
  RARITY_EPIC,       // 天行健 - 史诗
  RARITY_RARE,       // 蛇形走位 - 稀有
  RARITY_EPIC,       // 自在极意 - 史诗
  RARITY_EPIC,       // 一键三连 - 史诗
  RARITY_RARE,       // 再来一瓶 - 稀有
  RARITY_EPIC,       // 还有三杯 - 史诗
  RARITY_LEGENDARY,  // 辛辣天塞 - 传说
  RARITY_RARE,       // 激发 - 稀有
  RARITY_LEGENDARY,  // 颠人 - 传说
  RARITY_COMMON,     // 致命一鸡 - 普通
  RARITY_RARE,       // 哎呦喂 - 稀有
  RARITY_COMMON,     // 剑圣 - 普通
  RARITY_RARE,       // 幻影刺客 - 稀有
  RARITY_EPIC,       // 强运 - 史诗
  RARITY_LEGENDARY,  // 招灾 - 传说
  RARITY_EPIC,       // D4 - 史诗
  RARITY_COMMON,     // 包甜吗 - 普通
  RARITY_RARE,       // 三刀流 - 稀有
  RARITY_LEGENDARY,  // 界王拳 - 传说
  RARITY_LEGENDARY,  // 繁星 - 传说
  RARITY_EPIC,       // 业力 - 史诗
  RARITY_RARE,       // 薄葬 - 稀有
  RARITY_EPIC        // 风光大葬 - 史诗
};

/** 返回固定BUFF名称；NULL及越界ID安全地显示空字符串。 */
void RN_Buff_Name(int buff, char[] name, int maxlength)
{
    strcopy(name, maxlength, buff > PLAYBUFF_NULL && buff < MAXBUFFENUM ? g_Buff_Names[buff] : "");
}

/** 稀有度是稳定元数据，不依赖配置或客户端状态。 */
int RN_Buff_Rarity(int buff)
{
    return buff >= 0 && buff < MAXBUFFENUM ? g_Buff_Rarities[buff] : RARITY_COMMON;
}

/** 资源及兑换卡不保存持续层数，避免查看和统计误算。 */
bool RN_Buff_Persistent(int buff)
{
    return buff > PLAYBUFF_NULL && buff < MAXBUFFENUM &&
        buff != PLAYBUFF_DUOBAOXIANREN && buff != PLAYBUFF_SHILENBAODI &&
        buff != PLAYBUFF_ZAILAIYIPING && buff != PLAYBUFF_HAIYOUSANBEI &&
        buff != PLAYBUFF_DIANREN && buff != PLAYBUFF_YUXI && buff != PLAYBUFF_FANXING;
}

/** 返回稀有度显示标记；文案统一由此方法渲染。 */
void RN_Buff_RarityText(int rarity, char[] text, int maxlength)
{
    static const char labels[][] = {"Ⅰ 普通", "Ⅱ 稀有", "Ⅲ 史诗", "Ⅳ 传说"};
    strcopy(text, maxlength, labels[rarity >= 0 && rarity < MAX_RARITY_LEVELS ? rarity : 0]);
}
