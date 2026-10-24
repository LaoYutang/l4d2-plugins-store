#if defined _rn_math_included
 #endinput
#endif
#define _rn_math_included

/** 拒绝NaN/Infinity；位级判定不依赖引擎原生函数，便于离线执行测试。 */
bool RN_Math_Finite(float value)
{
    return (view_as<int>(value) & 0x7F800000) != 0x7F800000;
}

/** 仅舍入显示：整数输出小数位，避免SourceMod浮点格式截断；不改实际效果。 */
void RN_Math_NumberText(float value, char[] text, int maxlength, int decimals = 1, bool trim = false)
{
    if (!RN_Math_Finite(value)) { strcopy(text, maxlength, "无效"); return; }
    if (decimals < 0) decimals = 0;
    if (decimals > 2) decimals = 2;
    float magnitude = FloatAbs(value);
    // 该范围float32已没有小数位，不做越界的浮点转整数或缩放。
    if (magnitude >= RN_INT_FLOAT_LIMIT)
    {
        FormatEx(text, maxlength, "%.0f", value);
        if (!trim && decimals > 0) StrCat(text, maxlength, decimals == 1 ? ".0" : ".00");
        return;
    }
    int scale = decimals == 2 ? 100 : (decimals == 1 ? 10 : 1);
    int whole = RoundToFloor(magnitude);
    int fraction = RoundToNearest((magnitude - float(whole)) * float(scale));
    if (fraction >= scale) { whole++; fraction = 0; }
    bool negative = value < 0.0 && (whole != 0 || fraction != 0);
    if (decimals == 0) FormatEx(text, maxlength, "%s%d", negative ? "-" : "", whole);
    else if (decimals == 1) FormatEx(text, maxlength, "%s%d.%d", negative ? "-" : "", whole, fraction);
    else FormatEx(text, maxlength, "%s%d.%02d", negative ? "-" : "", whole, fraction);
    if (!trim || decimals == 0) return;
    int length = strlen(text), dot = -1;
    for (int i = 0; i < length; i++) if (text[i] == '.') dot = i;
    if (dot < 0) return;
    while (length > dot + 1 && text[length-1] == '0') text[--length] = '\0';
    if (length == dot + 1) text[dot] = '\0';
}

/** 对非负账本做精确整数加法，失败时不修改result。 */
bool RN_Math_Add(int a, int b, int &result)
{
    if (a < 0 || b < 0 || a > RN_MAX_INT - b) return false;
    result = a + b;
    return true;
}

/** 对非负账本做精确整数乘法，禁止先溢出再校验。 */
bool RN_Math_Multiply(int a, int b, int &result)
{
    if (a < 0 || b < 0 || (b > 0 && a > RN_MAX_INT / b)) return false;
    result = a * b;
    return true;
}

/** 整型百分比重配累计预算，四舍五入且增量至少minimum；失败不改输出。 */
bool RN_Math_GrowChoices(int current, int percent, int minimum, int &granted, int &added)
{
    if (current < 0 || percent < 100 || minimum < 0) return false;
    int whole, fraction, scaled;
    if (!RN_Math_Multiply(current, percent / 100, whole) ||
        !RN_Math_Multiply(current / 100, percent % 100, fraction) ||
        !RN_Math_Add(whole, fraction, scaled) ||
        !RN_Math_Add(scaled, (current % 100 * (percent % 100) + 50) / 100, scaled)) return false;
    int increase = scaled - current;
    if (increase < minimum) increase = minimum;
    if (!RN_Math_Add(current, increase, scaled)) return false;
    granted = scaled;
    added = increase;
    return true;
}

/**
 * 返回当前等级的有效需求；先封顶后人数缩放。
 * @param level 当前团队等级，从0开始。
 * @param scale 已校验的人数系数。
 * @return 非法参数或不可表达结果返回0，调用方必须拒绝结算。
 */
