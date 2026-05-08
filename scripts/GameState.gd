extends Node

signal assignment_changed
signal flight_completed(route_idx: int)
signal repair_completed(plane_idx: int)
signal cash_changed
signal used_market_changed

const SAVE_PATH         := "user://save.json"
const AUTOSAVE_INTERVAL := 30.0
const USED_MARKET_SIZE  := 10
const MIN_LOCKED_ROUTES := 5

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

# Routes unlocked progressively; always maintain MIN_LOCKED_ROUTES locked entries
const ROUTE_POOL: Array = [
	{"origin":"JFK","origin_city":"New York","destination":"BOS","destination_city":"Boston",
	 "distance_mi":187,"ticket_price":99.0,"occupancy_rate":0.83,"flight_duration_sec":138.0,"unlock_cost":4000.0},
	{"origin":"JFK","origin_city":"New York","destination":"ORD","destination_city":"Chicago",
	 "distance_mi":740,"ticket_price":159.0,"occupancy_rate":0.84,"flight_duration_sec":548.0,"unlock_cost":22000.0},
	{"origin":"JFK","origin_city":"New York","destination":"MIA","destination_city":"Miami",
	 "distance_mi":1090,"ticket_price":189.0,"occupancy_rate":0.85,"flight_duration_sec":807.0,"unlock_cost":40000.0},
	{"origin":"JFK","origin_city":"New York","destination":"LAX","destination_city":"Los Angeles",
	 "distance_mi":2475,"ticket_price":299.0,"occupancy_rate":0.86,"flight_duration_sec":1832.0,"unlock_cost":130000.0},
	{"origin":"JFK","origin_city":"New York","destination":"LHR","destination_city":"London",
	 "distance_mi":3459,"ticket_price":699.0,"occupancy_rate":0.88,"flight_duration_sec":2560.0,"unlock_cost":800000.0},
	{"origin":"JFK","origin_city":"New York","destination":"CDG","destination_city":"Paris",
	 "distance_mi":3635,"ticket_price":749.0,"occupancy_rate":0.87,"flight_duration_sec":2690.0,"unlock_cost":900000.0},
	{"origin":"JFK","origin_city":"New York","destination":"NRT","destination_city":"Tokyo",
	 "distance_mi":6760,"ticket_price":1299.0,"occupancy_rate":0.86,"flight_duration_sec":5003.0,"unlock_cost":2600000.0},
	{"origin":"ATL","origin_city":"Atlanta","destination":"MIA","destination_city":"Miami",
	 "distance_mi":662,"ticket_price":129.0,"occupancy_rate":0.86,"flight_duration_sec":490.0,"unlock_cost":22000.0},
	{"origin":"ATL","origin_city":"Atlanta","destination":"ORD","destination_city":"Chicago",
	 "distance_mi":606,"ticket_price":139.0,"occupancy_rate":0.82,"flight_duration_sec":449.0,"unlock_cost":20000.0},
	{"origin":"ATL","origin_city":"Atlanta","destination":"CUN","destination_city":"Cancun",
	 "distance_mi":1095,"ticket_price":249.0,"occupancy_rate":0.85,"flight_duration_sec":810.0,"unlock_cost":45000.0},
	{"origin":"ATL","origin_city":"Atlanta","destination":"LAX","destination_city":"Los Angeles",
	 "distance_mi":1946,"ticket_price":239.0,"occupancy_rate":0.83,"flight_duration_sec":1440.0,"unlock_cost":90000.0},
	{"origin":"ATL","origin_city":"Atlanta","destination":"LHR","destination_city":"London",
	 "distance_mi":4197,"ticket_price":799.0,"occupancy_rate":0.86,"flight_duration_sec":3106.0,"unlock_cost":1000000.0},
	{"origin":"ORD","origin_city":"Chicago","destination":"MIA","destination_city":"Miami",
	 "distance_mi":1197,"ticket_price":179.0,"occupancy_rate":0.83,"flight_duration_sec":886.0,"unlock_cost":50000.0},
	{"origin":"ORD","origin_city":"Chicago","destination":"SEA","destination_city":"Seattle",
	 "distance_mi":1721,"ticket_price":209.0,"occupancy_rate":0.82,"flight_duration_sec":1273.0,"unlock_cost":70000.0},
	{"origin":"ORD","origin_city":"Chicago","destination":"LAX","destination_city":"Los Angeles",
	 "distance_mi":1745,"ticket_price":219.0,"occupancy_rate":0.84,"flight_duration_sec":1292.0,"unlock_cost":75000.0},
	{"origin":"ORD","origin_city":"Chicago","destination":"LHR","destination_city":"London",
	 "distance_mi":3942,"ticket_price":799.0,"occupancy_rate":0.86,"flight_duration_sec":2917.0,"unlock_cost":1100000.0},
	{"origin":"ORD","origin_city":"Chicago","destination":"NRT","destination_city":"Tokyo",
	 "distance_mi":6299,"ticket_price":1199.0,"occupancy_rate":0.85,"flight_duration_sec":4661.0,"unlock_cost":2200000.0},
	{"origin":"LAX","origin_city":"Los Angeles","destination":"LAS","destination_city":"Las Vegas",
	 "distance_mi":236,"ticket_price":79.0,"occupancy_rate":0.87,"flight_duration_sec":175.0,"unlock_cost":5000.0},
	{"origin":"LAX","origin_city":"Los Angeles","destination":"SFO","destination_city":"San Francisco",
	 "distance_mi":337,"ticket_price":89.0,"occupancy_rate":0.84,"flight_duration_sec":249.0,"unlock_cost":8000.0},
	{"origin":"LAX","origin_city":"Los Angeles","destination":"HNL","destination_city":"Honolulu",
	 "distance_mi":2556,"ticket_price":449.0,"occupancy_rate":0.86,"flight_duration_sec":1892.0,"unlock_cost":180000.0},
	{"origin":"LAX","origin_city":"Los Angeles","destination":"LHR","destination_city":"London",
	 "distance_mi":5456,"ticket_price":1099.0,"occupancy_rate":0.85,"flight_duration_sec":4037.0,"unlock_cost":1900000.0},
	{"origin":"LAX","origin_city":"Los Angeles","destination":"NRT","destination_city":"Tokyo",
	 "distance_mi":5479,"ticket_price":1099.0,"occupancy_rate":0.87,"flight_duration_sec":4055.0,"unlock_cost":1800000.0},
	{"origin":"LAX","origin_city":"Los Angeles","destination":"SYD","destination_city":"Sydney",
	 "distance_mi":7488,"ticket_price":1299.0,"occupancy_rate":0.84,"flight_duration_sec":5541.0,"unlock_cost":3000000.0},
	{"origin":"MIA","origin_city":"Miami","destination":"CUN","destination_city":"Cancun",
	 "distance_mi":528,"ticket_price":149.0,"occupancy_rate":0.87,"flight_duration_sec":391.0,"unlock_cost":15000.0},
	{"origin":"MIA","origin_city":"Miami","destination":"BOG","destination_city":"Bogota",
	 "distance_mi":1148,"ticket_price":229.0,"occupancy_rate":0.82,"flight_duration_sec":850.0,"unlock_cost":55000.0},
	{"origin":"MIA","origin_city":"Miami","destination":"MEX","destination_city":"Mexico City",
	 "distance_mi":1298,"ticket_price":239.0,"occupancy_rate":0.83,"flight_duration_sec":961.0,"unlock_cost":65000.0},
	{"origin":"MIA","origin_city":"Miami","destination":"GRU","destination_city":"Sao Paulo",
	 "distance_mi":4084,"ticket_price":799.0,"occupancy_rate":0.83,"flight_duration_sec":3022.0,"unlock_cost":950000.0},
	{"origin":"MIA","origin_city":"Miami","destination":"LHR","destination_city":"London",
	 "distance_mi":4420,"ticket_price":849.0,"occupancy_rate":0.85,"flight_duration_sec":3271.0,"unlock_cost":1200000.0},
	{"origin":"DFW","origin_city":"Dallas","destination":"ORD","destination_city":"Chicago",
	 "distance_mi":802,"ticket_price":149.0,"occupancy_rate":0.83,"flight_duration_sec":594.0,"unlock_cost":30000.0},
	{"origin":"DFW","origin_city":"Dallas","destination":"CUN","destination_city":"Cancun",
	 "distance_mi":1046,"ticket_price":219.0,"occupancy_rate":0.85,"flight_duration_sec":774.0,"unlock_cost":40000.0},
	{"origin":"DFW","origin_city":"Dallas","destination":"LAX","destination_city":"Los Angeles",
	 "distance_mi":1235,"ticket_price":169.0,"occupancy_rate":0.84,"flight_duration_sec":914.0,"unlock_cost":45000.0},
	{"origin":"DFW","origin_city":"Dallas","destination":"LHR","destination_city":"London",
	 "distance_mi":4746,"ticket_price":899.0,"occupancy_rate":0.85,"flight_duration_sec":3512.0,"unlock_cost":1500000.0},
	{"origin":"DFW","origin_city":"Dallas","destination":"NRT","destination_city":"Tokyo",
	 "distance_mi":6551,"ticket_price":1249.0,"occupancy_rate":0.84,"flight_duration_sec":4848.0,"unlock_cost":2300000.0},
	{"origin":"SEA","origin_city":"Seattle","destination":"LAX","destination_city":"Los Angeles",
	 "distance_mi":954,"ticket_price":149.0,"occupancy_rate":0.84,"flight_duration_sec":706.0,"unlock_cost":35000.0},
	{"origin":"SEA","origin_city":"Seattle","destination":"LHR","destination_city":"London",
	 "distance_mi":4776,"ticket_price":899.0,"occupancy_rate":0.84,"flight_duration_sec":3534.0,"unlock_cost":1600000.0},
	{"origin":"SEA","origin_city":"Seattle","destination":"NRT","destination_city":"Tokyo",
	 "distance_mi":4783,"ticket_price":999.0,"occupancy_rate":0.85,"flight_duration_sec":3540.0,"unlock_cost":1700000.0},
	{"origin":"BOS","origin_city":"Boston","destination":"MIA","destination_city":"Miami",
	 "distance_mi":1258,"ticket_price":179.0,"occupancy_rate":0.84,"flight_duration_sec":931.0,"unlock_cost":50000.0},
	{"origin":"BOS","origin_city":"Boston","destination":"LAX","destination_city":"Los Angeles",
	 "distance_mi":2596,"ticket_price":299.0,"occupancy_rate":0.83,"flight_duration_sec":1921.0,"unlock_cost":140000.0},
	{"origin":"BOS","origin_city":"Boston","destination":"LHR","destination_city":"London",
	 "distance_mi":3267,"ticket_price":649.0,"occupancy_rate":0.88,"flight_duration_sec":2418.0,"unlock_cost":700000.0},
	{"origin":"BOS","origin_city":"Boston","destination":"CDG","destination_city":"Paris",
	 "distance_mi":3446,"ticket_price":699.0,"occupancy_rate":0.87,"flight_duration_sec":2550.0,"unlock_cost":850000.0},
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
	# ── Second wave: more domestic ──────────────────────────────────────────────
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "YYZ", "destination_city": "Toronto",
		"distance_mi": 330, "ticket_price": 139.0, "occupancy_rate": 0.81,
		"flight_duration_sec": 244.0,
		"locked": true, "unlock_cost": 12000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "MCO", "destination_city": "Orlando",
		"distance_mi": 860, "ticket_price": 149.0, "occupancy_rate": 0.88,
		"flight_duration_sec": 636.0,
		"locked": true, "unlock_cost": 25000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "CUN", "destination_city": "Cancun",
		"distance_mi": 1715, "ticket_price": 289.0, "occupancy_rate": 0.85,
		"flight_duration_sec": 1270.0,
		"locked": true, "unlock_cost": 75000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "LAS", "destination_city": "Las Vegas",
		"distance_mi": 2175, "ticket_price": 239.0, "occupancy_rate": 0.86,
		"flight_duration_sec": 1610.0,
		"locked": true, "unlock_cost": 80000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "SFO", "destination_city": "San Francisco",
		"distance_mi": 2520, "ticket_price": 269.0, "occupancy_rate": 0.84,
		"flight_duration_sec": 1865.0,
		"locked": true, "unlock_cost": 100000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "ANC", "destination_city": "Anchorage",
		"distance_mi": 3370, "ticket_price": 349.0, "occupancy_rate": 0.76,
		"flight_duration_sec": 2494.0,
		"locked": true, "unlock_cost": 200000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "HNL", "destination_city": "Honolulu",
		"distance_mi": 4985, "ticket_price": 499.0, "occupancy_rate": 0.83,
		"flight_duration_sec": 3690.0,
		"locked": true, "unlock_cost": 500000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	# ── International ───────────────────────────────────────────────────────────
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "LHR", "destination_city": "London",
		"distance_mi": 3530, "ticket_price": 649.0, "occupancy_rate": 0.88,
		"flight_duration_sec": 2612.0,
		"locked": true, "unlock_cost": 750000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "CDG", "destination_city": "Paris",
		"distance_mi": 3670, "ticket_price": 699.0, "occupancy_rate": 0.87,
		"flight_duration_sec": 2716.0,
		"locked": true, "unlock_cost": 850000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "FRA", "destination_city": "Frankfurt",
		"distance_mi": 3880, "ticket_price": 729.0, "occupancy_rate": 0.86,
		"flight_duration_sec": 2872.0,
		"locked": true, "unlock_cost": 950000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "DXB", "destination_city": "Dubai",
		"distance_mi": 6870, "ticket_price": 1099.0, "occupancy_rate": 0.85,
		"flight_duration_sec": 5084.0,
		"locked": true, "unlock_cost": 2000000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "NRT", "destination_city": "Tokyo",
		"distance_mi": 6755, "ticket_price": 1299.0, "occupancy_rate": 0.86,
		"flight_duration_sec": 4999.0,
		"locked": true, "unlock_cost": 2500000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
	{
		"origin": "PHL", "origin_city": "Philadelphia",
		"destination": "SYD", "destination_city": "Sydney",
		"distance_mi": 9940, "ticket_price": 1599.0, "occupancy_rate": 0.84,
		"flight_duration_sec": 7355.0,
		"locked": true, "unlock_cost": 5000000.0,
		"assigned_plane": -1, "status": "inactive", "flight_progress": 0.0,
	},
]

