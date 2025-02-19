/spell/lightning
	name = "Lightning"
	abbreviation = "LS"
	desc = "Strike an enemy with a bolt of lightning."
	user_type = USER_TYPE_WIZARD
	specialization = SSOFFENSIVE
	charge_max = 100
	cooldown_min = 40
	cooldown_reduc = 30

	spell_levels = list(Sp_SPEED = 0, Sp_POWER = 0)
	level_max = list(Sp_TOTAL = 3, Sp_SPEED = 3, Sp_POWER = 3) //each level of power grants 1 additional target.

	spell_flags = NEEDSCLOTHES | WAIT_FOR_CLICK | IS_HARMFUL
	charge_type = Sp_RECHARGE
	invocation = "ZAP MUTHA FUH KA"
	invocation_type = SpI_SHOUT
	hud_state = "wiz_zap"
	valid_targets = list(/mob/living,/obj/machinery/bot,/obj/mecha)

	var/basedamage = 50
	var/bounces = 0
	var/bounce_range = 6
	var/image/chargeoverlay
	var/last_active_sound
	var/multicast = 1
	var/zapzap = 0
	var/lastbumped = null
	var/hit_valid_target = FALSE //If toggled off, prevents the lightning from jumping to other targets

/spell/lightning/New()
	..()
	chargeoverlay = image("icon" = 'icons/mob/mob.dmi', "icon_state" = "sithlord")

/spell/lightning/quicken_spell()
	if(!can_improve(Sp_SPEED))
		return 0

	spell_levels[Sp_SPEED]++

	if(delay_reduc && cast_delay)
		cast_delay = max(0, cast_delay - delay_reduc)
	else if(cast_delay)
		cast_delay = round( max(0, initial(cast_delay) * ((level_max[Sp_SPEED] - spell_levels[Sp_SPEED]) / level_max[Sp_SPEED] ) ) )

	if(charge_type == Sp_RECHARGE)
		if(cooldown_reduc)
			charge_max = max(cooldown_min, charge_max - cooldown_reduc)
		else
			charge_max = round( max(cooldown_min, initial(charge_max) * ((level_max[Sp_SPEED] - spell_levels[Sp_SPEED]) / level_max[Sp_SPEED] ) ) ) //the fraction of the way you are to max speed levels is the fraction you lose
	if(charge_max < charge_counter)
		charge_counter = charge_max

	var/temp = "You have improved [name]"
	if(spell_levels[Sp_SPEED] >= level_max[Sp_SPEED])
		multicast = 2
		temp += " and gain the ability to multicast, each incantation allows you to fire off two bolts of lightning before having to re-cast."
	else
		temp += " and can cast it more frequently."

	return temp

/spell/lightning/empower_spell()
	if(!can_improve(Sp_POWER))
		return 0
	spell_levels[Sp_POWER]++
	var/temp = ""
	switch(level_max[Sp_POWER] - spell_levels[Sp_POWER])
		if(2)
			temp = "You have improved [name] into Chain Lightning it will arc to one additional target."
			name = "Chain Lightning"
			bounces++
		if(1)
			temp = "You have improved [name] into Powerful Chain Lightning it will arc to up to 3 targets."
			name = "Powerful Chain Lightning"
			bounces+=2
		if(0)
			temp = "You have improved [name] into Zeus' Own Chain Lightning it will arc to up to 5 targets."
			name = "Zeus' Own Chain Lightning"
			bounces+=2
	basedamage += 5
	connected_button.name = name
	return temp

/spell/lightning/channel_spell(mob/user = usr, skipcharge = 0, force_remove = 0)
	if(!..()) //We only make it to this point if we succeeded in channeling or are removing channeling
		return 0
	if(user.spell_channeling && !force_remove)
		user.overlays += chargeoverlay
		if(world.time >= last_active_sound + 50)
			playsound(user, 'sound/effects/lightning/chainlightning_activate.ogg', 100, 1, "vary" = 0)
			last_active_sound = world.time
		zapzap = multicast
		//give user overlay
	else
		//remove overlay
		connected_button.name = name
		charge_counter = charge_max
		user.overlays -= chargeoverlay
		if((zapzap != multicast) && (zapzap > 0)) //partial cast
			take_charge(holder, 0)
		zapzap = 0
	return 1

/spell/lightning/before_cast(list/targets, user, bypass_range)
	if(targets[1] == user) //No self-hitting
		return FALSE
	return ..()

/spell/lightning/cast(var/list/targets, mob/user)
	var/atom/A = targets[1]
	if(istype(A))
		if (user.is_pacified(VIOLENCE_DEFAULT,A))
			return
		zapzap--
		if(zapzap > 0)
			to_chat(user, "<span class='info'>You can throw lightning [zapzap] more time\s</span>")
			. = 1

		spawn()
			zapmuthafucka(user,A, bounces)
		score.lightningwiz++

