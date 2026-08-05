class_name RealismBudget
extends RefCounted
## Phase A — discovery math for uber-realistic Mission Flight.
## Hohmann Δv, rocket-equation propellant fractions, synodic windows.
## See docs/STRATEGY_REAL_ROCKET_SCIENCE.md. No kid UI here.

const G0_M_S2 := 9.80665
const AU_KM := 149597870.7
## GM_sun in km³/s² (conventional value used in AU/yr conversions).
const MU_SUN_KM3_S2 := 1.32712440018e11
## Circular LEO proxies for the Oberth inject stub (Earth).
const V_LEO_KM_S := 7.67
const V_ESC_LEO_KM_S := V_LEO_KM_S * sqrt(2.0)

const ISP_CHEMICAL_S := 450.0
const ISP_NTP_S := 900.0
const ISP_ORION_S := 4000.0

const PROPULSION := {
	"chemical": ISP_CHEMICAL_S,
	"ntp": ISP_NTP_S,
	"orion": ISP_ORION_S,
}


## Synodic period in Earth years between two sidereal periods (years).
static func synodic_years(period_a_yr: float, period_b_yr: float) -> float:
	var pa: float = maxf(period_a_yr, 1.0e-9)
	var pb: float = maxf(period_b_yr, 1.0e-9)
	var diff: float = absf(1.0 / pa - 1.0 / pb)
	if diff < 1.0e-12:
		return INF
	return 1.0 / diff


## Propellant mass fraction for a given Δv (km/s) and Isp (s).
static func propellant_fraction(dv_km_s: float, isp_s: float) -> float:
	var ve: float = maxf(isp_s, 1.0) * G0_M_S2 / 1000.0  # km/s
	return 1.0 - exp(-maxf(dv_km_s, 0.0) / ve)


static func r_km(a_au: float) -> float:
	return maxf(a_au, 1.0e-6) * AU_KM


static func v_circ_km_s(r_km_val: float) -> float:
	return sqrt(MU_SUN_KM3_S2 / maxf(r_km_val, 1.0))


## Coplanar circular Hohmann: heliocentric departure + arrival Δv and coast time.
static func hohmann(r1_au: float, r2_au: float) -> Dictionary:
	var r1: float = r_km(r1_au)
	var r2: float = r_km(r2_au)
	var a_t: float = 0.5 * (r1 + r2)
	var v1: float = v_circ_km_s(r1)
	var v2: float = v_circ_km_s(r2)
	var v_peri: float = sqrt(MU_SUN_KM3_S2 * (2.0 / r1 - 1.0 / a_t))
	var v_ap: float = sqrt(MU_SUN_KM3_S2 * (2.0 / r2 - 1.0 / a_t))
	var dv_dep: float = absf(v_peri - v1)
	var dv_arr: float = absf(v2 - v_ap)
	var t_sec: float = PI * sqrt(a_t * a_t * a_t / MU_SUN_KM3_S2)
	var t_yr: float = t_sec / (365.25 * 24.0 * 3600.0)
	return {
		"r1_au": r1_au,
		"r2_au": r2_au,
		"a_transfer_au": a_t / AU_KM,
		"dv_depart_heliocentric_km_s": dv_dep,
		"dv_arrive_heliocentric_km_s": dv_arr,
		"dv_heliocentric_total_km_s": dv_dep + dv_arr,
		"coast_yr": t_yr,
		"coast_days": t_yr * 365.25,
	}


## Oberth LEO inject stub: Δv from circular LEO given hyperbolic excess ≈ heliocentric depart Δv.
static func leo_inject_km_s(v_inf_km_s: float) -> float:
	var esc2: float = V_ESC_LEO_KM_S * V_ESC_LEO_KM_S
	return sqrt(maxf(v_inf_km_s * v_inf_km_s + esc2, 0.0)) - V_LEO_KM_S


## Capture stub: destination circularization ≈ heliocentric arrival Δv (Phase A).
static func capture_stub_km_s(dv_arrive_heliocentric_km_s: float) -> float:
	return maxf(dv_arrive_heliocentric_km_s, 0.0)


## Required heliocentric phase (dest − origin) at departure for a Hohmann coast.
static func hohmann_phase_required_rad(period_dest_yr: float, coast_yr: float) -> float:
	var n2: float = TAU / maxf(period_dest_yr, 1.0e-9)
	return wrapf(PI - n2 * coast_yr, -PI, PI)


