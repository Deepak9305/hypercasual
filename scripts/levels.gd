class_name Levels
extends RefCounted
const CHAPTERS = ["LEARN THE TOOLS", "DESIGN A RESCUE"]

static func hazard(kind: String, position: Vector2, velocity: Vector2 = Vector2.ZERO, delay: float = 0.0, motion: String = "fall", extent: Vector2 = Vector2(100, 100)) -> Dictionary:
	return {"kind": kind, "position": position, "velocity": velocity, "delay": delay, "motion": motion, "size": extent}

static func tool(kind: String, at: Vector2, direction: int = 0) -> Dictionary:
	return {"kind": kind, "position": at, "direction": direction}

static func mechanism(kind: String, at: Vector2, size_: Vector2, link: String = "") -> Dictionary:
	return {"kind": kind, "position": at, "size": size_, "link": link}

static func all() -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	var names = ["SPECIAL DELIVERY", "CHANGE DIRECTION", "SPRING INTO ACTION", "HOLD THE DOOR", "WRONG ADDRESS", "FRAGILE DELIVERY", "AIR MAIL", "EXPRESS ROUTE"]
	for i in range(names.size()):
		var level = LevelDefinition.new()
		level.id = ["shield", "redirect", "jump", "hold", "address", "fragile", "air", "express"][i]
		level.title = names[i]
		level.chapter = 0 if i < 4 else 1
		level.auto_freeze = i < 4
		level.background = "courtyard" if i < 4 else "workshop" if i < 7 else "rooftop"
		level.tool_budget = 1 if i < 4 else 2
		level.par_tools = 1 if i < 4 or i == 4 or i == 6 else 2
		result.append(level)
	result[0].hazards = [hazard("crate", Vector2(320, 340))]
	result[0].candidates = PackedStringArray(["umbrella"])
	result[0].solution = [tool("umbrella", Vector2(320, 750), 4)]
	result[0].hints = PackedStringArray(["Shield the courier. The parcel stays dangerous after impact.", "Place the umbrella under the parcel and point its arrow LEFT."])
	result[1].hazards = [hazard("trolley", Vector2(790, 975), Vector2(-250, 0), 0, "roll", Vector2(110, 120))]
	result[1].candidates = PackedStringArray(["ramp", "umbrella"])
	result[1].solution = [tool("ramp", Vector2(460, 1020))]
	result[1].hints = PackedStringArray(["Send the trolley up and away from the courier.", "Put a ramp at the right of the path, arrow RIGHT. Tap TURN to change direction."])
	result[2].hazards = [hazard("branch", Vector2(790, 989), Vector2(-180, 0), 0, "roll", Vector2(150, 72))]
	result[2].candidates = PackedStringArray(["spring", "ramp"])
	result[2].solution = [tool("spring", Vector2(340, 1020))]
	result[2].hints = PackedStringArray(["A spring launches the courier or any falling object.", "Spring just ahead of the courier to clear the branch."])
	result[3].candidates = PackedStringArray(["crate", "fan"])
	result[3].environment = [mechanism("plate", Vector2(465, 1035), Vector2(125, 16), "exit"), mechanism("gate", Vector2(625, 925), Vector2(28, 230), "exit")]
	result[3].solution = [tool("crate", Vector2(465, 990))]
	result[3].hints = PackedStringArray(["A pressure plate opens its matching gate while a weight stays on it.", "Drop a crate on the striped plate. The courier can step over a low crate while it holds the gate open."])
	# A parcel must land on the raised switch, rather than merely miss the courier.
	result[4].hazards = [hazard("crate", Vector2(330, 320))]
	result[4].environment = [mechanism("switch", Vector2(555, 875), Vector2(130, 22), "exit"), mechanism("gate", Vector2(635, 925), Vector2(28, 230), "exit")]
	result[4].solution = [tool("umbrella", Vector2(330, 720))]
	result[4].hints = PackedStringArray(["Parcel → umbrella → raised switch → gate. Missing the courier is only half the plan.", "Point the umbrella RIGHT beneath the parcel. Land it on the gold switch above the path."])
	# Shelf catches a player crate; its roof catches the parcel before the bridge.
	result[5].par_tools = 1
	result[5].hazards = [hazard("crate", Vector2(330, 320))]
	result[5].environment = [mechanism("bridge", Vector2(590, 1055), Vector2(320, 30)), mechanism("fragile_shelf", Vector2(555, 880), Vector2(145, 20))]
	result[5].solution = [tool("umbrella", Vector2(330, 720)), tool("crate", Vector2(555, 825))]
	result[5].hints = PackedStringArray(["The shield sends a heavy parcel toward a fragile bridge. Catch it before it lands.", "Umbrella RIGHT beneath the parcel, then place a crate on the raised shelf as a catcher."])
	result[6].hazards = [hazard("crate", Vector2(355, 390), Vector2.ZERO, 0, "fall", Vector2(85, 85))]
	result[6].environment = [mechanism("plate", Vector2(565, 1035), Vector2(130, 16), "exit"), mechanism("gate", Vector2(655, 925), Vector2(28, 230), "exit")]
	result[6].solution = [tool("fan", Vector2(205, 675))]
	result[6].hints = PackedStringArray(["Fan → falling crate → pressure plate → gate. Aim across the fall.", "Aim a fan RIGHT from the left of the falling crate. Its wind must carry the crate onto the plate."])
	result[7].tool_budget = 3
	result[7].courier_speed = 120.0
	result[7].timeout = 14.0
	result[7].environment = [mechanism("plate", Vector2(125, 1035), Vector2(110, 16), "exit"), mechanism("gate", Vector2(650, 925), Vector2(28, 230), "exit"), mechanism("platform", Vector2(480, 990), Vector2(115, 25)), mechanism("gap", Vector2(472, 1060), Vector2(235, 50)), mechanism("conveyor", Vector2(640, 1040), Vector2(160, 14))]
	result[7].solution = [tool("crate", Vector2(125, 990)), tool("spring", Vector2(335, 1020))]
	result[7].hints = PackedStringArray(["Crate holds the gate. Spring reaches the moving platform. Time the launch to cross the gap.", "Leave a crate on the first plate, then spring at the edge of the gap. The conveyor carries the courier through the open gate."])
	return result