var used_market: Array = []
var routes_pool_cursor: int = 0

var _autosave_timer  := 0.0
var _window_focused  := true
var _rng             := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	get_tree().root.focus_entered.connect(func(): _window_focused = true)
	get_tree().root.focus_exited.connect(func():
		_window_focused = false
		save_game()
	)
	load_game()
	_reconcile_state()
	while used_market.size() < USED_MARKET_SIZE:
		used_market.append(_gen_used_listing())
	_replenish_routes()

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

func _replenish_routes() -> void:
	var locked_count := 0
	for route in routes:
		if route.get("locked", false):
			locked_count += 1
	while locked_count < MIN_LOCKED_ROUTES and routes_pool_cursor < ROUTE_POOL.size():
		var entry: Dictionary = ROUTE_POOL[routes_pool_cursor]
		routes_pool_cursor += 1
		routes.append({
			"origin":              entry["origin"],
			"origin_city":         entry["origin_city"],
			"destination":         entry["destination"],
			"destination_city":    entry["destination_city"],
			"distance_mi":         entry["distance_mi"],
			"ticket_price":        entry["ticket_price"],
			"occupancy_rate":      entry["occupancy_rate"],
			"flight_duration_sec": entry["flight_duration_sec"],
			"locked":              true,
			"unlock_cost":         entry["unlock_cost"],
			"assigned_plane":      -1,
			"status":              "inactive",
			"flight_progress":     0.0,
		})
		locked_count += 1

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
			var route_idx: int = int(plane["assigned_route"])
			if route_idx != -1:
				plane["status"] = "flying"
				routes[route_idx]["status"] = "active"
			else:
				plane["status"] = "grounded"
			repair_completed.emit(i)

	for i in routes.size():
		var route: Dictionary = routes[i]
		if route["status"] != "active":
			continue
		var plane_idx: int = route["assigned_plane"]
		var plane: Dictionary = planes[plane_idx]
		if float(plane["condition"]) <= 0.0:
			plane["status"] = "grounded"
			route["status"] = "inactive"
			assignment_changed.emit()
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
	save_game()

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
	save_game()

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
	_replenish_routes()
	assignment_changed.emit()
	save_game()

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
	save_game()

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
	save_game()

