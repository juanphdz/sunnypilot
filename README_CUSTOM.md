# Custom Prius Prime (TSS-P + SmartDSU) Tuning Log

This document tracks custom longitudinal and lateral modifications applied to the `jphxprius` branch of **sunnypilot** for a **2020 Toyota Prius Prime** equipped with **TSS-P and SmartDSU (sDSU)**.

---

## 1. Problem Statements & Objectives

1. **Slow Launch Reaction from Stop (0–20 mph)**:
   - Vehicle hesitated when the car ahead started rolling away at green lights or in stop-and-go traffic, resulting in getting honked at.
   - Acceleration curve lagged behind human reaction time until higher speeds were reached.

2. **Sluggish Recovery After a Vehicle Turns Right**:
   - When a preceding car slowed down to make a right turn and vacated the lane, the car lingered at low speeds and took multiple seconds to resume cruising speed.

3. **Steering Feel & Lateral Tuning**:
   - Balancing steering authority, smooth turn unwinding, and eliminating 25–50 mph lateral oscillation/ping-ponging.

---

## 2. Inventory of Changes

### A. Dynamic Experimental Control (`sunnypilot/selfdrive/controls/lib/dec/dec.py`)
- **Moving Lead Priority from Standstill**:
  - *Previous behavior*: When stopped, `_standstill_count > 3` unconditionally requested `blended` mode. DEC remained locked in blended mode until wheel speed decremented the counter, forcing the planner to arbitrate through vision model `shouldStop` and conservative E2E acceleration.
  - *New behavior*: If a tracked lead vehicle begins moving (`lead_one.vLead > 0.5 m/s`), DEC immediately requests `acc` mode, allowing MPC radar tracking to drive the launch without waiting for ego motion or blended mode hysteresis.

### B. Longitudinal Planner (`selfdrive/controls/lib/longitudinal_planner.py`)
- **Full Accel Ceiling Flat to 40 mph**:
  - `A_CRUISE_MAX_VALS = [1.5, 1.5, 0.7, 0.5]` with `A_CRUISE_MAX_BP = [0., 17.88, 25., 40.]`. Holds Prius 1.5 m/s² ceiling genuinely flat up to 40 mph (~17.88 m/s).
- **Accel Clip Ramping Rate**:
  - Slew rate per frame increased from `0.05` (1.0 m/s²/s) to `0.25` (5.0 m/s²/s), eliminating artificial 1.5s ramp lag at launch.
- **Throttle Gate & Low-Speed Creep Clamping**:
  - `ALLOW_THROTTLE_THRESHOLD = 0.2` (lowered from 0.4).
  - `MIN_ALLOW_THROTTLE_SPEED = 10.0` m/s (raised from 2.5 m/s) to prevent `throttle_prob` from forcing coast deceleration during launch.
- **E2E Speed Bias**:
  - Nudges vision model `desiredAcceleration` by `+0.20 m/s²` when positive, tapering to zero during braking.
- **Lead Launch Protection in Blended Mode**:
  - When in blended mode, if MPC detects a departing lead (`vLead > 0.5` or `vRel > 0.2`) and requests positive launch acceleration (`output_a_target_mpc > 0.1`), `output_should_stop` follows MPC rather than letting vision `output_should_stop_e2e` hold the vehicle in `LongCtrlState.stopping` with -1.2 m/s² brake deceleration. Command is assigned `max(output_a_target_e2e, output_a_target_mpc)`.

### C. Longitudinal MPC (`selfdrive/controls/lib/longitudinal_mpc_lib/long_mpc.py`)
- **Jerk Factor & Acceleration Change Cost**:
  - Lowered `jerk_factor` to `0.9` for Standard, `0.5` for Aggressive, and `1.2` for Relaxed (reverted from `1.8` / `1.6`).
  - Reduces `a_change_cost` weight from 360 down to 180 (Standard) or 100 (Aggressive), allowing the MPC solver to ramp acceleration briskly when pulling away or resuming after a turn.
