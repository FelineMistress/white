/obj/machinery/power/emitter
	name = "излучатель"
	desc = "Мощный промышленный лазер, часто используемый в области силовых полей и производства электроэнергии."
	icon = 'icons/obj/singularity.dmi'
	icon_state = "emitter"
	base_icon_state = "emitter"

	anchored = FALSE
	density = TRUE
	req_access = list(ACCESS_ENGINE_EQUIP)
	circuit = /obj/item/circuitboard/machine/emitter

	use_power = NO_POWER_USE

	/// The icon state used by the emitter when it's on.
	var/icon_state_on = "emitter_+a"
	/// The icon state used by the emitter when it's on and low on power.
	var/icon_state_underpowered = "emitter_+u"
	///Is the machine active?
	var/active = FALSE
	///Does the machine have power?
	var/powered = FALSE
	///Seconds before the next shot
	var/fire_delay = 10 SECONDS
	///Max delay before firing
	var/maximum_fire_delay = 10 SECONDS
	///Min delay before firing
	var/minimum_fire_delay = 2 SECONDS
	///When was the last shot
	var/last_shot = 0
	///Number of shots made (gets reset every few shots)
	var/shot_number = 0
	///if it's welded down to the ground or not. the emitter will not fire while unwelded. if set to true, the emitter will start anchored as well.
	var/welded = FALSE
	///Is the emitter id locked?
	var/locked = FALSE
	///Used to stop interactions with the object (mainly in the wabbajack statue)
	var/allow_switch_interact = TRUE
	///What projectile type are we shooting?
	var/projectile_type = /obj/projectile/beam/emitter/hitscan
	///What's the projectile sound?
	var/projectile_sound = 'sound/weapons/emitter.ogg'
	///Sparks emitted with every shot
	var/datum/effect_system/spark_spread/sparks
	///Stores the type of gun we are using inside the emitter
	var/obj/item/gun/energy/gun
	///List of all the properties of the inserted gun
	var/list/gun_properties
	//only used to always have the gun properties on non-letal (no other instances found)
	var/mode = FALSE
	// The following 3 vars are mostly for the prototype
	///manual shooting? (basically you hop onto the emitter and choose the shooting direction, is very janky since you can only shoot at the 8 directions and i don't think is ever used since you can't build those)
	var/manual = FALSE
	///Amount of power inside
	var/charge = 0
	///stores the direction and orientation of the last projectile
	var/last_projectile_params

/obj/machinery/power/emitter/Initialize(mapload)
	. = ..()
	RefreshParts()
	wires = new /datum/wires/emitter(src)
	if(welded)
		if(!anchored)
			set_anchored(TRUE)
		connect_to_network()

	sparks = new
	sparks.attach(src)
	sparks.set_up(5, TRUE, src)
	AddComponent(/datum/component/simple_rotation, ROTATION_ALTCLICK | ROTATION_CLOCKWISE | ROTATION_COUNTERCLOCKWISE | ROTATION_VERBS, null, CALLBACK(src, PROC_REF(can_be_rotated)))
	AddElement(/datum/element/empprotection, EMP_PROTECT_SELF | EMP_PROTECT_WIRES)

/obj/machinery/power/emitter/welded/Initialize(mapload)
	welded = TRUE
	. = ..()

/obj/machinery/power/emitter/set_anchored(anchorvalue)
	. = ..()
	if(!anchored && welded) //make sure they're keep in sync in case it was forcibly unanchored by badmins or by a megafauna.
		welded = FALSE

/obj/machinery/power/emitter/RefreshParts()
	. = ..()
	var/max_fire_delay = 12 SECONDS
	var/fire_shoot_delay = 12 SECONDS
	var/min_fire_delay = 2.4 SECONDS
	var/power_usage = 350
	for(var/obj/item/stock_parts/micro_laser/laser in component_parts)
		max_fire_delay -= 2 SECONDS * laser.rating
		min_fire_delay -= 0.4 SECONDS * laser.rating
		fire_shoot_delay -= 2 SECONDS * laser.rating
	maximum_fire_delay = max_fire_delay
	minimum_fire_delay = min_fire_delay
	fire_delay = fire_shoot_delay
	for(var/obj/item/stock_parts/manipulator/manipulator in component_parts)
		power_usage -= 50 * manipulator.rating
	update_mode_power_usage(ACTIVE_POWER_USE, power_usage)