## Years until the next Hohmann departure phase.
## phase_now_rad = current (θ_dest − θ_origin). Epoch default 0 = aligned longitudes.
static func next_window_wait_yr(period_origin_yr: float, period_dest_yr: float,
		coast_yr: float, phase_now_rad: float = 0.0) -> Dictionary:
	var p1: float = maxf(period_origin_yr, 1.0e-9)
	var p2: float = maxf(period_dest_yr, 1.0e-9)
	var n1: float = TAU / p1
	var n2: float = TAU / p2
	var phase_req: float = hohmann_phase_required_rad(p2, coast_yr)
	var rel_rate: float = n1 - n2  # rad / year
	if absf(rel_rate) < 1.0e-12:
		return {"wait_yr": 0.0, "phase_err_deg": 0.0,
			"phase_now_deg": rad_to_deg(phase_now_rad),
			"phase_req_deg": rad_to_deg(phase_req)}
	# Relative phase of dest−origin advances at (n2−n1) = −rel_rate.
	# We need phase_now → phase_req.
	var delta: float
	if rel_rate > 0.0:
		# Origin gains (typical Earth → outer): relative phase decreases.
		delta = wrapf(phase_now_rad - phase_req, 0.0, TAU)
		return {
			"wait_yr": delta / rel_rate,
			"phase_err_deg": rad_to_deg(wrapf(phase_req - phase_now_rad, -PI, PI)),
			"phase_now_deg": rad_to_deg(phase_now_rad),
			"phase_req_deg": rad_to_deg(phase_req),
		}
	# Dest gains (Earth → inner): relative phase increases.
	delta = wrapf(phase_req - phase_now_rad, 0.0, TAU)
	return {
		"wait_yr": delta / (-rel_rate),
		"phase_err_deg": rad_to_deg(wrapf(phase_req - phase_now_rad, -PI, PI)),
		"phase_now_deg": rad_to_deg(phase_now_rad),
		"phase_req_deg": rad_to_deg(phase_req),
	}


## Full Phase A ledger for an origin→dest hop using SolarData a_au / period_yr.
static func hop_budget(origin: Dictionary, dest: Dictionary,
		phase_now_rad: float = 0.0) -> Dictionary:
	var r1: float = float(origin.get("a_au", 0.0))
	var r2: float = float(dest.get("a_au", 0.0))
	var p1: float = float(origin.get("period_yr", 0.0))
	var p2: float = float(dest.get("period_yr", 0.0))
	var oid := str(origin.get("id", "?"))
	var did := str(dest.get("id", "?"))
	if r1 <= 0.0 or r2 <= 0.0:
		return {
			"from": oid, "to": did, "ok": false,
			"error": "non-orbiting body (need a_au > 0)",
		}
	var h := hohmann(r1, r2)
	var v_inf: float = float(h["dv_depart_heliocentric_km_s"])
	# LEO Oberth inject only for Earth departures; otherwise the heliocentric
	# departure burn is the Phase A departure stub.
	var from_earth: bool = (oid == "earth") or is_equal_approx(r1, 1.0)
	var dv_depart: float = leo_inject_km_s(v_inf) if from_earth else v_inf
	var dv_cap: float = capture_stub_km_s(float(h["dv_arrive_heliocentric_km_s"]))
	var dv_mission: float = dv_depart + dv_cap
	var fuels := {}
	for key in PROPULSION.keys():
		var isp: float = float(PROPULSION[key])
		fuels[key] = {
			"isp_s": isp,
			"propellant_frac_depart": propellant_fraction(dv_depart, isp),
			"propellant_frac_mission": propellant_fraction(dv_mission, isp),
		}
	var syn: float = synodic_years(p1, p2)
	var wait := next_window_wait_yr(p1, p2, float(h["coast_yr"]), phase_now_rad)
	return {
		"from": oid,
		"to": did,
		"ok": true,
		"r1_au": r1,
		"r2_au": r2,
		"period1_yr": p1,
		"period2_yr": p2,
		"synodic_yr": syn,
		"coast_yr": float(h["coast_yr"]),
		"coast_days": float(h["coast_days"]),
		"dv_depart_heliocentric_km_s": float(h["dv_depart_heliocentric_km_s"]),
		"dv_arrive_heliocentric_km_s": float(h["dv_arrive_heliocentric_km_s"]),
		"dv_heliocentric_total_km_s": float(h["dv_heliocentric_total_km_s"]),
		"from_earth_leo_inject": from_earth,
		"dv_leo_inject_km_s": dv_depart if from_earth else 0.0,
		"dv_depart_burn_km_s": dv_depart,
		"dv_capture_stub_km_s": dv_cap,
		"dv_mission_km_s": dv_mission,
		"fuels": fuels,
		"window_wait_yr": float(wait.get("wait_yr", 0.0)),
		"window_phase_err_deg": float(wait.get("phase_err_deg", 0.0)),
	}


