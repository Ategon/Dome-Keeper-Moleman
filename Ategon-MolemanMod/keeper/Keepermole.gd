extends Keeper

signal tileHit

onready  var DrillHitTestRay = $DrillHitTestRay

export (bool) var simulatedCarrySlowdown: = false

var knockbackDirection: = Vector2()
var moveSlowdown: = 0.0
var carrySlowdown: = 0.0
var spriteLockDuration: = 0.0
var moveStopSoundPlayBuffer: = 0.0
var moveStartSoundPlayBuffer: = 0.0
const maxCarryLineLength: = 150.0

var inTunnel := false
var isTunneling := false
var isChangingVacuum := false
var hasChangedVacuum := false
var curTunnelDistance := 0.0
var lastTileDir:Vector2
var lastTile:Node2D
var tileTunnelers := {}
var tunnelMarkerInstances := []
var hasUpdatedTunnelMarkers := false
var curTunnelerCooldown := 0.0

var tunnelLeaveAnimTimer = 0.0

var carryLines: = {}

var TUNNEL_MARKER = preload("res://mods-unpacked/Ategon-MolemanMod/tunneler/TunnelMarker.tscn")
var TUNNELER = preload("res://mods-unpacked/Ategon-MolemanMod/tunneler/TunnelerDrone.tscn")

func _ready():
	Data.listen(self, "keepermole.jetpackStage")

	$Sprite.frame = 0
	focussedUsable = null
	focussedCarryable = null

	$ThrusterLeft.emitting = true
	$ThrusterRight.emitting = true
	$ThrusterLeft / Booster.playing = true
	$ThrusterRight / Booster.playing = true

	Style.init(self)

	# Force upgrades.yaml to be re-read when playing with the moleman
	# TODO: A less hacky way of achieving this
	if not Data.ofOr("keepermole.maxSpeed", false):
		Data.gameProperties = {}
		Data.upgrades = {}
		Data.gadgets = {}
		Data.orderedUpgradeKeys = []

		Data.templates = {}
		Data._ready()

	self.addTranslations()
	
	Level.addTutorial(self, "moleman_intro")

func setSkin(skinId:String):
	pass

func addTranslations():
	var fs = File.new()
	var err = fs.open("res://content/keeper/keepermole/locale/" + TranslationServer.get_locale() + ".csv", File.READ)
	if err != OK:
		err = fs.open("res://content/keeper/keepermole/locale/en_US.csv", File.READ)

		if err != OK:
			return

	var translations = Translation.new()

	while not fs.eof_reached():
		var cols = fs.get_csv_line("\t")

		if cols.size() >= 2:
			translations.add_message(cols[0], cols[1])

	TranslationServer.add_translation(translations)

func propertyChanged(property:String, oldValue, newValue):
	match property:
		"keepermole.jetpackstage":
			setJetpackStage(newValue)