/spell/lightning/proc/zapmuthafucka(var/mob/user, var/atom/target, var/chained = bounces, var/list/zapped = list(), var/oursound = null)
	var/otarget = target
	hit_valid_target = FALSE
	src.lastbumped = null
	zapped |= target
	var/turf/T = get_turf(user)
	var/turf/U = get_turf(target)
	var/obj/item/projectile/beam/lightning/spell/L = new /obj/item/projectile/beam/lightning/spell(T)

	if(!oursound)
		oursound = pick(lightning_sound)
	L.our_spell = src
	playsound(user, oursound, 100, 1, "vary" = 0)
	L.tang = adjustAngle(get_angle(U,T))
	L.icon = midicon
	L.icon_state = "[L.tang]"
	L.firer = user
	L.def_zone = LIMB_CHEST
	L.original = target
	L.current = U
	L.starting = U
	L.yo = U.y - T.y
	L.xo = U.x - T.x
	L.process()
	while(!src.lastbumped)
		sleep(world.tick_lag)
	target = lastbumped
	if(target) //hit something
//		to_chat(world, "we hit a [formatJumpTo(target)] (<a href='?_src_=vars;Vars=\ref[target]'>VV</a>) instead of a mob")
		U = get_turf(target)
		var/list/zappanic = list()
		for(var/potential in get_turf(target)) //find a mob in the tile
			if(is_type_in_list(potential, valid_targets))
				if((potential == user) || (potential == holder) || (potential in zapped))
					continue
//			to_chat(world, "adding [Living](<a href='?_src_=vars;Vars=\ref[Living]'>VV</a>) to the potentials list")
				zappanic |= potential
		if(zappanic.len)
			target = pick(zappanic)
//			to_chat(world, "picked [formatJumpTo(target)](<a href='?_src_=vars;Vars=\ref[target]'>VV</a>)")
		else
//			to_chat(world, "no potentials")
			if(isturf(target))
				target = get_step_towards(target, get_dir(target, user))
//				to_chat(world, "new target is [formatJumpTo(target)](<a href='?_src_=vars;Vars=\ref[target]'>VV</a>)")
	if(is_type_in_list(target, valid_targets))
		hit_valid_target = TRUE
	if(!(target == holder)) //Not the wizard who cast the spell
		spawn() //Blowing up something that might explode afterwards could cause chain lightning to not work properly
			target.emp_act(1)
			if(isliving(target))
				var/mob/living/living_target = target
				living_target.apply_damage((issilicon(target) ? basedamage*0.66 : basedamage), BURN, LIMB_CHEST, "blocked" = 0)
			else
				var/obj/item/projectile/beam/lightning/spell/B = new /obj/item/projectile/beam/lightning/spell
				B.our_spell = src
				B.damage = basedamage
				target.bullet_act(B)
				qdel(B)
			target.emp_act(1)
	if(chained && hit_valid_target) //If it didn't hit a correct target then the lightning just gets grounded
		//DO IT AGAIN
		var/atom/next_target
		var/currdist = -1 //Keeps track of which target is the closest for the purpose of which one to arc to
		for(var/potential in view(target,bounce_range))
//			to_chat(world, "checking [formatJumpTo(M)] (<a href='?_src_=vars;Vars=\ref[M]'>VV</a>) for a bounce")
			if(is_type_in_list(potential, valid_targets))
				if((potential != holder) && (potential != user)) //Don't consider the spell owner nor the target being arced from
					if((potential in zapped) || (potential == otarget)) //Target was already zapped, or is the one the spell has currently affected
						continue
					var/dist = get_dist(potential, user)
					if(currdist == -1)
//						to_chat(world, "distance to [formatJumpTo(M)] (<a href='?_src_=vars;Vars=\ref[M]'>VV</a>) is the shortest so far([dist])")
						currdist = dist
						next_target = potential
					else if(dist < currdist)
//						to_chat(world, "distance to [formatJumpTo(M)] (<a href='?_src_=vars;Vars=\ref[M]'>VV</a>) is the shortest so far([dist])")
						next_target = potential
						currdist = dist
					else
//						to_chat(world, "too far away from [formatJumpTo(M)] (<a href='?_src_=vars;Vars=\ref[M]'>VV</a>) ")

		if(!next_target)
//			to_chat(world, "didn't have a next target")
			return //bail out bail out!
//		to_chat(world, "going one more time 'user' = [formatJumpTo(target)] (<a href='?_src_=vars;Vars=\ref[target]'>VV</a>) ; 'target' = [formatJumpTo(next_target)](<a href='?_src_=vars;Vars=\ref[next_target]'>VV</a>)")
		zapmuthafucka("user" = target, "target" = next_target, "chained" = chained-1, "zapped" = zapped, "oursound" = oursound)

/spell/lightning/get_upgrade_info(upgrade_type, level)
	switch(upgrade_type)
		if(Sp_POWER)
			switch(level)
				if(1)
					return "Allow the spell to arc to one additional target and slightly increases its damage."
				if(2)
					return "Allow the spell to arc up to 3 targets and slightly increases its damage."
				if(3)
					return "Allow the spell to arc up to 5 targets and slightly increases its damage."
		if(Sp_SPEED)
			if(spell_levels[Sp_SPEED] == 2)
				return "Allows you to multi-cast the spell, being able to fire up to two bolts of lightning before having to re-cast."
	return ..()

/spell/lightning/sith
	basedamage = 25
	invocation = "UNLIMITED POWER!"
	user_type = USER_TYPE_OTHER