## Hard Phase A asserts — return list of {name, ok, detail}.
static func phase_a_checks() -> Array:
	var out: Array = []
	var mars_syn := synodic_years(1.0, 1.88)
	out.append({
		"name": "mars_synodic_~2.1yr",
		"ok": mars_syn > 2.0 and mars_syn < 2.3,
		"detail": "syn=%.3f yr (expect ~2.14)" % mars_syn,
	})
	var jup_syn := synodic_years(1.0, 11.86)
	out.append({
		"name": "jupiter_synodic_~1.1yr",
		"ok": jup_syn > 1.0 and jup_syn < 1.2,
		"detail": "syn=%.3f yr (expect ~1.09)" % jup_syn,
	})
	out.append({
		"name": "jupiter_not_decade_lock",
		"ok": jup_syn < 5.0,
		"detail": "syn=%.3f yr (fail if someone codes 12+ yr Jupiter window)" % jup_syn,
	})
	var nep_syn := synodic_years(1.0, 165.0)
	out.append({
		"name": "neptune_synodic_~1yr",
		"ok": nep_syn > 0.95 and nep_syn < 1.15,
		"detail": "syn=%.3f yr" % nep_syn,
	})
	var h := hohmann(1.0, 1.52)
	var dv_leo := leo_inject_km_s(float(h["dv_depart_heliocentric_km_s"]))
	var f_chem := propellant_fraction(dv_leo, ISP_CHEMICAL_S)
	var f_orion := propellant_fraction(dv_leo, ISP_ORION_S)
	out.append({
		"name": "mars_leo_inject_heliocentric_band",
		"ok": float(h["dv_depart_heliocentric_km_s"]) > 2.5 \
			and float(h["dv_depart_heliocentric_km_s"]) < 3.5,
		"detail": "dv_dep_helio=%.3f km/s (wiki ~2.93)" % float(
			h["dv_depart_heliocentric_km_s"]),
	})
	out.append({
		"name": "mars_coast_~0.7yr",
		"ok": float(h["coast_yr"]) > 0.55 and float(h["coast_yr"]) < 0.85,
		"detail": "coast=%.3f yr (~%.0f days)" % [
			float(h["coast_yr"]), float(h["coast_days"])],
	})
	out.append({
		"name": "orion_beats_chemical_mass",
		"ok": f_orion < f_chem * 0.5,
		"detail": "chem=%.1f%% orion=%.1f%% of stack for LEO inject" % [
			f_chem * 100.0, f_orion * 100.0],
	})
	var hj := hohmann(1.0, 5.2)
	out.append({
		"name": "jupiter_coast_~2.7yr",
		"ok": float(hj["coast_yr"]) > 2.4 and float(hj["coast_yr"]) < 3.0,
		"detail": "coast=%.3f yr" % float(hj["coast_yr"]),
	})
	# Window wait must never invent a multi-decade single-target lock.
	var earth := {"id": "earth", "a_au": 1.0, "period_yr": 1.0}
	var jup := {"id": "jupiter", "a_au": 5.2, "period_yr": 11.86}
	var b := hop_budget(earth, jup, 0.0)
	out.append({
		"name": "jupiter_window_wait_lt_synodic",
		"ok": bool(b.get("ok", false)) \
			and float(b["window_wait_yr"]) <= float(b["synodic_yr"]) + 0.05,
		"detail": "wait=%.3f syn=%.3f" % [
			float(b.get("window_wait_yr", -1.0)), float(b.get("synodic_yr", -1.0))],
	})
	return out