- **Stopped Distance Buffer**:
  - Lowered `STOP_DISTANCE` from `6.0` meters (~20 ft) to `5.0` meters (~16.4 ft), initiating forward rolling sooner as the lead car pulls away.
- **Comfort Brake**:
  - Restored `COMFORT_BRAKE = 2.5` (reverted from 2.2) to tighten obstacle distance buffer calculation at low speeds.

### D. Radar Daemon (`selfdrive/controls/radard.py`)
- **Low-Speed Lead Lateral Window**:
  - `potential_low_speed_lead()` window tightened from `abs(yRel) < 1.0` to `abs(yRel) < 0.7`. Allows vehicles turning right to clear the primary lead qualification substantially earlier.
- **Lead Probability Drop Response**:
  - Added fast-drop check in `lead_prob_filters`: when `lead_prob < 0.2`, filter value drops immediately to avoid the 0.2s RC smoothing decay from latching onto departing/turning vehicles.

### E. Toyota Car Controller (`opendbc_repo/opendbc/car/toyota/carcontroller.py`)
- **Brake Release Threshold (`permit_braking`)**:
  - Lowered hysteresis from `0.2` / `0.3` to `0.1` / `0.15` m/s². Releases Toyota brake actuator earlier when transitioning from standstill to creep/acceleration.
- **PCM Windup Rate Limit**:
  - `ACCEL_WINDUP_LIMIT` raised from `4.0` to `6.0 * DT_CTRL * 3` m/s²/frame for faster CAN-level throttle response.
- **Standstill Request Clearing**:
  - `standstill_req` cleared as soon as `actuators.longControlState != LongCtrlState.stopping` rather than waiting on PCM cruise status.

### F. Toyota Car Interface (`opendbc_repo/opendbc/car/toyota/interface.py`)
- **Prius Stop/Start Tuning**:
  - Extended TSS2 hybrid stop/start tuning to `CAR.TOYOTA_PRIUS`: `vEgoStopping = 0.25`, `vEgoStarting = 0.25`, `stoppingDecelRate = 0.3`, `stopAccel = -1.2`, and `longitudinalActuatorDelay = 0.05`.

---

## 3. Quick Reference: Key Tuning Variables

| Parameter | File | Previous / Stock | Current Setting | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `A_CRUISE_MAX_VALS` | `longitudinal_planner.py` | `[1.6, 1.2, 0.8, 0.6]` | `[1.5, 1.5, 1.0, 0.7, 0.5]` | Holds 1.5 m/s² flat to 20 mph, tapers to 1.0 by 40 mph (was flat to 40 - felt too punchy 20-40) |
| `accel_clip` step | `longitudinal_planner.py` | `0.05` | `0.25` | 5.0 m/s²/s slew rate limit |
| `E2E_SPEED_BIAS` | `longitudinal_planner.py` | `0.00` | `0.23` | Nudge e2e launch acceleration |
| `STOP_DISTANCE` | `long_mpc.py` | `6.0` | `5.0` | Target stopped distance buffer |
| `COMFORT_BRAKE` | `long_mpc.py` | `2.2` | `2.5` | Obstacle buffer deceleration curve |
| `jerk_factor` (Rel/Std/Agg) | `long_mpc.py` | `1.8 / 1.8 / 1.6` | `1.2 / 0.9 / 0.9` | Reduces acceleration ramp penalty (aggressive matched to standard - was too jerky) |
| `T_FOLLOW` (Rel/Std/Agg) | `long_mpc.py` | `1.75 / 1.45 / 1.25` | `1.75 / 1.45 / 1.45` | Follow time gap (aggressive matched to standard - was following too close) |
| `potential_low_speed_lead` | `radard.py` | `abs(yRel) < 1.0` | `abs(yRel) < 0.7` | Quick drop of right-turning cars |
| `permit_braking` off | `carcontroller.py` | `0.30` | `0.15` | Earlier physical brake release |
