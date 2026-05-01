extends Node

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
