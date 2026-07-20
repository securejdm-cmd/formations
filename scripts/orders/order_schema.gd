class_name OrderSchema
extends RefCounted

## WO-031 — primitive / trigger name constants (see docs/ORDER_SCHEMA.md).

const QUEUE_CAP := 3

const PRIM_ADVANCE_TO := "advance_to"
const PRIM_HOLD := "hold"
const PRIM_ABSOLUTE_HOLD := "absolute_hold"
const PRIM_ATTACK_NEAREST := "attack_nearest"
const PRIM_ATTACK_TARGET := "attack_target"
const PRIM_FEIGN_RETREAT := "feign_retreat"
const PRIM_FLANK_MOVE := "flank_move"
const PRIM_SWING_AND_CHARGE := "swing_and_charge"

const TRIG_AT_START := "at_start"
const TRIG_AFTER_SECONDS := "after_seconds"
const TRIG_ENEMY_WITHIN := "enemy_within"
const TRIG_UNIT_ENGAGES := "unit_engages"
const TRIG_UNIT_ROUTS := "unit_routs"
const TRIG_MY_COHESION_BELOW := "my_cohesion_below"
const TRIG_HORN_SOUNDED := "horn_sounded"
const TRIG_UNIT_ORDER_STARTED := "unit_order_started"

const PHASE_IDLE := "idle"
const PHASE_WAITING := "waiting"
const PHASE_EXECUTING := "executing"
const PHASE_TERMINAL := "terminal"

const BATTLE_TYPE_PITCHED := "pitched"
const POSTURE_NORMAL := "normal"
const POSTURE_CONCEALED := "concealed"


static func clamp_queue(steps: Array) -> Array:
	if steps.size() <= QUEUE_CAP:
		return steps.duplicate(true)
	return steps.slice(0, QUEUE_CAP)


static func point_to_px(point: Dictionary) -> Vector2:
	var px := Constants.get_float("px_per_meter")
	return Vector2(float(point.get("x", 0.0)) * px, float(point.get("y", 0.0)) * px)


static func ordered_retreat_drain_per_sec(unit: Variant) -> float:
	var base: float = Constants.get_float("ordered_retreat_drain_per_sec")
	var skill: float = float(unit.profile.get("retreating_skill", 30.0))
	return base * maxf(0.0, 1.0 - skill / 100.0)