/obj/machinery/power/emitter/examine(mob/user)
	. = ..()
	. += "<hr>"
	if(welded)
		. += span_info("Он прочно пришвартован к полу. Можно <b>отварить</b> его от пола.")
	else if(anchored)
		. += span_info("В настоящее время он прикреплен к полу. Можно <b>приварить</b> его к полу или же <b>открутить</b> от пола.")
	else
		. += span_info("Он не прикручен к полу. Можно закрепить его на месте с помощью <b>ключа</b>.")

	if(in_range(user, src) || isobserver(user))
		if(!active)
			. += span_notice("\nЕго индикатор состояния в настоящее время выключен.")
		else if(!powered)
			. += span_notice("\nЕго индикатор состояния слабо светится.")
		else
			. += span_notice("\nЕго индикатор состояния показывает: излучение каждые <b>[DisplayTimeText(fire_delay)]</b>.")
			. += span_notice("\nПотребление энергии: <b>[display_power(active_power_usage)]</b>.")

/obj/machinery/power/emitter/should_have_node()
	return welded

/obj/machinery/power/emitter/Destroy()
	if(SSticker.IsRoundInProgress())
		var/turf/T = get_turf(src)
		message_admins("[src] deleted at [ADMIN_VERBOSEJMP(T)].")
		log_game("[src] deleted at [AREACOORD(T)].")
		investigate_log("deleted at [AREACOORD(T)].", INVESTIGATE_SINGULO)
	QDEL_NULL(sparks)
	return ..()

/obj/machinery/power/emitter/update_icon_state()
	if(!active || !powernet)
		icon_state = base_icon_state
		return ..()
	icon_state = avail(active_power_usage) ? icon_state_on : icon_state_underpowered
	return ..()

/obj/machinery/power/emitter/proc/can_be_rotated(mob/user,rotation_type)
	if (anchored)
		to_chat(user, span_warning("Он прикручен к полу!"))
		return FALSE
	return TRUE

/obj/machinery/power/emitter/update_icon_state()
	. = ..()
	if(active && powernet)
		icon_state = avail(active_power_usage) ? icon_state_on : icon_state_underpowered
	else
		icon_state = initial(icon_state)

/obj/machinery/power/emitter/interact(mob/user)
	add_fingerprint(user)
	if(!welded)
		to_chat(user, span_warning("<b>[capitalize(src)]</b> должен быть надёжно закреплён!"))
		return FALSE
	if(!powernet)
		to_chat(user, span_warning("<b>[capitalize(src)]</b> не подключен к проводу!"))
		return FALSE
	if(locked || !allow_switch_interact)
		to_chat(user, span_warning("The controls are locked!"))
		return FALSE

	if(active)
		active = FALSE
	else
		active = TRUE
		shot_number = 0
		fire_delay = maximum_fire_delay

	to_chat(user, span_notice("[active ? "Включаю" : "Выключаю"] <b>[src]</b>."))
	message_admins("[src] turned [active ? "ON" : "OFF"] by [ADMIN_LOOKUPFLW(user)] in [ADMIN_VERBOSEJMP(src)]")
	log_game("[src] turned [active ? "ON" : "OFF"] by [key_name(user)] in [AREACOORD(src)]")
	investigate_log("turned [active ? "ON" : "OFF"] by [key_name(user)] at [AREACOORD(src)]", INVESTIGATE_SINGULO)
	update_appearance()

/obj/machinery/power/emitter/attack_animal(mob/living/simple_animal/user, list/modifiers)
	if(ismegafauna(user) && anchored)
		set_anchored(FALSE)
		user.visible_message(span_warning("<b>[user]</b> отрывает <b>[src.name]</b> от пола!"))
	else
		. = ..()
	if(. && !anchored)
		step(src, get_dir(user, src))

