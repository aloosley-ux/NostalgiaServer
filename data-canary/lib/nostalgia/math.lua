-- Pure gameplay maths. No engine objects: checked against canonical Python outputs.
local M = {}
local D = dofile('data-canary/lib/nostalgia/catalog.lua')
M.data = D
local B, C, P = D.balance, D.balance.combat, D.balance.progression
local cumulativeSkills = {0}
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
M.clamp = clamp
function M.scale(value, kind)
    local divisor = C[kind .. '_multiplier_divisor']
    return ((math.max(1, value) + C[kind .. '_multiplier_shift']) / divisor) ^ C[kind .. '_multiplier_exponent']
end
function M.hp(level, class)
    local factor = ((math.max(1, level) + C.hp_level_shift) / C.hp_reference_divisor) ^ C.hp_exponent
    return C.base_hp_at_level_100 * factor * B.classes[class].hp_coeff
end
function M.challenge(level, content)
    return clamp((math.max(1, content) / math.max(1, level)) ^ C.challenge.ratio_exponent, C.challenge.minimum, C.challenge.maximum)
end
function M.content(level, content)
    local r = math.max(1, content) / math.max(1, level)
    local c = C.content_scaling
    return {
        outgoing = r > 1 and r ^ -c.underlevel_outgoing_exponent or 1,
        incoming = r > 1 and r ^ c.underlevel_incoming_exponent or 1,
        xp = r < 1 and math.max(c.minimum_xp_relevance, r ^ c.overlevel_xp_relevance_exponent) or 1,
        skill = r < 1 and math.max(c.minimum_skill_relevance, r ^ c.overlevel_skill_relevance_exponent) or 1,
    }
end
function M.skillRate(skill)
    return P.skill_xp.base_per_dedicated_hour_at_100 * ((skill + 50) / 150) ^ P.skill_xp.scale_exponent
end
function M.skillStep(n)
    return D.skill_steps[n] or P.skill_anchor_effort_hours * ((n + 1 + P.curve_shift)^3 - (n + P.curve_shift)^3)
        / ((P.skill_anchor + P.curve_shift)^3 - (1 + P.curve_shift)^3) * M.skillRate(n + 0.5)
end
function M.skill(xp)
    xp = math.max(0, xp or 0)
    while cumulativeSkills[#cumulativeSkills] <= xp do
        local n = #cumulativeSkills
        cumulativeSkills[n + 1] = cumulativeSkills[n] + M.skillStep(n)
    end
    local lo, hi = 1, #cumulativeSkills
    while lo + 1 < hi do
        local mid = math.floor((lo + hi) / 2)
        if cumulativeSkills[mid] <= xp then lo = mid else hi = mid end
    end
    return lo + (xp - cumulativeSkills[lo]) / M.skillStep(lo)
end
function M.skillGain(skill, seconds, efficiency, level, content)
    return M.skillRate(skill) * seconds / 3600 * efficiency * M.challenge(level, content) * M.content(level, content).skill
end
function M.pressure(level)
    local a = C.attack_mitigation
    local ip = ((level + B.items.item_power_level_shift) / (B.items.item_power_reference_level + B.items.item_power_level_shift)) ^ B.items.item_power_exponent
    return a.pressure_at_ip100 * ip * ((level + a.level_shift) / a.level_divisor)^a.level_exponent
end
function M.damage(weapon, level, skill, mob, critical)
    local p = M.pressure(weapon.required_level)
    local armour = mob.stats.armour * (1 - weapon.penetration)
    local common = M.scale(skill, 'skill') * M.scale(level, 'level') * M.content(level, mob.content_level).outgoing
        * B.classes[weapon.class_name][mob.archetype .. '_efficiency']
    local direct = weapon.base_damage_per_attack * p / (p + armour) * common
    if critical then direct = direct * weapon.crit_multiplier end
    local status = weapon.status_dps * weapon.attack_interval * p / (p + armour * (1 - weapon.status_armour_bypass)) * common
    return direct, status
end
function M.reduction(armour, defence, class, pressure, guard)
    local effective = armour * M.scale(defence, 'defence') * B.classes[class].armour_coeff
    return math.min(0.95, 1 - pressure / (effective + pressure) * (1 - (guard or 0)))
end
function M.recovery(level, recovery, class)
    local hp = M.hp(level, class)
    local hpScale = hp / (C.base_hp_at_level_100 * B.classes[class].hp_coeff)
    return (C.recovery.percent_hp_per_second * hp + C.recovery.flat_at_hp_scale_1 * hpScale)
        * M.scale(recovery, 'recovery') * B.classes[class].recovery_coeff
end
return M
