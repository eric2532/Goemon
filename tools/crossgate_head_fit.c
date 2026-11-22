/* Offline masked color matching. This library is never loaded by the game. */
#include <stdint.h>
#include <math.h>
#include <stdlib.h>

double fit_head(const uint8_t *pixels, int width, int height, const int *samples,
                int count, double expected_x, double expected_y, int *point) {
    double best = 1e30;
    for (int y = (int)expected_y - 42; y <= (int)expected_y + 42; ++y) {
        for (int x = (int)expected_x - 32; x <= (int)expected_x + 32; ++x) {
            double cost = 0;
            for (int i = 0; i < count; ++i) {
                const int *s = samples + i * 5;
                int px = x + s[0], py = y + s[1];
                if (px < 0 || px >= width || py < 0 || py >= height) {
                    cost += 765;
                    continue;
                }
                const uint8_t *p = pixels + (py * width + px) * 4;
                cost += p[3] < 128 ? 765 : abs(p[0]-s[2]) + abs(p[1]-s[3]) + abs(p[2]-s[4]);
            }
            double dx = x-expected_x, dy = y-expected_y;
            cost = cost / (count ? count : 1) + .04 * (dx*dx + dy*dy);
            if (cost < best) {
                best = cost;
                point[0] = x;
                point[1] = y;
            }
        }
    }
    return best;
}

/* Palette-independent outline matching is used only after the reviewed head fit. */
double fit_head_mask(const uint8_t *alpha, int width, int height, const uint8_t *mask,
                     double expected_x, double expected_y, int *point) {
    uint32_t reference[20] = {0};
    uint32_t *rows = malloc((size_t)width * height * sizeof(uint32_t));
    if (!rows) return 1e9;
    for (int y = 0; y < 20; ++y)
        for (int x = 0; x < 29; ++x)
            reference[y] |= (uint32_t)(mask[y * 29 + x] >= 128) << x;
    for (int y = 0; y < height; ++y) {
        uint32_t bits = 0;
        for (int x = -14; x < width + 14; ++x) {
            bits = (bits >> 1) | ((uint32_t)(x >= 0 && x < width && alpha[y * width + x] >= 128) << 28);
            if (x >= 14) rows[y * width + x - 14] = bits;
        }
    }
    double best = 35.0, error = 1e9;
    for (int y = (int)expected_y - 42; y <= (int)expected_y + 42; ++y) {
        if (y < 0 || y >= height) continue;
        for (int x = (int)expected_x - 32; x <= (int)expected_x + 32; ++x) {
            if (x < 0 || x >= width) continue;
            int mismatch = 0;
            for (int i = 0; i < 20; ++i) {
                int row = y + i - 8;
                uint32_t actual = row >= 0 && row < height ? rows[row * width + x] : 0;
                mismatch += __builtin_popcount(actual ^ reference[i]);
                if (mismatch > best) break;
            }
            double dx = x - expected_x, dy = y - expected_y;
            double cost = mismatch + .002 * (dx * dx + dy * dy);
            if (cost < best) { best = cost; error = mismatch; point[0] = x; point[1] = y; }
        }
    }
    free(rows);
    return error;
}
