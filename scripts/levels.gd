class_name Levels
extends RefCounted
const CHAPTERS = ["EVERYDAY DISASTERS", "CHAIN REACTION", "PERFECT INTERVENTION"]

static func hazard(kind: String, position: Vector2, velocity: Vector2 = Vector2.ZERO, delay: float = 0.0, motion: String = "fall", extent: Vector2 = Vector2(135, 135)) -> Dictionary:
	return {"kind": kind, "position": position, "velocity": velocity, "delay": delay, "motion": motion, "size": extent}

static func all() -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	var names = ["SPECIAL DELIVERY", "RUNAWAY TROLLEY", "CAFE CATCH", "BRANCH OFFICE", "BARREL TROUBLE", "SWING SHIFT", "ART ATTACK", "DOUBLE DROP", "MIND THE GAP", "GUST IN TIME", "ONE AFTER ANOTHER", "THE PERFECT DELIVERY"]
	for i in range(12):
		var level = LevelDefinition.new()
		level.title = names[i]
		level.chapter = i / 4
		level.background = ["courtyard", "workshop", "rooftop"][level.chapter]
		result.append(level)
	result[0].hazards = [hazard("crate", Vector2(320, 340), Vector2.ZERO, 0, "fall", Vector2(265, 265))]
	result[0].solution_position = Vector2(320, 750)
	result[0].hints = PackedStringArray(["The parcel is falling straight down.", "Put the umbrella between the parcel and the courier."])
	result[1].hazards = [hazard("trolley", Vector2(770, 958), Vector2(-265, 0), 0, "roll", Vector2(125, 140))]
	result[1].solution_prop = "ramp"
	result[1].solution_position = Vector2(455, 1020)
	result[1].hints = PackedStringArray(["That trolley needs a change of direction.", "A ramp on the right sends the trolley up and away."])
	result[2].hazards = [hazard("tray", Vector2(345, 340), Vector2(-12, 0), 0, "fall", Vector2(135, 65))]
	result[2].solution_position = Vector2(330, 720)
	result[2].hints = PackedStringArray(["A tray full of trouble is overhead.", "The umbrella can catch it before it reaches you."])
	result[3].hazards = [hazard("branch", Vector2(335, 330), Vector2(0, 10), 0, "fall", Vector2(200, 72))]
	result[3].solution_position = Vector2(335, 730)
	result[3].hints = PackedStringArray(["Watch the branch, not the leaves.", "Shield the path beneath the falling branch."])
	result[4].hazards = [hazard("barrel", Vector2(780, 975), Vector2(-285, 0), 0, "roll", Vector2(125, 125))]
	result[4].solution_prop = "ramp"
	result[4].solution_position = Vector2(460, 1020)
	result[4].hints = PackedStringArray(["Turn rolling motion into a leap.", "Put the ramp in the barrel's path to the right."])
	result[5].hazards = [hazard("crate", Vector2(600, 400), Vector2(-210, 100), 0, "swing", Vector2(140, 140))]
	result[5].solution_position = Vector2(335, 770)
	result[5].hints = PackedStringArray(["The cargo swings left before it drops.", "Shield the middle of the path, not the cargo's starting point."])
	result[6].hazards = [hazard("sculpture", Vector2(330, 320), Vector2.ZERO, 0, "fall", Vector2(115, 160))]
	result[6].solution_position = Vector2(330, 730)
	result[6].hints = PackedStringArray(["This masterpiece has terrible balance.", "Catch it with the umbrella above the courier's path."])
	result[7].hazards = [hazard("crate", Vector2(330, 330), Vector2.ZERO, 0, "fall", Vector2(135, 135)), hazard("crate", Vector2(350, 270), Vector2.ZERO, 0.4, "fall", Vector2(115, 115))]
	result[7].solution_position = Vector2(340, 750)
	result[7].hints = PackedStringArray(["Two parcels. One well-placed shield.", "Center the umbrella beneath both falling parcels."])
	result[8].mechanism = "platform"
	result[8].solution_prop = "spring"
	result[8].solution_position = Vector2(340, 1020)
	result[8].courier_speed = 120.0
	result[8].hazards = [hazard("barrel", Vector2(770, 975), Vector2(-205, 0), 0.45, "roll", Vector2(120, 120))]
	result[8].hints = PackedStringArray(["The platform is moving, and the path has a gap.", "Put the spring just before the gap to hop across."])
	result[9].hazards = [hazard("branch", Vector2(530, 320), Vector2(-150, 10), 0, "wind", Vector2(180, 80))]
	result[9].solution_position = Vector2(345, 790)
	result[9].hints = PackedStringArray(["Wind changes where the debris will land.", "Protect the left side of the path, ahead of the drifting debris."])
	result[10].hazards = [hazard("crate", Vector2(340, 320), Vector2.ZERO, 0, "fall", Vector2(125, 125)), hazard("tray", Vector2(430, 280), Vector2(-80, 0), 0.7, "fall", Vector2(125, 65))]
	result[10].solution_position = Vector2(365, 790)
	result[10].hints = PackedStringArray(["A second hazard follows the first.", "Place the umbrella where both falling paths cross."])
	result[11].mechanism = "finale"
	result[11].courier_speed = 120.0
	result[11].solution_prop = "spring"
	result[11].solution_position = Vector2(340, 1020)
	result[11].hazards = [hazard("barrel", Vector2(780, 975), Vector2(-220, 0), 0.2, "roll", Vector2(115, 115)), hazard("crate", Vector2(490, 300), Vector2.ZERO, 0.1, "fall", Vector2(120, 120))]
	result[11].hints = PackedStringArray(["One bounce can solve two problems.", "Spring over the barrel; the overhead awning deflects the parcel."])
	return result