func _physics_process(delta):
	
	$Light.visible = position.y > 0
	
	for t in carryLines:
		var line = carryLines[t]
		line.set_point_position(0, global_position)
		line.set_point_position(1, t.global_position)
	
	updateCarry()
	
	if Data.of("keeper.insidestation") or GameWorld.paused or disabled or inTunnel:
		$MoveSound.stop()
		$CarryLoadSound.stop()
		return 

	control_thruster_vfx(move, moveDirectionInput.length() > 0.0, delta)
	
	var carrySize: = 0.0
	for i in range(1, carriedCarryables.size() + 1):
		if not is_instance_valid(carriedCarryables[i - 1]):
			continue
		carrySize += i / float(carriedCarryables[i - 1].carrierCount())
	
	moveSlowdown *= 1.0 - delta * Data.of("keepermole.slowdownRecovery") * 1.0
	
	var baseSpeed = currentSpeed()
	var desiredMove:Vector2 = moveDirectionInput * baseSpeed
	
	if abs(moveDirectionInput.x) < 0.1 and abs(moveDirectionInput.y) > 0.9:
		move.x *= 1 - delta * Data.of("keepermole.deceleration")
	if abs(moveDirectionInput.y) < 0.1 and abs(moveDirectionInput.x) > 0.9:
		move.y *= 1 - delta * Data.of("keepermole.deceleration")
	
	var moveChange = desiredMove * Data.of("keepermole.acceleration") * delta * max(0.1, 1.0 - moveSlowdown)
	moveChange = moveChange.clamped(max(0, desiredMove.length() - move.length()))
	move = (move * (1 - delta * Data.of("keepermole.deceleration"))) + moveChange
	
	var totalCarryImpulse = updateCarry()
	if simulatedCarrySlowdown:

		carrySlowdown = clamp(totalCarryImpulse.length() / 20.0, 0.0, 0.9)

	else :
		
		carrySlowdown = 0.01 * Data.of("keepermole.speedLossPerCarry") * carrySize
	
	var slowdown: = 1.0
	for c in carriedCarryables:
		slowdown *= 1.0 - (c.additionalSlowdown / c.carrierCount())
	
	var maxSpeed = baseSpeed * slowdown
	maxSpeed -= carrySlowdown * maxSpeed
	if externallyMoved:
		move *= 0
		moveDirectionInput *= 0
	move = move.clamped(max(0, maxSpeed))
	
	var actualMove = position
	move_and_slide(move)
	actualMove = position - actualMove
	GameWorld.travelledDistance += actualMove.length()


	if moveDirectionInput.length() > 0.0:
		touchTunnelTile()
	else:
		hasChangedVacuum = false
	
	
	
	if $CarryLoadSound.playing:
		$CarryLoadSound.volume_db = min( - 2, - 30 + carrySlowdown * 50)
	
	var speedBuff = Data.of("keeper.speedBuff")
	var drillBuff = Data.of("keeper.drillBuff")
	if speedBuff > 0 or drillBuff > 0:
		animationSuffix = "_buffed"
	else :
		animationSuffix = ""
	
	$Trail.emitting = moveDirectionInput.length() > 0 and spriteLockDuration <= 0.0
	$Trail.direction = - moveDirectionInput
	
	if spriteLockDuration > 0.0:
		spriteLockDuration -= delta
	else :
		var combinedMove = moveDirectionInput
		if actualMove.length() > 0.15:
			combinedMove += actualMove
		if inTunnel:
			$Sprite.play("dash" + animationSuffix)
			if $ThrusterLeft.emitting:
				disableEffects()
		elif tunnelLeaveAnimTimer > 0:
			tunnelLeaveAnimTimer -= delta
			$Sprite.play("exit-dash" + animationSuffix) # TODO handle suffix change?
		elif combinedMove.length() < 0.35:
			$Sprite.play("default" + animationSuffix)
			if not $ThrusterLeft.emitting:
				enableEffects()
		else :
			if not $ThrusterLeft.emitting:
				enableEffects()
			if abs(combinedMove.x) > abs(combinedMove.y) * 0.95:
				$Sprite.play("left" + animationSuffix if combinedMove.x < 0 else "right" + animationSuffix)
			else :
				$Sprite.play("up" + animationSuffix if combinedMove.y < 0 else "down" + animationSuffix)
		if moveDirectionInput.length() == 0:
			moveStartSoundPlayBuffer = 0
			if $MoveSound.shouldPlay:
				moveStopSoundPlayBuffer += delta
				if moveStopSoundPlayBuffer >= 0.2:
					$MoveSound.stop()
					$CarryLoadSound.stop()
					$MoveStopSound.play()
					$StillSound.play()
					moveStopSoundPlayBuffer = 0
		else :
			moveStopSoundPlayBuffer = 0
			if not $MoveSound.shouldPlay:
				moveStartSoundPlayBuffer += delta
				if moveStartSoundPlayBuffer >= 0.1:
					$MoveSound.play()
					$CarryLoadSound.play()
					$MoveStartSound.play()
					$StillSound.stop()
					moveStartSoundPlayBuffer = 0
			
	
	
	
	
	
	updateInteractables()

	updateTunnelerTargets(delta)

func updateCarry():
	var longest = 0
	for c in carriedCarryables.duplicate():
		if c.independent:
			dropCarry(c)
		else :
			var d = (position - c.position).length()
			if d > longest:
				longest = d
			if d > maxCarryLineLength:
				dropCarry(c)
				$CarryLineBreak.play()

	var breakThreshold = 0.7
	if longest > breakThreshold * maxCarryLineLength:
		if not $CarryLineStretch.playing:
			$CarryLineStretch.play()
		var pitch = (longest - breakThreshold * maxCarryLineLength) / ((1.0 - breakThreshold) * maxCarryLineLength)
		$CarryLineStretch.pitch_scale = 1 + ease(pitch, 0.6)
	else :
		$CarryLineStretch.stop()
	
	var strength: = 0.15
	var totalImpulse: = Vector2()
	for c in carriedCarryables:
		var dist = position - c.position
		
		if dist.length() < 12.0:
			dist *= 0.0
		else :
			dist -= dist.normalized() * 12
		if dist.y < 0:
			dist.y -= 2.0 * pow(1.0 + dist.length() / maxCarryLineLength, 4)
		
		var factor: = 1.0
		var off = dist.length() - 0.15 * maxCarryLineLength
		if off > 0:
			var fill = abs(off / (0.8 * maxCarryLineLength))
			if randf() < fill:
				factor = 10.0 * fill
		var impulse = (dist * strength * factor).clamped(100)
		totalImpulse += impulse
		c.apply_central_impulse(impulse)
		strength = max(strength * 0.9, 0.005)
	return totalImpulse