float RN_Math_Need(int level, float base, float step, float cap, float scale)
{
    if (level < 0 || !RN_Math_Finite(base) || !RN_Math_Finite(step) ||
        !RN_Math_Finite(cap) || !RN_Math_Finite(scale) ||
        base < 1.0 || step < 0.0 || cap < base || scale <= 0.0) return 0.0;
    float need = base;
    if (step > 0.0)
    {
        if (float(level) >= (cap - base) / step) need = cap;
        else need = base + float(level) * step;
    }
    need *= scale;
    return RN_Math_Finite(need) && need > 0.0 ? need : 0.0;
}

/** 计算选择预算；降级时pending钳为0，历史used不被改写。 */
bool RN_Math_Budget(int initial, int perLevel, int level, int bonus, int used, int &total, int &pending)
{
    int earned, basic, next;
    if (used < 0 || !RN_Math_Multiply(perLevel, level, earned) ||
        !RN_Math_Add(initial, earned, basic) || !RN_Math_Add(basic, bonus, next)) return false;
    total = next;
    pending = next > used ? next - used : 0;
    return true;
}

/**
 * 模拟一次XP结算，不写真实团队/档案。
 * @param xp 实际发放经验，保留游戏难度倍率产生的小数。
 * @param progress 旧百分比；人数变化不会重新换算它。
 * @param nextLevel/nextProgress 仅在全量模拟成功后写入。
 * @return 失败保持所有输出；极端跨级量由工作量保护拒绝，不构成玩法等级上限。
 */
bool RN_Math_GainXP(int level, float progress, float xp, float base, float step, float cap,
                   float scale, int &nextLevel, float &nextProgress, int &gained)
{
    if (!RN_Math_Finite(xp) || xp < 0.0 || !RN_Math_Finite(progress) || progress < 0.0 || progress >= 100.0) return false;
    float need = RN_Math_Need(level, base, step, cap, scale);
    if (need <= 0.0) return false;
    if (xp == 0.0)
    {
        nextLevel = level; nextProgress = progress; gained = 0;
        return true;
    }
    // 临时XP余额与百分比溢出公式等价，避免多级循环反复乘除放大舍入误差。
    float previous = progress / 100.0 * need;
    float balance = previous + xp;
    if (!RN_Math_Finite(balance) || balance <= previous) return false;
    int count, current = level;
    while (balance >= need || balance / need * 100.0 >= 99.9999)
    {
        if (current == RN_MAX_INT || ++count > RN_MAX_LEVEL_STEPS) return false;
        balance -= need;
        if (balance < 0.0) balance = 0.0;
        current++;
        need = RN_Math_Need(current, base, step, cap, scale);
        if (need <= 0.0) return false;
        if (!RN_Math_Finite(balance)) return false;
    }
    float next = balance / need * 100.0;
    if (!RN_Math_Finite(next) || next < 0.0 || next >= 100.0 ||
        (count == 0 && next <= progress)) return false;
    nextLevel = current;
    nextProgress = next;
    gained = count;
    return true;
}

/** 从跨图时间戳扣除已结束及进行中的暂停区间；负起点表示未开局。 */
float RN_Math_Elapsed(float now, float start, float paused, float pauseStart)
{
    if (start < 0.0 || !RN_Math_Finite(now) || !RN_Math_Finite(start) ||
        !RN_Math_Finite(paused) || !RN_Math_Finite(pauseStart)) return 0.0;
    float elapsed = now - start - paused;
    if (pauseStart >= 0.0) elapsed -= now - pauseStart;
    return elapsed > 0.0 ? elapsed : 0.0;
}

/** 按完整区间取档，不累加定时器次数；无上限时仍检查整型范围。 */
int RN_Math_Tier(float elapsed, float intervalSeconds, int maximum)
{
    if (!RN_Math_Finite(elapsed) || !RN_Math_Finite(intervalSeconds) ||
        elapsed < 0.0 || intervalSeconds <= 0.0 || maximum < 0) return 0;
    float value = elapsed / intervalSeconds;
    if (maximum > 0 && value >= float(maximum)) return maximum;
    if (!RN_Math_Finite(value) || value >= RN_INT_FLOAT_LIMIT) return RN_MAX_INT;
    return RoundToFloor(value);
}
