/datum/disease/gbs
	name = "GBS"
	max_stages = 4
	spread_text = "При контакте"
	spread_flags = DISEASE_SPREAD_BLOOD | DISEASE_SPREAD_CONTACT_SKIN | DISEASE_SPREAD_CONTACT_FLUIDS
	cure_text = "Синаптизин и сера"
	cures = list(/datum/reagent/medicine/synaptizine,/datum/reagent/sulfur)
	cure_chance = 7.5 //higher chance to cure, since two reagents are required
	agent = "Гравитокинетические бипотенциальные SADS+"
	viable_mobtypes = list(/mob/living/carbon/human)
	disease_flags = CAN_CARRY|CAN_RESIST|CURABLE
	spreading_modifier = 1
	severity = DISEASE_SEVERITY_BIOHAZARD

/datum/disease/gbs/stage_act(delta_time, times_fired)
	. = ..()
	if(!.)
		return

	switch(stage)
		if(2)
			if(DT_PROB(2.5, delta_time))
				affected_mob.emote("cough")
		if(3)
			if(DT_PROB(2.5, delta_time))
				affected_mob.emote("gasp")
			if(DT_PROB(5, delta_time))
				to_chat(affected_mob, span_danger("Всё тело болит!"))
		if(4)
			to_chat(affected_mob, span_userdanger("Тело разрывается на куски!"))
			if(DT_PROB(30, delta_time))
				affected_mob.gib()
				return FALSE