func attachCarry(body):
	if carriedCarryables.has(body):
		Logger.error("Tried to attach carryable " + body.name + "although it's already carried ")
		return 
	body.unfocusCarry(self)
	var po = CarryablePhysicsOverride.new()
	po.linear_damp = 2
	po.angular_damp = 2
	body.addPhysicsOverride(po)
	carriedCarryables.append(body)
	body.setCarriedBy(self)
	$Pickup.play()
	
	var carryLine = preload("res://mods-unpacked/Ategon-MolemanMod/keeper/Carryline.tscn").instance()
	carryLine.add_point(position)
	carryLine.add_point(body.position)
	get_parent().add_child(carryLine)
	carryLines[body] = carryLine
	Style.init(carryLine)
	
	if not $CarryLine.playing:
		$CarryLine.play()

func dropCarry(body):
	if not carriedCarryables.has(body):
		Logger.error("keeper wants to drop carryable that isn't carried", "Keeper.dropCarry", {"carryable":body.name, "carry":str(carriedCarryables)})
		return 
	carriedCarryables.erase(body)
	body.freeCarry(self)
	$Drop.play()
	
	
	var brk = Data.CARRYLINE_BREAK.instance()
	brk.global_position = global_position
	brk.target = body.global_position
	Level.stage.add_child(brk)
	
	
	carryLines[body].queue_free()
	carryLines.erase(body)

	if carryLines.size() == 0:
		$CarryLine.stop()

func updateCarryables():
	if not is_instance_valid(focussedCarryable):
		focussedCarryable = null
	
	if focussedCarryable:
		if not focussedCarryable.canFocusCarry() or not carryables.has(focussedCarryable) or carriedCarryables.has(focussedCarryable) or (focussedCarryable.is_in_group("usables") and not usables.has(focussedCarryable.get_meta("usable"))):
			focussedCarryable.unfocusCarry(self)
			focussedCarryable = null
	
	
	var potentialCarryables: = []
	for carryable in carryables:
		if not is_instance_valid(carryable):
			continue
		
		if not carriedCarryables.has(carryable) and carryable.canFocusCarry() and (pickupType == "" or pickupType == carryable.carryableType) and ( not carryable.is_in_group("usables") or usables.has(carryable.get_meta("usable"))):
				
				potentialCarryables.append(carryable)
	
	potentialCarryables.sort_custom(self, "sortByDistance")
	
	
	for carryable in potentialCarryables:
		if focussedCarryable == carryable:
			return 
		else :
			if focussedCarryable:
				focussedCarryable.unfocusCarry(self)
			focussedCarryable = carryable
			focussedCarryable.focusCarry(self)
		return 

func normalizeIntVector(vec: Vector2):
	vec = vec.normalized()

	# Clamp to int values
	if abs(vec.x) > abs(vec.y):
		vec.x = sign(vec.x)
		vec.y = 0
	else:
		vec.x = 0
		vec.y = sign(vec.y)

	return vec

func setTunnelTargetMarker(id: int, startPos: Vector2, dir: Vector2, distance: int):
	var targetPos = Level.map.getTilePos(Level.map.getTileCoord(startPos) + dir * int(distance + 1)) + Level.map.borderSpriteOffset

	for _i in range(0, (id+1) - tunnelMarkerInstances.size()):
		var tunnelMarker = TUNNEL_MARKER.instance()
		Level.map.addTileOverlay(tunnelMarker)

		tunnelMarkerInstances.append(tunnelMarker)
	
	if !tunnelMarkerInstances[id].visible:
		tunnelMarkerInstances[id].sprite.frame = 0

	tunnelMarkerInstances[id].show()
	tunnelMarkerInstances[id].position = targetPos
	