# ── Repair ────────────────────────────────────────────────────────────────────

static func repair_cost_for_plane(plane: Dictionary) -> float:
	var damage := 100.0 - float(plane["condition"])
	if damage <= 0.0:
		return 0.0
	var age_mult := 1.0 + int(plane["total_flights"]) * 0.005
	return damage * float(plane["repair_cost_per_pct"]) * age_mult

func total_repair_cost() -> float:
	var total := 0.0
	for plane in planes:
		if plane["status"] != "maintenance" and float(plane["condition"]) < 100.0:
			total += repair_cost_for_plane(plane)
	return total

func repair_all_planes() -> void:
	var total := total_repair_cost()
	if total <= 0.0 or cash < total:
		return
	for i in planes.size():
		var plane: Dictionary = planes[i]
		if plane["status"] == "maintenance" or float(plane["condition"]) >= 100.0:
			continue
		var damage := 100.0 - float(plane["condition"])
		var cost := repair_cost_for_plane(plane)
		cash        -= cost
		total_spent += cost
		var route_idx: int = int(plane["assigned_route"])
		if route_idx != -1:
			routes[route_idx]["status"] = "inactive"
			routes[route_idx]["flight_progress"] = 0.0
		var repair_time := damage * float(plane["repair_time_sec_per_pct"])
		plane["repair_time_left"] = repair_time
		plane["repair_total_time"] = repair_time
		plane["status"] = "maintenance"
	cash_changed.emit()
	assignment_changed.emit()
	save_game()

