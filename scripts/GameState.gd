extends Node

signal assignment_changed
signal flight_completed(route_idx: int)
signal repair_completed(plane_idx: int)
signal cash_changed

const SAVE_PATH         := "user://save.json"
const AUTOSAVE_INTERVAL := 30.0

const PLANE_CATALOG: Array = [
	{
		"name": "Cessna 208 Caravan",
		"seats": 9,
		"price": 35000,
		"wear_per_flight": 1.5,
		"repair_cost_per_pct": 50.0,
		"repair_time_sec_per_pct": 2.0,
		"description": "Small regional prop",
	},
	{
		"name": "Pilatus PC-12",
		"seats": 9,
		"price": 95000,
		"wear_per_flight": 1.0,
		"repair_cost_per_pct": 60.0,
		"repair_time_sec_per_pct": 2.0,
		"description": "Durable single-engine turboprop",
	},
	{
		"name": "DHC-6 Twin Otter",
		"seats": 19,
		"price": 150000,
		"wear_per_flight": 2.0,
		"repair_cost_per_pct": 90.0,
		"repair_time_sec_per_pct": 2.5,
		"description": "19-seat STOL turboprop",
	},
	{
		"name": "Saab 340",
		"seats": 34,
		"price": 350000,
		"wear_per_flight": 1.6,
		"repair_cost_per_pct": 140.0,
		"repair_time_sec_per_pct": 3.0,
		"description": "34-seat regional turboprop",
	},
]

var airline_name := "Sky Haven Airways"
var cash         := 25000.0
var time_scale   := 1.0

var planes: Array = [
	{
		"name": "Cessna 208 Caravan",
		"seats": 9,
		"condition": 100.0,
		"status": "grounded",       # grounded | flying | maintenance
		"assigned_route": -1,
		"wear_per_flight": 1.5,
		"repair_cost_per_pct": 50.0,
		"repair_time_sec_per_pct": 2.0,
		"repair_time_left": 0.0,
		"repair_total_time": 0.0,
		"total_flights": 0,
	}
]

var routes: Array = [
	{
		"origin": "PHL",
		"origin_city": "Philadelphia",
		"destination": "AVP",
		"destination_city": "Wilkes-Barre",
		"distance_mi": 81,
		"assigned_plane": -1,
		"status": "inactive",       # inactive | active
		"ticket_price": 89.0,
		"occupancy_rate": 0.8,
		"flight_duration_sec": 60.0,
		"flight_progress": 0.0,
	}
]

var _autosave_timer  := 0.0
var _window_focused  := true

func _ready() -> void:
	get_tree().root.focus_entered.connect(func(): _window_focused = true)
	get_tree().root.focus_exited.connect(func(): _window_focused = false)
	load_game()

func _process(delta: float) -> void:
	var effective := delta * (time_scale if _window_focused else 1.0)
	_tick(effective)
	_autosave_timer += delta          # autosave on real time
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()

# ── Speed ─────────────────────────────────────────────────────────────────────

func cycle_speed() -> void:
	match time_scale:
		1.0: time_scale = 2.0
		2.0: time_scale = 5.0
		_:   time_scale = 1.0

# ── Flight loop ───────────────────────────────────────────────────────────────

func _tick(delta: float) -> void:
	for i in planes.size():
		var plane: Dictionary = planes[i]
		if plane["status"] != "maintenance":
			continue
		plane["repair_time_left"] = float(plane["repair_time_left"]) - delta
		if float(plane["repair_time_left"]) <= 0.0:
			plane["repair_time_left"] = 0.0
			plane["repair_total_time"] = 0.0
			plane["condition"] = 100.0
			plane["status"] = "grounded"
			repair_completed.emit(i)

	for i in routes.size():
		var route: Dictionary = routes[i]
		if route["status"] != "active":
			continue
		var plane_idx: int = route["assigned_plane"]
		var plane: Dictionary = planes[plane_idx]
		if float(plane["condition"]) <= 0.0:
			unassign_route(i)
			continue
		route["flight_progress"] = float(route["flight_progress"]) + delta
		while float(route["flight_progress"]) >= float(route["flight_duration_sec"]):
			route["flight_progress"] = float(route["flight_progress"]) - float(route["flight_duration_sec"])
			_complete_flight(i)
			if route["status"] != "active":
				break

func _complete_flight(route_idx: int) -> void:
	var route: Dictionary = routes[route_idx]
	var plane: Dictionary = planes[int(route["assigned_plane"])]
	var revenue := float(route["ticket_price"]) * float(plane["seats"]) * float(route["occupancy_rate"])
	cash += revenue
	cash_changed.emit()
	plane["condition"] = maxf(0.0, float(plane["condition"]) - float(plane["wear_per_flight"]))
	plane["total_flights"] = int(plane["total_flights"]) + 1
	flight_completed.emit(route_idx)

# ── Assignment ────────────────────────────────────────────────────────────────