func updateTunnelerTargets(delta):

	if curTunnelerCooldown > 0:
		curTunnelerCooldown -= delta

	if isTunneling and is_instance_valid(lastTile):

		var lastTileCoord = Level.map.getTileCoord(lastTile.global_position) - lastTileDir

		var curTileCoord = Level.map.getTileCoord(self.global_position)

		# No longer in the same position to create the tunnel
		if (lastTileCoord - curTileCoord).length() > 0.1:
			lastTile = null
			isTunneling = false
			hasUpdatedTunnelMarkers = false

			return

		if curTunnelDistance < Data.of("keepermole.tunnelMinLength"):
			curTunnelDistance = Data.of("keepermole.tunnelMinLength")

		curTunnelDistance += Data.of("keepermole.tunnelLengthSpeed") * delta

		if curTunnelDistance > Data.of("keepermole.tunnelMaxLength"):
			curTunnelDistance = Data.of("keepermole.tunnelMaxLength")

		if tileTunnelers.has(lastTile.get_instance_id()):
			var tunneler = tileTunnelers.get(lastTile.get_instance_id())

			if not is_instance_valid(tunneler):
				tileTunnelers.erase(lastTile.get_instance_id())
				return

			if tunneler.numQueuedOrders() < self.getMaxQueuedTunnelers():

				var startPositions = []

				var tunnelerDir = lastTileDir

				if Data.ofOr("keepermole.queuedTunnelersSplit", false) and (tunneler.numQueuedOrders() % 2) == 0:
					tunnelerDir = normalizeIntVector(tunnelerDir.rotated(PI/2))

				if tunneler.numQueuedOrders() == 0:
					startPositions.append(tunneler.getTargetPos())
				else:
					for queueData in tunneler.getQueuedTargets():
						startPositions.append(Level.map.getTilePos(queueData["targetCoord"]) + Level.map.borderSpriteOffset)

						# The second recursion is limited to half the length of the first recursion
						curTunnelDistance = int((queueData["targetCoord"] - queueData["startCoord"]).length() / 2)

				var curTunnelMarkerID = 0

				for startPos in startPositions:

					if Data.ofOr("keepermole.queuedTunnelersSplit", false):
						setTunnelTargetMarker(curTunnelMarkerID, startPos, tunnelerDir, int(curTunnelDistance))
						setTunnelTargetMarker(curTunnelMarkerID+1, startPos, -tunnelerDir, int(curTunnelDistance))

						curTunnelMarkerID += 2
					else:
						setTunnelTargetMarker(curTunnelMarkerID, startPos, tunnelerDir, int(curTunnelDistance))

						curTunnelMarkerID += 1

		else:
			setTunnelTargetMarker(0, lastTile.global_position, lastTileDir, int(curTunnelDistance - 1))

		hasUpdatedTunnelMarkers = true

	else:
		curTunnelDistance = Data.of("keepermole.tunnelMinLength")

		for tunnelMarker in tunnelMarkerInstances:
			tunnelMarker.hide()

func pickupHit():
	if Data.of("keeper.insidestation") or disabled or inTunnel:
		return false
	
	if focussedCarryable:
		pickup(focussedCarryable)
		
func setTunnelMode(isInTunnel):
	inTunnel = isInTunnel

	if inTunnel:
		if carriedCarryables.size() > 0:
			pass
			#for _i in range(0, carriedCarryables.size()):
			#	dropCarry(carriedCarryables.front())
	else:
		tunnelLeaveAnimTimer = 0.155

func pickupHold():
	if Data.of("keeper.insidestation") or disabled or inTunnel:
		return false
	
	if focussedCarryable:
		pickup(focussedCarryable)
		pickupType = focussedCarryable.carryableType
		
	isTunneling = true

func allowTunneling(startCoord, targetCoord):
	var pathClear = true

	# Nip diagonal paths in the bud if they get past our defenses
	if abs(targetCoord.x - startCoord.x) > 0.01 and abs(targetCoord.y - startCoord.y) > 0.01:
		return false

	var dir = normalizeIntVector(targetCoord - startCoord)

	for i in range(0, int((targetCoord - startCoord).length())):

		var tileCoord = startCoord + dir * i

		# Why must we round this here?
		tileCoord.x = int(tileCoord.x)
		tileCoord.y = int(tileCoord.y)

		var tile = Level.map.getTile(tileCoord)

		# Do not allow tunneling through other tunnels
		if is_instance_valid(tile) and tile.has_meta("tunnel"):
			pathClear = false
			break

	return pathClear

func getMaxQueuedTunnelers():
	if Data.ofOr("keepermole.queuedTunnelers", false):
		if Data.ofOr("keepermole.queuedTunnelersRecursion", false):
			return 2
		else:
			return 1

	return 0

