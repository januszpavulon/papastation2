/spell/targeted/bound_object
	name = "Bound Object"
	desc = "This spell allows a wizard to bind an object to themselves, then teleport it to them at will. Middle click the spell icon or use the 'Unbind' spell to select a new object."
	user_type = USER_TYPE_WIZARD
	specialization = SSUTILITY
	abbreviation = "BO"

	school = "abjuration"
	charge_max = 100
	minimum_charge = 10 //1 second delay
	spell_flags = SELECTABLE | WAIT_FOR_CLICK
	hud_state = "wiz_bound"
	level_max = list(Sp_TOTAL = 4, Sp_SPEED = 2, Sp_POWER = 2)
	price = 0.5 * Sp_BASE_PRICE

	var/has_object = 0
	var/obj/bound
	var/icon/bound_icon

	var/allow_anchored = 0

	var/static/list/prohibited = list( //Items that are prohibited because, frankly, it would cause more unfun for everyone else than fun for the user if they could be retrieved.
		/obj/machinery/power/apc,								//APCs
		/obj/machinery/atmospherics,							//pipes, vents, pumps, the cryo tubes, the gas miners, etc.
		/obj/machinery/alarm,									//air alarms
		/obj/machinery/firealarm,								//fire alarms
		/obj/machinery/status_display,							//status displays
		/obj/machinery/newscaster,								//newscasters
		/obj/item/device/radio/intercom,						//intercoms
		/obj/structure/extinguisher_cabinet,					//fire extinguisher cabinets
		/obj/machinery/computer/security/telescreen,			//TV screens
		/obj/machinery/camera,									//AI cameras
		/obj/machinery/requests_console,						//requests consoles
		/obj/machinery/door_control,							//door control buttons
		/obj/structure/fireaxecabinet,					//fire axe cabinets
		/obj/machinery/light_switch,							//light switches                  //list taken from subspacetunneler.dm
		/obj/structure/sign,									//area signs
		/obj/structure/closet/walllocker,						//defib lockers, wall-mounted O2 lockers, etc.
		/obj/machinery/recharger/defibcharger/wallcharger,		//wall-mounted defib chargers
		/obj/structure/noticeboard,								//notice boards
		/obj/machinery/space_heater/campfire/stove/fireplace,	//fireplaces
		/obj/structure/painting,								//paintings
		/obj/item/weapon/storage/secure/safe,					//wall-mounted safes
		/obj/machinery/door_timer,								//brig cell timers
		/obj/structure/closet/secure_closet/brig,				//brig cell closets
		/obj/machinery/disposal,								//disposal bins
		/obj/machinery/light,									//light bulbs and tubes
		/obj/machinery/media/receiver/boombox/wallmount,		//sound systems
		/obj/machinery/keycard_auth,							//keycard authentication devices
		/obj/landline,											//telephone landlines
		/obj/effect/phone_cord,									//the telephone cord effect
		/obj/item/telephone,									//telephones
		)
	//Generally extremely dangerous things that could spell doom and devastation for anyone nearby, possibly the wizard too
	var/list/empower_limited = list(
		/obj/machinery/singularity,
		/obj/machinery/power/supermatter,
	)

/spell/targeted/bound_object/get_upgrade_price(upgrade_type)
	switch(upgrade_type)
		if(Sp_SPEED)
			return 5
		if(Sp_POWER)
			return 20

/spell/targeted/bound_object/is_valid_target(obj/target, mob/user, options, bypass_range = 0)
	if(!istype(target))
		return 0
	var/datum/zLevel/L = get_z_level(target)
	if(L.teleJammed && get_dist(target,holder) >= range && !bypass_range)
		return 0
	if(target.anchored && !allow_anchored)
		return 0
	for(var/J in prohibited)
		if(istype(target, J))
			return 0
	return target

/spell/targeted/bound_object/before_channel(mob/user)
	if(has_object)
		if(cast_check(0, user))
			if(!bound || bound.loc == null) //if it's deleted or something
				to_chat(user, "<span class='danger'>The link to your bound object has been severed!</span>")
				clear_bound()
				return 1
			if(bound.anchored && !allow_anchored)
				to_chat(user, "<span class='danger'>You can't seem to summon your bound object!</span>")
				clear_bound()
				return 1
			var/turf/oldloc = get_turf(bound)
			if(istype(bound, /obj/item))
				var/obj/item/I = bound
				if(istype(I.loc, /mob))
					var/mob/M = bound.loc
					if(M == user) //you already have it you dumb
						return 1
					M.drop_item(I, force_drop = 1)
					M.update_icons()
				bound.forceMove(get_turf(user))
				user.put_in_hands(I)
			else
				bound.forceMove(get_turf(user))
			spark(oldloc, 3, FALSE)
			take_charge(user)
		return 1
	return 0