static func sell_price_for_plane(plane: Dictionary) -> float:
	var base := 0.0
	for entry in PLANE_CATALOG:
		if entry["name"] == plane["name"]:
			base = float(entry["price"])
			break
	if base <= 0.0:
		base = float(plane["repair_cost_per_pct"]) * 200.0
	return base * (float(plane["condition"]) / 100.0) * 0.5

func sell_plane(plane_idx: int) -> void:
	var plane: Dictionary = planes[plane_idx]
	if plane["status"] == "flying":
		return
	var route_idx: int = int(plane["assigned_route"])
	if route_idx != -1:
		routes[route_idx]["assigned_plane"] = -1
		routes[route_idx]["status"] = "inactive"
		routes[route_idx]["flight_progress"] = 0.0
	var price := sell_price_for_plane(plane)
	cash += price
	cash_changed.emit()
	planes.remove_at(plane_idx)
	# Fix route assigned_plane indices shifted by removal
	for route in routes:
		var ap: int = int(route["assigned_plane"])
		if ap > plane_idx:
			route["assigned_plane"] = ap - 1
	assignment_changed.emit()
	save_game()

func repair_plane(plane_idx: int) -> void:
	var plane: Dictionary = planes[plane_idx]
	if plane["status"] == "maintenance":
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
	# Pause route if currently flying — it will auto-resume when repair completes
	var route_idx: int = int(plane["assigned_route"])
	if route_idx != -1:
		routes[route_idx]["status"] = "inactive"
		routes[route_idx]["flight_progress"] = 0.0
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
		"routes_pool_cursor": routes_pool_cursor,
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
		routes = data["routes"]
	if data.has("routes_pool_cursor"):
		routes_pool_cursor = int(data["routes_pool_cursor"])
	if data.has("used_market"):
		used_market = data["used_market"]
	var elapsed := Time.get_unix_time_from_system() - float(data.get("timestamp", Time.get_unix_time_from_system()))
	if elapsed > 0.0:
		_simulate_offline(elapsed)