func pickupHoldStopped():
	pickupType = ""
	
	if isTunneling and is_instance_valid(lastTile) and hasUpdatedTunnelMarkers:
		curTunnelerCooldown = Data.of("keepermole.tunnelerCooldownTime")

		var lastTileCoord = Level.map.getTileCoord(lastTile.global_position) - lastTileDir

		var curTileCoord = Level.map.getTileCoord(self.global_position)

		# No longer in the same position to create the tunnel
		if (lastTileCoord - curTileCoord).length() > 0.1:
			lastTile = null
			isTunneling = false
			hasUpdatedTunnelMarkers = false

			return

		if tileTunnelers.has(lastTile.get_instance_id()):
			var tileTunneler = tileTunnelers.get(lastTile.get_instance_id())

			if is_instance_valid(tileTunneler):

				var startPositions = []

				var hasFailedOnce = false

				if tileTunneler.numQueuedOrders() == 0:
					startPositions.append(tileTunneler.getTargetPos())
				else:
					for queueData in tileTunneler.getQueuedTargets():
						startPositions.append(Level.map.getTilePos(queueData["targetCoord"]) + Level.map.borderSpriteOffset)

				var curTunnelMarkerID = 0
				var queuedTargets = {"cur": tileTunneler.getQueuedTargets(), "next": []}

				for startPos in startPositions:

					var list = queuedTargets["cur"] if tileTunneler.numQueuedOrders() == 0 else queuedTargets["next"]

					for _i in range(0, 2 if Data.ofOr("keepermole.queuedTunnelersSplit", false) else 1):

						var startCoord = Level.map.getTileCoord(startPos)
						var targetCoord = Level.map.getTileCoord(tunnelMarkerInstances[curTunnelMarkerID].global_position)

						curTunnelMarkerID += 1

						if allowTunneling(startCoord, targetCoord):
							list.append({
								"startCoord": startCoord,
								"targetCoord": targetCoord
							})
						else:
							hasFailedOnce = true

				tileTunneler.setQueuedTargets(queuedTargets)

				if hasFailedOnce:
					# Failed to create one tunnel
					Audio.sound("gui_quit_confirm")
		else:

			if allowTunneling(Level.map.getTileCoord(lastTile.global_position), Level.map.getTileCoord(tunnelMarkerInstances[0].global_position)):
				var tunneler = TUNNELER.instance()

				Data.changeByInt("keepermole.curWorkingTunnelers", 1)

				var tileStartCoord = Level.map.getTileCoord(lastTile.global_position) - lastTileDir

				var startPos = Level.map.getTilePos(tileStartCoord) + Level.map.borderSpriteOffset

				tunneler.position = startPos
				tunneler.keeperOwner = self

				tunneler.setTargetPos(tunnelMarkerInstances[0].global_position)

				Level.stage.add_child(tunneler)

				tileTunnelers[lastTile.get_instance_id()] = tunneler
			else:
				# Failed to create tunnel here
				Audio.sound("gui_quit_confirm")

	lastTile = null
	isTunneling = false
	hasUpdatedTunnelMarkers = false

func dropHit():

	if inTunnel:
		if Data.ofOr("keepermole.tunnelDetonation", false):
			var tunnelCoord = Level.map.getTileCoord(global_position)

			var tunnelTile = Level.map.getTile(tunnelCoord)

			# Shouldn't be possible
			if not is_instance_valid(tunnelTile) or not tunnelTile.has_meta("tunnel"):
				return false

			var tunnel = tunnelTile.get_meta("tunnel")

			tunnel.detonate()
		return

	if Data.of("keeper.insidestation") or disabled:
		return 
	
	var farthestDrop
	var distance: = 0.0
	for c in carriedCarryables:
		var dist = (c.global_position - global_position).length()
		if dist > distance:
			distance = dist
			farthestDrop = c
	if farthestDrop:
		dropCarry(farthestDrop)
		return true

func dropHold():

	if Data.of("keeper.insidestation") or disabled:
		return 

	if carriedCarryables.size() > 0:
		var drop = carriedCarryables.front()
		dropCarry(drop)

	isChangingVacuum = true

func dropHoldStopped():

	if Data.of("keeper.insidestation") or disabled:
		return

	isChangingVacuum = false

func pickup(drop):
	attachCarry(drop)

func currentSpeed()->float:
	var s = Data.of("keepermole.maxSpeed") + Data.of("keeper.additionalmaxspeed")
	s += Data.of("keeper.speedBuff")
	var yMove = move.normalized().y
	if yMove < 0:
		s += Data.of("keeper.additionalupwardsspeed") * abs(yMove)
	return s