/obj/machinery/power/emitter/attack_ai_secondary(mob/user, list/modifiers)
	togglelock(user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/machinery/power/emitter/process(delta_time)
	if(machine_stat & (BROKEN))
		return
	if(!welded || (!powernet && active_power_usage))
		active = FALSE
		update_appearance()
		return
	if(!active)
		return
	if(active_power_usage && surplus() < active_power_usage)
		if(powered)
			powered = FALSE
			update_appearance()
			investigate_log("lost power and turned OFF at [AREACOORD(src)]", INVESTIGATE_SINGULO)
			log_game("[src] lost power in [AREACOORD(src)]")
		return

	add_load(active_power_usage)
	if(!powered)
		powered = TRUE
		update_appearance()
		investigate_log("regained power and turned ON at [AREACOORD(src)]", INVESTIGATE_SINGULO)
	if(charge <= 80)
		charge += 2.5 * delta_time
	if(!check_delay() || manual == TRUE)
		return FALSE
	fire_beam()

/obj/machinery/power/emitter/proc/check_delay()
	if((last_shot + fire_delay) <= world.time)
		return TRUE
	return FALSE

/obj/machinery/power/emitter/proc/fire_beam_pulse()
	if(!check_delay())
		return FALSE
	if(!welded)
		return FALSE
	if(surplus() >= active_power_usage)
		add_load(active_power_usage)
		fire_beam()

/obj/machinery/power/emitter/proc/fire_beam(mob/user)
	var/obj/projectile/projectile = new projectile_type(get_turf(src))
	playsound(src, projectile_sound, 50, TRUE)
	if(prob(35))
		sparks.start()
	projectile.firer = user ? user : src
	projectile.fired_from = src
	if(last_projectile_params)
		projectile.p_x = last_projectile_params[2]
		projectile.p_y = last_projectile_params[3]
		projectile.fire(last_projectile_params[1])
	else
		projectile.fire(dir2angle(dir))
	if(!manual)
		last_shot = world.time
		if(shot_number < 3)
			fire_delay = 20
			shot_number ++
		else
			fire_delay = rand(minimum_fire_delay,maximum_fire_delay)
			shot_number = 0
	return projectile

/obj/machinery/power/emitter/can_be_unfasten_wrench(mob/user, silent)
	if(active)
		if(!silent)
			to_chat(user, span_warning("Надо бы выключить <b>[src]</b> сначала!"))
		return FAILED_UNFASTEN

	else if(welded)
		if(!silent)
			to_chat(user, span_warning("<b>[capitalize(src)]</b> приварен к полу!"))
		return FAILED_UNFASTEN

	return ..()

/obj/machinery/power/emitter/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	default_unfasten_wrench(user, tool)
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/machinery/power/emitter/welder_act(mob/living/user, obj/item/item)
	..()
	if(active)
		to_chat(user, span_warning("Надо бы выключить <b>[src]</b> сначала!"))
		return TRUE

	if(welded)
		if(!item.tool_start_check(user, amount=0))
			return TRUE
		user.visible_message(span_notice("<b>[user.name]</b> начинает отваривать <b>[name]</b> от пола."), \
			span_notice("Начинаю отваривать <b>[src]</b> от пола..."), \
			span_hear("Слышу сварку."))
		if(!item.use_tool(src, user, 20, 1, 50))
			return FALSE
		welded = FALSE
		to_chat(user, span_notice("Отвариваю <b>[src]</b> от пола."))
		disconnect_from_network()
		update_cable_icons_on_turf(get_turf(src))
		return TRUE

	if(!anchored)
		to_chat(user, span_warning("<b>[capitalize(src)]</b> должен быть прикручен к полу!"))
		return TRUE
	if(!item.tool_start_check(user, amount=0))
		return TRUE
	user.visible_message(span_notice("<b>[user.name]</b> начинает приваривать <b>[name]</b> к полу."), \
		span_notice("Начинаю приваривать <b>[src]</b> к полу..."), \
		span_hear("Слышу сварку."))
	if(!item.use_tool(src, user, 20, 1, 50))
		return FALSE
	welded = TRUE
	to_chat(user, span_notice("Привариваю <b>[src]</b> к полу."))
	connect_to_network()
	update_cable_icons_on_turf(get_turf(src))
	return TRUE

/obj/machinery/power/emitter/crowbar_act(mob/living/user, obj/item/item)
	if(panel_open && gun)
		return remove_gun(user)
	default_deconstruction_crowbar(item)
	return TRUE

/obj/machinery/power/emitter/screwdriver_act(mob/living/user, obj/item/item)
	if(..())
		return TRUE
	default_deconstruction_screwdriver(user, "emitter_open", "emitter", item)
	return TRUE

/// Attempt to toggle the controls lock of the emitter
/obj/machinery/power/emitter/proc/togglelock(mob/user)
	if(obj_flags & EMAGGED)
		to_chat(user, span_warning("Блокировка не работает!"))
		return
	if(!allowed(user))
		to_chat(user, span_danger("Доступ запрещён."))
		return
	if(!active)
		to_chat(user, span_warning("Управление может быть заблокировано только когда [src] работает!"))
		return
	locked = !locked
	to_chat(user, span_notice("[src.locked ? "Блокирую" : "Разблокирую"] управление."))

/obj/machinery/power/emitter/attackby(obj/item/item, mob/user, params)
	if(item.GetID())
		togglelock(user)
		return

	if(is_wire_tool(item) && panel_open)
		wires.interact(user)
		return
	if(panel_open && !gun && istype(item,/obj/item/gun/energy))
		if(integrate(item,user))
			return
	return ..()

/obj/machinery/power/emitter/AltClick(mob/user)
	return ..() // This hotkey is BLACKLISTED since it's used by /datum/component/simple_rotation

/obj/machinery/power/emitter/proc/integrate(obj/item/gun/energy/energy_gun, mob/user)
	if(!istype(energy_gun, /obj/item/gun/energy))
		return
	if(!user.transferItemToLoc(energy_gun, src))
		return
	gun = energy_gun
	gun_properties = gun.get_turret_properties()
	set_projectile()
	return TRUE

/obj/machinery/power/emitter/proc/remove_gun(mob/user)
	if(!gun)
		return
	user.put_in_hands(gun)
	gun = null
	playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	gun_properties = list()
	set_projectile()
	return TRUE

/obj/machinery/power/emitter/proc/set_projectile()
	if(LAZYLEN(gun_properties))
		if(mode || !gun_properties["lethal_projectile"])
			projectile_type = gun_properties["stun_projectile"]
			projectile_sound = gun_properties["stun_projectile_sound"]
		else
			projectile_type = gun_properties["lethal_projectile"]
			projectile_sound = gun_properties["lethal_projectile_sound"]
		return
	projectile_type = initial(projectile_type)
	projectile_sound = initial(projectile_sound)

/obj/machinery/power/emitter/emag_act(mob/user)
	if(obj_flags & EMAGGED)
		return
	locked = FALSE
	obj_flags |= EMAGGED
	if(user)
		user.visible_message(span_warning("<b>[user.name]</b> взламывает <b>[src]</b>."), span_notice("Взламываю управление."))


/obj/machinery/power/emitter/prototype
	name = "прототип излучателя"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "proto_emitter"
	base_icon_state = "proto_emitter"
	icon_state_on = "proto_emitter_+a"
	icon_state_underpowered = "proto_emitter_+u"
	base_icon_state = "proto_emitter"
	can_buckle = TRUE
	buckle_lying = 0
	///Sets the view size for the user
	var/view_range = 4.5
	///Grants the buckled mob the action button
	var/datum/action/innate/proto_emitter/firing/auto

//BUCKLE HOOKS

/obj/machinery/power/emitter/prototype/unbuckle_mob(mob/living/buckled_mob, force = FALSE, can_fall = TRUE)
	playsound(src,'sound/mecha/mechmove01.ogg', 50, TRUE)
	manual = FALSE
	for(var/obj/item/item in buckled_mob.held_items)
		if(istype(item, /obj/item/turret_control))
			qdel(item)
	if(istype(buckled_mob))
		buckled_mob.pixel_x = buckled_mob.base_pixel_x
		buckled_mob.pixel_y = buckled_mob.base_pixel_y
		if(buckled_mob.client)
			buckled_mob.client.view_size.resetToDefault()
	auto.Remove(buckled_mob)
	. = ..()

/obj/machinery/power/emitter/prototype/user_buckle_mob(mob/living/buckled_mob, mob/user, check_loc = TRUE)
	if(user.incapacitated() || !istype(user))
		return
	for(var/atom/movable/atom in get_turf(src))
		if(atom.density && (atom != src && atom != buckled_mob))
			return
	buckled_mob.forceMove(get_turf(src))
	..()
	playsound(src,'sound/mecha/mechmove01.ogg', 50, TRUE)
	buckled_mob.pixel_y = 14
	layer = 4.1
	if(buckled_mob.client)
		buckled_mob.client.view_size.setTo(view_range)
	if(!auto)
		auto = new()
	auto.Grant(buckled_mob, src)

/datum/action/innate/proto_emitter
	check_flags = AB_CHECK_HANDS_BLOCKED | AB_CHECK_IMMOBILE | AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED
	///Stores the emitter the user is currently buckled on
	var/obj/machinery/power/emitter/prototype/proto_emitter
	///Stores the mob instance that is buckled to the emitter
	var/mob/living/carbon/buckled_mob

/datum/action/innate/proto_emitter/Destroy()
	proto_emitter = null
	buckled_mob = null
	return ..()

/datum/action/innate/proto_emitter/Grant(mob/living/carbon/user, obj/machinery/power/emitter/prototype/proto)
	proto_emitter = proto
	buckled_mob = user
	. = ..()

/datum/action/innate/proto_emitter/firing
	name = "Switch to Manual Firing"
	desc = "The emitter will only fire on your command and at your designated target"
	button_icon_state = "mech_zoom_on"

/datum/action/innate/proto_emitter/firing/Activate()
	if(proto_emitter.manual)
		playsound(proto_emitter,'sound/mecha/mechmove01.ogg', 50, TRUE)
		proto_emitter.manual = FALSE
		name = "Switch to Manual Firing"
		desc = "The emitter will only fire on your command and at your designated target"
		button_icon_state = "mech_zoom_on"
		for(var/obj/item/item in buckled_mob.held_items)
			if(istype(item, /obj/item/turret_control))
				qdel(item)
		build_all_button_icons()
		return
	playsound(proto_emitter,'sound/mecha/mechmove01.ogg', 50, TRUE)
	name = "Switch to Automatic Firing"
	desc = "Emitters will switch to periodic firing at your last target"
	button_icon_state = "mech_zoom_off"
	proto_emitter.manual = TRUE
	for(var/things in buckled_mob.held_items)
		var/obj/item/item = things
		if(istype(item))
			if(!buckled_mob.dropItemToGround(item))
				continue
			var/obj/item/turret_control/turret_control = new /obj/item/turret_control()
			buckled_mob.put_in_hands(turret_control)
		else //Entries in the list should only ever be items or null, so if it's not an item, we can assume it's an empty hand
			var/obj/item/turret_control/turret_control = new /obj/item/turret_control()
			buckled_mob.put_in_hands(turret_control)
	build_all_button_icons()

/obj/item/turret_control
	name = "управление туррелью"
	icon_state = "offhand"
	w_class = WEIGHT_CLASS_HUGE
	item_flags = ABSTRACT | NOBLUDGEON
	resistance_flags = FIRE_PROOF | UNACIDABLE | ACID_PROOF
	var/delay = 0

/obj/item/turret_control/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, ABSTRACT_ITEM_TRAIT)

