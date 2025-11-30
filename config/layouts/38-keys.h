/*                                      38 KEY MATRIX / LAYOUT MAPPING

  ╭────────────────────────╮         ╭─────────────────────────╮
  │     0   1   2   3   4  │         │  5   6   7   8   9      │
  │     10  11  12  13  14 │         │  15  16  17  18  19     │
  │ 20  21  22  23  24  25 ╰────┬────╯  26  27  28  29  30  31 │
  │             32  33  34      │       35  36  37             │
  ╰─────────────────────────────┴──────────────────────────────╯
  ╭────────────────────────╮         ╭─────────────────────────╮
  │ LT4 LT3 LT2 LT1 LT0    │         │ RT0 RT1 RT2 RT3 RT4     │
  │ LM4 LM3 LM2 LM1 LM0    │         │ RM0 RM1 RM2 RM3 RM4     │
  │ LB5 LB4 LB3 LB2 LB1 LB0╰────┬────╯ RB0 RB1 RB2 RB3 RB4 RB5 │
  │             LH2 LH1 LH0     │      RH0 RH1 RH2             │
  ╰─────────────────────────────┴──────────────────────────────╯
*/

#pragma once

// Left Top Row
#define LT0  4  // Inner Index
#define LT1  3  // Index
#define LT2  2  // Middle
#define LT3  1  // Ring
#define LT4  0  // Pinky

// Right Top Row
#define RT0  5  // Inner Index
#define RT1  6  // Index
#define RT2  7  // Middle
#define RT3  8  // Ring
#define RT4  9  // Pinky

// Left Middle Row
#define LM0 14  // Inner Index
#define LM1 13  // Index
#define LM2 12  // Middle
#define LM3 11  // Ring
#define LM4 10  // Pinky

// Right Middle Row
#define RM0 15  // Inner Index
#define RM1 16  // Index
#define RM2 17  // Middle
#define RM3 18  // Ring
#define RM4 19  // Pinky

// Left Bottom Row
#define LB0 25  // Inner Index
#define LB1 24  // Index
#define LB2 23  // Middle
#define LB3 22  // Ring
#define LB4 21  // Pinky
#define LB5 20  // Extra Pinky/Outer

// Right Bottom Row
#define RB0 26  // Inner Index
#define RB1 27  // Index
#define RB2 28  // Middle
#define RB3 29  // Ring
#define RB4 30  // Pinky
#define RB5 31  // Extra Pinky/Outer

// Left Thumb Keys
#define LH0 34  // Inner
#define LH1 33  // Middle
#define LH2 32  // Outer

// Right Thumb Keys
#define RH0 35  // Inner
#define RH1 36  // Middle
#define RH2 37  // Outer

#define KEYS_L LT0 LT1 LT2 LT3 LT4 LM0 LM1 LM2 LM3 LM4 LB0 LB1 LB2 LB3 LB4 LB5
#define KEYS_R RT0 RT1 RT2 RT3 RT4 RM0 RM1 RM2 RM3 RM4 RB0 RB1 RB2 RB3 RB4 RB5
#define THUMBS LH2 LH1 LH0 RH0 RH1 RH2

#define LAYER_FROM38( \
    k00, k01, k02, k03, k04,           k05, k06, k07, k08, k09, \
    k10, k11, k12, k13, k14,           k15, k16, k17, k18, k19, \
    k20, k21, k22, k23, k24, k25, k26, k27, k28, k29, k30, k31, \
              k32, k33, k34,      k35, k36, k37                 \
) \
    k00  k01  k02  k03  k04            k05  k06  k07  k08  k09  \
    k10  k11  k12  k13  k14            k15  k16  k17  k18  k19  \
    k20  k21  k22  k23  k24  k25  k26  k27  k28  k29  k30  k31  \
              k32  k33  k34       k35  k36  k37