/spell/targeted/bound_object/cast(list/targets, mob/user = user)
	for(var/obj/target in targets)
		if(!has_object)
			if(spell_levels[Sp_POWER] < 2) //Moving this check here because if it returned 0 on is_valid_target it would force the character to touch it if in range. Ouch.
				for(var/E in empower_limited)
					if(istype(target, E))
						to_chat(user, "<span class='warning'>This is too powerful to bind to yourself. Empower your spell sufficiently enough first!</span>")
						return 0
			has_object = 1
			bound = target
			draw_bound_object(bound)
			to_chat(user, "You bind \the [target] to yourself.")
			channel_spell(force_remove = 1)
	return 1

//Creates the item's sprite for the spell sprite
/spell/targeted/bound_object/proc/draw_bound_object(var/obj/target)
	if(!connected_button || !target)
		return
	connected_button.overlays -= bound_icon
	bound_icon = null
	bound_icon = image(target.icon, target.icon_state, layer = HUD_ITEM_LAYER)
	connected_button.overlays += bound_icon

/spell/targeted/bound_object/empower_spell()
	var/upgrade_desc
	if(spell_levels[Sp_POWER] == 0)
		spell_levels[Sp_POWER]++
		allow_anchored = 1
		upgrade_desc = "You have reduced the restrictions on your binding."
	else
		spell_levels[Sp_POWER]++
		upgrade_desc = "You can now bind far more destructive objects to yourself."
	return upgrade_desc

/spell/targeted/bound_object/get_upgrade_info(upgrade_type, level)
	if(upgrade_type == Sp_POWER)
		if(spell_levels[Sp_POWER] == 0)
			return "Increases your binding skill, allowing otherwise immobile structures and machines to be moved."
		if(spell_levels[Sp_POWER] == 1)
			return "Further increases your binding skill, allowing you to bind [types_to_english_list(empower_limited)]."
		else
			return "You can already bind a great amount of things."
	return ..()

/spell/targeted/bound_object/on_right_click(mob/user)
	if(has_object)
		if(!bound)
			to_chat(user, "You feel unbound.")
		else
			to_chat(user, "You unbind \the [bound] from yourself.")
		clear_bound()
	return 1

/spell/targeted/bound_object/proc/clear_bound()
	has_object = 0
	bound = null
	if(connected_button)
		connected_button.overlays -= bound_icon
	bound_icon = null

/spell/targeted/bound_object/on_added(mob/user)
	if(alert(user, "You can unbind the chosen object by middle-clicking the spell icon. You can also have a dedicated spell for unbinding. Do you want this?",,"Yes","No") == "Yes")
		var/spell/unbind/unbind = new /spell/unbind
		if(user.mind)
			if(!user.mind.wizard_spells)
				user.mind.wizard_spells = list()
			user.mind.wizard_spells += unbind
		user.add_spell(unbind)

/spell/targeted/bound_object/on_removed(mob/user)
	clear_bound()
	for(var/spell/unbind/spell in user.spell_list)
		user.remove_spell(spell)

//The connected button is regenerated, have it re-draw the image
/spell/targeted/bound_object/on_transfer(mob/user)
	draw_bound_object(bound)

/spell/unbind
	name = "Unbind"
	desc = "Dispells any objects bound to you, allowing a new object to be bound."

	school = "abjuration"
	charge_max = 10
	spell_flags = 0
	hud_state = "wiz_unbind"
	level_max = list(Sp_TOTAL = 0)

	var/spell/targeted/bound_object/linked_spell

/spell/unbind/choose_targets(mob/user = usr)
	return list(user)

/spell/unbind/cast(list/targets, mob/user)
	if(linked_spell.has_object)
		if(!linked_spell.bound)
			to_chat(user, "You feel unbound.")
		else
			to_chat(user, "You unbind \the [linked_spell.bound] from yourself.")
		linked_spell.clear_bound()

/spell/unbind/on_added(mob/user)
	var/spell = /spell/targeted/bound_object
	if(!(locate(spell) in user.spell_list))
		user.remove_spell(src)
		return
	for(var/spell/targeted/bound_object/bound_object in user.spell_list)
		linked_spell = bound_object
