extends Node

func _ready() -> void:
	var day = await DonkiService.fetch_random_day()

	print(day["date"])
	print(day["message"])
	for e in day["events"]:
		print(e["name"], " | severity ", e["severity"], " | ", e["details"])