func _reconcile_state() -> void:
	# Fix planes that are grounded but cross-assigned to a route — start them flying.
	# This repairs saves corrupted by the offline-repair bug (repair completed offline
	# but route was never resumed).
	for i in planes.size():
		var plane: Dictionary = planes[i]
		var route_idx: int = int(plane["assigned_route"])
		if route_idx < 0 or route_idx >= routes.size():
			plane["assigned_route"] = -1
			continue
		var route: Dictionary = routes[route_idx]
		if int(route["assigned_plane"]) == i \
				and plane["status"] == "grounded" \
				and float(plane["condition"]) > 0.0:
			plane["status"] = "flying"
			route["status"] = "active"

func _simulate_offline(elapsed: float) -> void:
	for i in planes.size():
		var plane: Dictionary = planes[i]
		if plane["status"] != "maintenance":
			continue
		plane["repair_time_left"] = maxf(0.0, float(plane["repair_time_left"]) - elapsed)
		if float(plane["repair_time_left"]) <= 0.0:
			plane["repair_total_time"] = 0.0
			plane["condition"] = 100.0
			var route_idx: int = int(plane["assigned_route"])
			if route_idx != -1:
				plane["status"] = "flying"
				routes[route_idx]["status"] = "active"
			else:
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
				route["status"] = "inactive"
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