/obj/item/turret_control/afterattack(atom/targeted_atom, mob/user, proxflag, clickparams)
	. = ..()
	var/obj/machinery/power/emitter/E = user.buckled
	E.setDir(get_dir(E,targeted_atom))
	user.setDir(E.dir)
	switch(E.dir)
		if(NORTH)
			E.layer = 3.9
			user.pixel_x = 0
			user.pixel_y = -14
		if(NORTHEAST)
			E.layer = 3.9
			user.pixel_x = -8
			user.pixel_y = -12
		if(EAST)
			E.layer = 4.1
			user.pixel_x = -14
			user.pixel_y = 0
		if(SOUTHEAST)
			E.layer = 3.9
			user.pixel_x = -8
			user.pixel_y = 12
		if(SOUTH)
			E.layer = 4.1
			user.pixel_x = 0
			user.pixel_y = 14
		if(SOUTHWEST)
			E.layer = 3.9
			user.pixel_x = 8
			user.pixel_y = 12
		if(WEST)
			E.layer = 4.1
			user.pixel_x = 14
			user.pixel_y = 0
		if(NORTHWEST)
			E.layer = 3.9
			user.pixel_x = 8
			user.pixel_y = -12

	E.last_projectile_params = calculate_projectile_angle_and_pixel_offsets(user, null, clickparams)

	if(E.charge >= 10 && world.time > delay)
		E.charge -= 10
		E.fire_beam(user)
		delay = world.time + 10
	else if (E.charge < 10)
		playsound(src,'white/valtos/sounds/error1.ogg', 50, TRUE)

/obj/machinery/power/emitter/ctf
	name = "энергопушка"
	active = TRUE
	active_power_usage = 0
	idle_power_usage = 0
	locked = TRUE
	req_access_txt = "100"
	welded = TRUE
	use_power = NO_POWER_USE