func touchTunnelTile()->void:
	DrillHitTestRay.rotation = moveDirectionInput.angle()

	DrillHitTestRay.force_raycast_update()
	var tile = DrillHitTestRay.get_collider()

	if not (tile and tile.has_meta("destructable") and tile.get_meta("destructable")):
		return

	if tile.has_meta("tunnel"):
		var tunnel = tile.get_meta("tunnel")
		
		if tunnel.canEnterTunnel(self):

			if isChangingVacuum and Data.ofOr("keepermole.tunnelVacuum", false):
				if not hasChangedVacuum:
					hasChangedVacuum = true
					print(global_position)
					print(tile.global_position)
					tunnel.reverseVacuumDirection(true, global_position - tile.global_position)
			else:
				lastTile = null
				isTunneling = false
				hasUpdatedTunnelMarkers = false

				# Only allow tunnel entry if not carrying anything
				# if carriedCarryables.size() == 0: (disabled for new behaviour)
				tunnel.enterTunnel(self)

			return

		if not Data.ofOr("keepermole.queuedTunnelers", false) or not tileTunnelers.has(tile.get_instance_id()):
			return

		var tileTunneler = tileTunnelers.get(tile.get_instance_id())

		if not is_instance_valid(tileTunneler) or tileTunneler.numQueuedOrders() >= self.getMaxQueuedTunnelers():
			return

	# Wait for cooldown to finish
	if curTunnelerCooldown > 0:
		return

	# Wait for tunneler to finish
	if Data.ofOr("keepermole.curWorkingTunnelers", 0) >= Data.of("keepermole.maxTunnelers"):
		return

	lastTile = tile
	lastTileDir = normalizeIntVector(lastTile.global_position - global_position)


func setJetpackStage(stage:int):
	$Trail.amount = 20 + stage * 8
	$Trail.initial_velocity = 12 + stage * 1

onready  var thruster_l:ParticlesMaterial = $ThrusterLeft.process_material
onready  var thruster_r:ParticlesMaterial = $ThrusterRight.process_material
onready  var thruster_l_boost:AnimatedSprite = $ThrusterLeft / Booster
onready  var thruster_r_boost:AnimatedSprite = $ThrusterRight / Booster
const THRUSTER_IDLE_DIR_L:Vector3 = Vector3( - 0.5, 1, 0)
const THRUSTER_IDLE_DIR_R:Vector3 = Vector3(0.5, 1, 0)
const THRUSTER_IDLE_VEL:float = 40.0

func control_thruster_vfx(_dir:Vector2, _is_moving:bool, delta:float)->void :
	var target_angle_l:Vector3
	var target_angle_r:Vector3
	var target_vel:float
	var lerp_speed:float
	if not _is_moving:
		thruster_l_boost.animation = "idle"
		thruster_r_boost.animation = "idle"
		lerp_speed = 7.0
		target_vel = THRUSTER_IDLE_VEL
		target_angle_l = THRUSTER_IDLE_DIR_L
		target_angle_r = THRUSTER_IDLE_DIR_R
	else :
		thruster_l_boost.animation = "boosting"
		thruster_r_boost.animation = "boosting"
		lerp_speed = 12.0
		target_angle_l = - Vector3(_dir.x, _dir.y, 0).normalized()
		target_angle_r = target_angle_l
		target_vel = _dir.length() + THRUSTER_IDLE_VEL
	thruster_l.direction = lerp(thruster_l.direction, target_angle_l, lerp_speed * delta).normalized()
	thruster_r.direction = lerp(thruster_r.direction, target_angle_r, lerp_speed * delta).normalized()
	thruster_l.initial_velocity = lerp(thruster_l.initial_velocity, target_vel, lerp_speed * delta)
	thruster_r.initial_velocity = lerp(thruster_r.initial_velocity, target_vel, lerp_speed * delta)

func disableEffects():
	$ThrusterLeft.emitting = false
	$ThrusterRight.emitting = false
	$ThrusterLeft / Booster.visible = false
	$ThrusterRight / Booster.visible = false
	$StillSound.stop()

func enableEffects():
	$ThrusterLeft.emitting = true
	$ThrusterRight.emitting = true
	$ThrusterLeft / Booster.visible = true
	$ThrusterRight / Booster.visible = true
	$StillSound.play()


func getCarrySlowdown()->float:
	return carrySlowdown
