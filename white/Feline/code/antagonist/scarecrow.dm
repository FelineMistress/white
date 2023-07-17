/// Психолог - Маска пугала


/obj/item/clothing/head/scarecrow
	name = "маска пугала"
	desc = "Угрожающая маска, с мощной системой фильтрации воздуха. Имеет функцию обратной акселирации фильтров, при использовании выдыхая дым и ненадолго активирую термосенсорный визор."
	icon = 'white/Feline/icons/scarecrow.dmi'
	icon_state = "scarecrow"
	worn_icon = 'white/Feline/icons/scarecrow_body.dmi'
	worn_icon_state = "scarecrow"
	inhand_icon_state = "gas_alt"
	flags_inv = HIDEEARS|HIDEEYES|HIDEFACE|HIDEFACIALHAIR|HIDESNOUT
	armor = list(MELEE = 30, BULLET = 10, LASER = 15, ENERGY = 25, BOMB = 5, BIO = 100, FIRE = 10, ACID = 100)
	flags_cover = HEADCOVERSEYES | HEADCOVERSMOUTH | PEPPERPROOF
	actions_types = list(/datum/action/cooldown/spell/smoke/scarecrow)

/// Гранаты
/obj/item/grenade/chem_grenade/scarecrow
	name = "граната психо-террора"
	desc = "Состав не известен даже производителю и смешивается случайным образом. Может содержать галюциногены, наркотические и психотропные вещества."
	stage = GRENADE_READY
	no_disassembly = TRUE

/obj/item/grenade/chem_grenade/scarecrow/n1_corgium/Initialize(mapload) // Корги + Пакс
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/pax, 60)
	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/corgium, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n2_demonium/Initialize(mapload) // Демоны + Кровь
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/demonium, 60)
	B1.reagents.add_reagent(/datum/reagent/toxin/heparin, 60)
	B1.reagents.add_reagent(/datum/reagent/blood, 15)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n3_skeletonium/Initialize(mapload) // Скелеты + Дезориентация
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/peaceborg/confuse, 60)
	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/skeletonium, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n4_zombium/Initialize(mapload) // Зомби + Усталость
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/peaceborg/tire, 60)
	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/zombium, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n5_carpium/Initialize(mapload) // Карпы + Мышечные спазмы
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/carpium, 120)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n6_monkeum/Initialize(mapload) // Обезьяны + Спавн обезьян
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/monkeum, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2
/*
/obj/item/grenade/chem_grenade/scarecrow/n7_morphium/Initialize(mapload) // Рвота
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/toxin/spewium/fast, 60)
	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/morphium, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n8_syndium/Initialize(mapload) // Искревление
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/syndium, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n9_skewium/Initialize(mapload) // Искревление
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/medicine/hallucinogen/statium, 60)
	B1.reagents.add_reagent(/datum/reagent/toxin/skewium, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2
*/

/obj/item/grenade/chem_grenade/scarecrow/n10_teargas/Initialize(mapload) // Перцовка
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/consumable/condensedcapsaicin, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/grenade/chem_grenade/scarecrow/n11_labebium/Initialize(mapload) // Лабебиум
	. = ..()
	var/obj/item/reagent_containers/glass/beaker/meta/B1 = new(src)
	var/obj/item/reagent_containers/glass/beaker/meta/B2 = new(src)

	B1.reagents.add_reagent(/datum/reagent/drug/labebium, 60)
	B1.reagents.add_reagent(/datum/reagent/potassium, 50)
	B2.reagents.add_reagent(/datum/reagent/phosphorus, 50)
	B2.reagents.add_reagent(/datum/reagent/consumable/sugar, 50)

	beakers += B1
	beakers += B2

/obj/item/storage/box/syndie_kit/scarecrow
	name = "набор пугала"

/obj/item/storage/box/syndie_kit/scarecrow/PopulateContents()
	var/list/types = subtypesof(/obj/item/grenade/chem_grenade/scarecrow)
	for(var/i in 1 to 6)
		var/type = pick(types)
		new type(src)
	new /obj/item/clothing/head/scarecrow(src)

