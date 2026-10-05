// Generated from Nostalgia canonical data; regenerate with tools/export_canary.py.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <mutex>
#include <vector>
namespace nostalgia {
inline bool isClass(uint16_t id) { return id >= 20 && id <= 23; }
inline uint32_t attackMs(uint16_t item) {
    switch (item) { case 3294: return 1050;
case 3307: return 1050;
case 3308: return 1050;
case 3304: return 1400;
case 3270: return 1400;
case 3279: return 1400;
case 3318: return 800;
case 3323: return 800;
case 3327: return 800;
case 3290: return 750;
case 3291: return 750;
case 3292: return 750;
case 3289: return 1000;
case 3324: return 1000;
case 3325: return 1000;
case 3282: return 650;
case 3311: return 650;
case 3312: return 650;
case 3264: return 1550;
case 3265: return 1550;
case 3271: return 1550;
case 3266: return 1200;
case 3274: return 1200;
case 3275: return 1200;
case 3267: return 950;
case 3268: return 950;
case 3269: return 950;
case 3280: return 300;
case 3281: return 300;
case 3283: return 300;
case 3295: return 950;
case 3296: return 950;
case 3297: return 950;
case 3300: return 1500;
case 3301: return 1500;
case 3302: return 1500; default: return 0; }
}
inline uint64_t experienceForLevel(uint32_t level) {
    if (level <= 1) return 0;
    // Serialized because login/database loaders also query the curve.
    static std::mutex mutex;
    static std::vector<long double> cumulative {0};
    std::lock_guard lock(mutex);
    constexpr std::array<double, 5> xs {100.0,200.0,300.0,500.0,750.0};
    constexpr std::array<double, 5> ys {122000.0,301000.0,527000.0,1090000.0,1960000.0};
    while (cumulative.size() < level) {
        double n = static_cast<double>(cumulative.size());
        double x = n + 0.5;
        size_t i = 0;
        while (i + 2 < xs.size() && x > xs[i + 1]) ++i;
        double t = (std::log(x) - std::log(xs[i])) / (std::log(xs[i + 1]) - std::log(xs[i]));
        double rate = std::exp(std::log(ys[i]) + t * (std::log(ys[i + 1]) - std::log(ys[i])));
        long double step = 500.0 * (std::pow(n + 1 + 20.0, 3) - std::pow(n + 20.0, 3)) / 10638739.0 * rate;
        long double next = cumulative.back() + step;
        if (next >= static_cast<long double>(std::numeric_limits<uint64_t>::max())) return std::numeric_limits<uint64_t>::max();
        cumulative.push_back(next);
    }
    return static_cast<uint64_t>(std::ceil(cumulative[level - 1]));
}
}
