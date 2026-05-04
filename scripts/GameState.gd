extends Node

signal assignment_changed
signal flight_completed(route_idx: int)
signal repair_completed(plane_idx: int)
signal cash_changed
signal used_market_changed

const SAVE_PATH         := "user://save.json"
const AUTOSAVE_INTERVAL := 30.0
const USED_MARKET_SIZE  := 10

const PLANE_CATALOG: Array = [
	{
		"name": "Cessna 208 Caravan",
		"seats": 9, "price": 35000, "wear_per_flight": 1.5,
		"repair_cost_per_pct": 50.0, "repair_time_sec_per_pct": 0.8,
		"description": "Small regional prop",
	},
	{
		"name": "Pilatus PC-12",
		"seats": 9, "price": 95000, "wear_per_flight": 1.0,
		"repair_cost_per_pct": 60.0, "repair_time_sec_per_pct": 0.8,
		"description": "Durable single-engine turboprop",
	},
	{
		"name": "Beechcraft 1900D",
		"seats": 19, "price": 175000, "wear_per_flight": 1.8,
		"repair_cost_per_pct": 85.0, "repair_time_sec_per_pct": 1.0,
		"description": "19-seat commuter turboprop",
	},
	{
		"name": "DHC-6 Twin Otter",
		"seats": 19, "price": 220000, "wear_per_flight": 1.6,
		"repair_cost_per_pct": 90.0, "repair_time_sec_per_pct": 1.0,
		"description": "Rugged 19-seat STOL turboprop",
	},
	{
		"name": "Saab 340B",
		"seats": 34, "price": 380000, "wear_per_flight": 1.5,
		"repair_cost_per_pct": 130.0, "repair_time_sec_per_pct": 1.2,
		"description": "34-seat regional turboprop",
	},
	{
		"name": "ATR 42-600",
		"seats": 48, "price": 600000, "wear_per_flight": 1.4,
		"repair_cost_per_pct": 180.0, "repair_time_sec_per_pct": 1.5,
		"description": "48-seat modern turboprop",
	},
	{
		"name": "Embraer ERJ-145",
		"seats": 50, "price": 850000, "wear_per_flight": 1.3,
		"repair_cost_per_pct": 220.0, "repair_time_sec_per_pct": 1.8,
		"description": "50-seat regional jet",
	},
	{
		"name": "Bombardier Q400",
		"seats": 78, "price": 1200000, "wear_per_flight": 1.4,
		"repair_cost_per_pct": 280.0, "repair_time_sec_per_pct": 1.8,
		"description": "78-seat high-speed turboprop",
	},
	{
		"name": "Boeing 737-700",
		"seats": 128, "price": 3500000, "wear_per_flight": 1.2,
		"repair_cost_per_pct": 600.0, "repair_time_sec_per_pct": 2.2,
		"description": "128-seat narrowbody jet",
	},
	{
		"name": "Airbus A320neo",
		"seats": 165, "price": 6000000, "wear_per_flight": 1.1,
		"repair_cost_per_pct": 900.0, "repair_time_sec_per_pct": 2.8,
		"description": "165-seat fuel-efficient jet",
	},
]

var airline_name   := "Sky Haven Airways"
var cash           := 75000.0
var time_scale     := 1.0
var total_earned   := 0.0
var total_spent    := 0.0
var flight_log     : Array = []   # [{route, amount}], newest first, capped at 60

var planes: Array = [
	{
		"name": "Cessna 208 Caravan",
		"seats": 9,
		"condition": 100.0,
		"status": "grounded",       # grounded | flying | maintenance
		"assigned_route": -1,
		"wear_per_flight": 1.5,
		"repair_cost_per_pct": 50.0,
		"repair_time_sec_per_pct": 0.8,
		"repair_time_left": 0.0,
		"repair_total_time": 0.0,
		"total_flights": 0,
	}
]

var routes: Array = [
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "AVP", "destination_city": "Wilkes-Barre",
		"distance_mi": 81, "ticket_price": 89.0, "occupancy_rate": 0.80,
		"flight_duration_sec": 60.0,
		"locked": false, "unlock_cost": 0.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "BOS", "destination_city": "Boston",
		"distance_mi": 300, "ticket_price": 129.0, "occupancy_rate": 0.82,
		"flight_duration_sec": 225.0,
		"locked": true, "unlock_cost": 5000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "DTW", "destination_city": "Detroit",
		"distance_mi": 400, "ticket_price": 119.0, "occupancy_rate": 0.78,
		"flight_duration_sec": 300.0,
		"locked": true, "unlock_cost": 8000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "ORD", "destination_city": "Chicago",
		"distance_mi": 668, "ticket_price": 159.0, "occupancy_rate": 0.85,
		"flight_duration_sec": 500.0,
		"locked": true, "unlock_cost": 15000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "ATL", "destination_city": "Atlanta",
		"distance_mi": 655, "ticket_price": 149.0, "occupancy_rate": 0.83,
		"flight_duration_sec": 490.0,
		"locked": true, "unlock_cost": 18000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "DFW", "destination_city": "Dallas",
		"distance_mi": 907, "ticket_price": 179.0, "occupancy_rate": 0.80,
		"flight_duration_sec": 680.0,
		"locked": true, "unlock_cost": 30000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "MIA", "destination_city": "Miami",
		"distance_mi": 990, "ticket_price": 199.0, "occupancy_rate": 0.87,
		"flight_duration_sec": 740.0,
		"locked": true, "unlock_cost": 35000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "DEN", "destination_city": "Denver",
		"distance_mi": 1471, "ticket_price": 219.0, "occupancy_rate": 0.79,
		"flight_duration_sec": 1100.0,
		"locked": true, "unlock_cost": 60000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "LAX", "destination_city": "Los Angeles",
		"distance_mi": 2375, "ticket_price": 289.0, "occupancy_rate": 0.84,
		"flight_duration_sec": 1780.0,
		"locked": true, "unlock_cost": 120000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "SEA", "destination_city": "Seattle",
		"distance_mi": 2598, "ticket_price": 299.0, "occupancy_rate": 0.82,
		"flight_duration_sec": 1950.0,
		"locked": true, "unlock_cost": 150000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
]

