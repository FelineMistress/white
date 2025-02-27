//Bluespace crystals, used in telescience and when crushed it will blink you to a random turf.
/obj/item/stack/ore/bluespace_crystal
	name = "блюспейс кристаллы"
	desc = "Светящийся блюспейс кристалл, мало что известно о том, как они работают. Этот выглядит очень деликатно."
	icon = 'icons/obj/telescience.dmi'
	icon_state = "bluespace_crystal"
	singular_name = "блюспейс кристалл"
	dye_color = DYE_COSMIC
	w_class = WEIGHT_CLASS_TINY
	mats_per_unit = list(/datum/material/bluespace=MINERAL_MATERIAL_AMOUNT)
	points = 50
	refined_type = /obj/item/stack/sheet/bluespace_crystal
	grind_results = list(/datum/reagent/bluespace = 20)
	scan_state = "rock_BScrystal"
	merge_type = /obj/item/stack/ore/bluespace_crystal
	/// The teleport range when crushed/thrown at someone.
	var/blink_range = 8

/obj/item/stack/ore/bluespace_crystal/refined
	name = "изысканный блюспейс кристалл"
	points = 0
	refined_type = null
	merge_type = /obj/item/stack/ore/bluespace_crystal/refined

/obj/item/stack/ore/bluespace_crystal/Initialize(mapload, new_amount, merge = TRUE, list/mat_override=null, mat_amt=1)
	. = ..()
	pixel_x = rand(-5, 5)
	pixel_y = rand(-5, 5)

/obj/item/stack/ore/bluespace_crystal/get_part_rating()
	return 1

/obj/item/stack/ore/bluespace_crystal/attack_self(mob/user)
	user.visible_message(span_warning("<b>[user]</b> раздавливает <b>[src]</b>!") , span_danger("Раздавливаю <b>[src]</b>!"))
	new /obj/effect/particle_effect/sparks(loc)
	playsound(loc, "zap", 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	blink_mob(user)
	use(1)

/obj/item/stack/ore/bluespace_crystal/proc/blink_mob(mob/living/L)
	do_teleport(L, get_turf(L), blink_range, asoundin = 'sound/effects/phasein.ogg', channel = TELEPORT_CHANNEL_BLUESPACE)

/obj/item/stack/ore/bluespace_crystal/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	if(!..()) // not caught in mid-air
		visible_message(span_notice("<b>[capitalize(src.name)]</b> шипит и исчезает при ударе!"))
		var/turf/T = get_turf(hit_atom)
		new /obj/effect/particle_effect/sparks(T)
		playsound(loc, "zap", 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		if(isliving(hit_atom))
			blink_mob(hit_atom)
		use(1)

//Artificial bluespace crystal, doesn't give you much research.
/obj/item/stack/ore/bluespace_crystal/artificial
	name = "синтетический блюспейс кристалл"
	desc = "Искусственно сделанный блюспейс кристалл, выглядит изысканно."
	mats_per_unit = list(/datum/material/bluespace=MINERAL_MATERIAL_AMOUNT*0.5)
	blink_range = 4 // Not as good as the organic stuff!
	points = 0 //nice try
	refined_type = null
	grind_results = list(/datum/reagent/bluespace = 10, /datum/reagent/silicon = 20)
	merge_type = /obj/item/stack/ore/bluespace_crystal/artificial

/obj/item/stack/ore/bluespace_crystal/artificial/attack_hand(mob/user, list/modifiers)
	. = ..()
	custom_materials = list(/datum/material/bluespace = MINERAL_MATERIAL_AMOUNT)

//Polycrystals, aka stacks
/obj/item/stack/sheet/bluespace_crystal
	name = "блюспейс поликристаллы"
	icon = 'icons/obj/telescience.dmi'
	icon_state = "polycrystal"
	inhand_icon_state = "sheet-polycrystal"
	singular_name = "блюспейс поликристалл"
	desc = "Стабильный поликристалл, изготовленный из сплавленных блюспейс кристаллов. Вы могли бы вероятно сломать один."
	mats_per_unit = list(/datum/material/bluespace=MINERAL_MATERIAL_AMOUNT)
	attack_verb_continuous = list("блюспейс полибьёт", "блюспейс полиударяет", "блюспейс полилупит", "блюспейс поливмазывает", "блюспейс полиразносит")
	attack_verb_simple = list("блюспейс полибьёт", "блюспейс полиударяет", "блюспейс полилупит", "блюспейс поливмазывает", "блюспейс полиразносит")
	novariants = TRUE
	grind_results = list(/datum/reagent/bluespace = 20)
	point_value = 30
	merge_type = /obj/item/stack/sheet/bluespace_crystal
	var/crystal_type = /obj/item/stack/ore/bluespace_crystal/refined

/obj/item/stack/sheet/bluespace_crystal/attack_self(mob/user)// to prevent the construction menu from ever happening
	to_chat(user, span_warning("Не могу сломать целый поликристалл в руке. Надо бы их разделить."))

//ATTACK HAND IGNORING PARENT RETURN VALUE
/obj/item/stack/sheet/bluespace_crystal/attack_hand(mob/user)
	if(user.get_inactive_held_item() == src)
		if(is_zero_amount())
			return
		var/BC = new crystal_type(src)
		user.put_in_hands(BC)
		use(1)
		if(!amount)
			to_chat(user, span_notice("Разбиваю последний кристалл."))
		else
			to_chat(user, span_notice("Разбиваю кристалл."))
	else
		..()