func assign_plane_to_route(plane_idx: int, route_idx: int) -> void:
	var old_route: int = planes[plane_idx]["assigned_route"]
	if old_route != -1:
		routes[old_route]["assigned_plane"] = -1
		routes[old_route]["status"] = "inactive"
		routes[old_route]["flight_progress"] = 0.0
	var old_plane: int = routes[route_idx]["assigned_plane"]
	if old_plane != -1:
		planes[old_plane]["status"] = "grounded"
		planes[old_plane]["assigned_route"] = -1
	planes[plane_idx]["assigned_route"] = route_idx
	planes[plane_idx]["status"] = "flying"
	routes[route_idx]["assigned_plane"] = plane_idx
	routes[route_idx]["status"] = "active"
	routes[route_idx]["flight_progress"] = 0.0
	assignment_changed.emit()

func unassign_route(route_idx: int) -> void:
	var plane_idx: int = routes[route_idx]["assigned_plane"]
	if plane_idx == -1:
		return
	planes[plane_idx]["status"] = "grounded"
	planes[plane_idx]["assigned_route"] = -1
	routes[route_idx]["assigned_plane"] = -1
	routes[route_idx]["status"] = "inactive"
	routes[route_idx]["flight_progress"] = 0.0
	assignment_changed.emit()

# ── Purchase ──────────────────────────────────────────────────────────────────

func buy_plane(catalog_idx: int) -> void:
	var entry: Dictionary = PLANE_CATALOG[catalog_idx]
	if cash < float(entry["price"]):
		return
	cash -= float(entry["price"])
	cash_changed.emit()
	planes.append({
		"name": entry["name"],
		"seats": entry["seats"],
		"condition": 100.0,
		"status": "grounded",
		"assigned_route": -1,
		"wear_per_flight": entry["wear_per_flight"],
		"repair_cost_per_pct": entry["repair_cost_per_pct"],
		"repair_time_sec_per_pct": entry["repair_time_sec_per_pct"],
		"repair_time_left": 0.0,
		"repair_total_time": 0.0,
		"total_flights": 0,
	})
	assignment_changed.emit()

# ── Repair ────────────────────────────────────────────────────────────────────

static func repair_cost_for_plane(plane: Dictionary) -> float:
	var damage := 100.0 - float(plane["condition"])
	if damage <= 0.0:
		return 0.0
	var age_mult := 1.0 + int(plane["total_flights"]) * 0.005
	return damage * float(plane["repair_cost_per_pct"]) * age_mult

func repair_plane(plane_idx: int) -> void:
	var plane: Dictionary = planes[plane_idx]
	if plane["status"] != "grounded":
		return
	var damage := 100.0 - float(plane["condition"])
	if damage <= 0.0:
		return
	var cost := repair_cost_for_plane(plane)
	if cash < cost:
		return
	cash -= cost
	cash_changed.emit()
	var repair_time := damage * float(plane["repair_time_sec_per_pct"])
	plane["repair_time_left"] = repair_time
	plane["repair_total_time"] = repair_time
	plane["status"] = "maintenance"
	assignment_changed.emit()

# ── Save / Load ───────────────────────────────────────────────────────────────

func save_game() -> void:
	var data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"cash": cash,
		"planes": planes.duplicate(true),
		"routes": routes.duplicate(true),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var result := JSON.parse_string(f.get_as_text())
	f.close()
	if not result is Dictionary:
		return
	var data: Dictionary = result
	cash = float(data.get("cash", cash))
	if data.has("planes"):
		planes = data["planes"]
	if data.has("routes"):
		routes = data["routes"]
	var elapsed := Time.get_unix_time_from_system() - float(data.get("timestamp", Time.get_unix_time_from_system()))
	if elapsed > 0.0:
		_simulate_offline(elapsed)

func _simulate_offline(elapsed: float) -> void:
	for i in planes.size():
		var plane: Dictionary = planes[i]
		if plane["status"] != "maintenance":
			continue
		plane["repair_time_left"] = maxf(0.0, float(plane["repair_time_left"]) - elapsed)
		if float(plane["repair_time_left"]) <= 0.0:
			plane["repair_total_time"] = 0.0
			plane["condition"] = 100.0
			plane["status"] = "grounded"

	for i in routes.size():
		var route: Dictionary = routes[i]
		if route["status"] != "active":
			continue
		var plane_idx: int = route["assigned_plane"]
		if plane_idx == -1:
			continue
		var plane: Dictionary = planes[plane_idx]
		var total     := float(route["flight_progress"]) + elapsed
		var dur       := float(route["flight_duration_sec"])
		var n_flights := int(total / dur)
		route["flight_progress"] = fmod(total, dur)
		for _j in n_flights:
			if float(plane["condition"]) <= 0.0:
				plane["status"] = "grounded"
				plane["assigned_route"] = -1
				route["assigned_plane"] = -1
				route["status"] = "inactive"
				route["flight_progress"] = 0.0
				break
			cash += float(route["ticket_price"]) * float(plane["seats"]) * float(route["occupancy_rate"])
			plane["condition"] = maxf(0.0, float(plane["condition"]) - float(plane["wear_per_flight"]))
			plane["total_flights"] = int(plane["total_flights"]) + 1

# ── Util ──────────────────────────────────────────────────────────────────────

static func format_money(amount: float) -> String:
	var n := int(abs(amount))
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return ("-$" if amount < 0.0 else "$") + out