var used_market: Array = []

var _autosave_timer  := 0.0
var _window_focused  := true
var _rng             := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	get_tree().root.focus_entered.connect(func(): _window_focused = true)
	get_tree().root.focus_exited.connect(func(): _window_focused = false)
	load_game()
	while used_market.size() < USED_MARKET_SIZE:
		used_market.append(_gen_used_listing())

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
	cash         += revenue
	total_earned += revenue
	cash_changed.emit()
	plane["condition"] = maxf(0.0, float(plane["condition"]) - float(plane["wear_per_flight"]))
	plane["total_flights"] = int(plane["total_flights"]) + 1
	flight_log.push_front({
		"route":  "%s -> %s" % [route["origin"], route["destination"]],
		"amount": revenue,
	})
	if flight_log.size() > 60:
		flight_log.resize(60)
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

# ── Route unlock ─────────────────────────────────────────────────────────────

func unlock_route(route_idx: int) -> void:
	var route: Dictionary = routes[route_idx]
	if not route["locked"]:
		return
	var cost := float(route["unlock_cost"])
	if cash < cost:
		return
	cash        -= cost
	total_spent += cost
	cash_changed.emit()
	route["locked"] = false
	assignment_changed.emit()

# ── Purchase ──────────────────────────────────────────────────────────────────

func _gen_used_listing() -> Dictionary:
	# Weight toward cheaper planes: pick the lower of two random indices
	var a := _rng.randi_range(0, PLANE_CATALOG.size() - 1)
	var b := _rng.randi_range(0, PLANE_CATALOG.size() - 1)
	var entry: Dictionary = PLANE_CATALOG[mini(a, b)]
	var condition := _rng.randf_range(50.0, 75.0)
	var price     := float(entry["price"]) * (condition / 100.0) * 0.75
	return {
		"name":                    entry["name"],
		"seats":                   entry["seats"],
		"condition":               condition,
		"price":                   price,
		"wear_per_flight":         entry["wear_per_flight"],
		"repair_cost_per_pct":     entry["repair_cost_per_pct"],
		"repair_time_sec_per_pct": entry["repair_time_sec_per_pct"],
		"description":             entry["description"],
	}

func buy_used_plane(market_idx: int) -> void:
	var listing: Dictionary = used_market[market_idx]
	if cash < float(listing["price"]):
		return
	var price := float(listing["price"])
	cash        -= price
	total_spent += price
	cash_changed.emit()
	planes.append({
		"name":                    listing["name"],
		"seats":                   listing["seats"],
		"condition":               listing["condition"],
		"status":                  "grounded",
		"assigned_route":          -1,
		"wear_per_flight":         listing["wear_per_flight"],
		"repair_cost_per_pct":     listing["repair_cost_per_pct"],
		"repair_time_sec_per_pct": listing["repair_time_sec_per_pct"],
		"repair_time_left":        0.0,
		"repair_total_time":       0.0,
		"total_flights":           0,
	})
	used_market[market_idx] = _gen_used_listing()
	used_market_changed.emit()
	assignment_changed.emit()

func buy_plane(catalog_idx: int) -> void:
	var entry: Dictionary = PLANE_CATALOG[catalog_idx]
	if cash < float(entry["price"]):
		return
	var ep := float(entry["price"])
	cash        -= ep
	total_spent += ep
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
	cash        -= cost
	total_spent += cost
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
		"total_earned": total_earned,
		"total_spent":  total_spent,
		"flight_log":   flight_log.duplicate(true),
		"planes": planes.duplicate(true),
		"routes": routes.duplicate(true),
		"used_market": used_market.duplicate(true),
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
	cash         = float(data.get("cash",         cash))
	total_earned = float(data.get("total_earned", total_earned))
	total_spent  = float(data.get("total_spent",  total_spent))
	if data.has("flight_log"):
		flight_log = data["flight_log"]
	if data.has("planes"):
		planes = data["planes"]
	if data.has("routes"):
		var saved: Array = data["routes"]
		# Merge saved mutable state into the canonical route list by matching
		# origin+destination so adding new routes never breaks old saves.
		for saved_route in saved:
			for route in routes:
				if route["origin"] == saved_route["origin"] and route["destination"] == saved_route["destination"]:
					route["locked"]          = saved_route.get("locked", route["locked"])
					route["assigned_plane"]  = saved_route.get("assigned_plane", -1)
					route["status"]          = saved_route.get("status", "inactive")
					route["flight_progress"] = saved_route.get("flight_progress", 0.0)
					break
	if data.has("used_market"):
		used_market = data["used_market"]
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
			var rev := float(route["ticket_price"]) * float(plane["seats"]) * float(route["occupancy_rate"])
			cash         += rev
			total_earned += rev
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
