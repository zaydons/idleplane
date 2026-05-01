extends Node

signal assignment_changed

var airline_name := "Sky Haven Airways"
var cash := 25000.0

var planes: Array = [
	{
		"name": "Cessna 208 Caravan",
		"seats": 9,
		"condition": 100.0,
		"status": "grounded",       # grounded | flying | maintenance
		"assigned_route": -1,
		"wear_per_flight": 2.5,
		"repair_cost_per_pct": 50.0,
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
	}
]

func assign_plane_to_route(plane_idx: int, route_idx: int) -> void:
	# Detach plane from its current route
	var old_route: int = planes[plane_idx]["assigned_route"]
	if old_route != -1:
		routes[old_route]["assigned_plane"] = -1
		routes[old_route]["status"] = "inactive"
	# Detach whoever was on this route
	var old_plane: int = routes[route_idx]["assigned_plane"]
	if old_plane != -1:
		planes[old_plane]["status"] = "grounded"
		planes[old_plane]["assigned_route"] = -1
	# Assign
	planes[plane_idx]["assigned_route"] = route_idx
	planes[plane_idx]["status"] = "assigned"
	routes[route_idx]["assigned_plane"] = plane_idx
	routes[route_idx]["status"] = "active"
	assignment_changed.emit()

func unassign_route(route_idx: int) -> void:
	var plane_idx: int = routes[route_idx]["assigned_plane"]
	if plane_idx == -1:
		return
	planes[plane_idx]["status"] = "grounded"
	planes[plane_idx]["assigned_route"] = -1
	routes[route_idx]["assigned_plane"] = -1
	routes[route_idx]["status"] = "inactive"
	assignment_changed.emit()

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
