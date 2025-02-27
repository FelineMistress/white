/datum/round_event_control/wizard/deprevolt //stationwide!
	name = "Departmental Uprising"
	weight = 0 //An order that requires order in a round of chaos was maybe not the best idea. Requiescat in pace departmental uprising August 2014 - March 2015
	typepath = /datum/round_event/wizard/deprevolt
	max_occurrences = 1
	earliest_start = 0 MINUTES

	var/picked_department
	var/announce = FALSE
	var/dangerous_nation = TRUE

/datum/round_event_control/wizard/deprevolt/admin_setup()
	if(!check_rights(R_FUN))
		return
	var/list/options = list("Random", "Uprising of Assistants", "Medical", "Engineering", "Science", "Supply", "Service", "Security")
	picked_department = tgui_input_list(usr, "Which department should revolt?", "Select a department", options)

	var/announce_question = tgui_alert(usr, "Announce This New Independent State?", "Secession", list("Announce", "No Announcement"))
	if(announce_question == "Announce")
		announce = TRUE

	var/dangerous_question = tgui_alert(usr, "Dangerous Nation? This means they will fight other nations.", "Conquest", list("Yes", "No"))
	if(dangerous_question == "No")
		dangerous_nation = FALSE

	//this is down here to allow the random system to pick a department whilst considering other independent departments
	if(!picked_department || picked_department == "Random")
		picked_department = null
		return

/datum/round_event/wizard/deprevolt/start()

	var/list/tidecolor
	var/list/jobs_to_revolt	= 	list()
	var/nation_name
	var/list/citizens	=		list()

	tidecolor = pick("grey", "white", "yellow", "purple", "brown", "whatevercolorrepresentstheservicepeople")
	switch(tidecolor)
		if("grey") //God help you
			jobs_to_revolt = list(JOB_ASSISTANT)
			nation_name = pick("Assa", "Mainte", "Tunnel", "Gris", "Grey", "Liath", "Grigio", "Ass", "Assi")
		if("white")
			jobs_to_revolt = GLOB.medical_positions
			nation_name = pick("Mede", "Healtha", "Recova", "Chemi", "Viro", "Psych")
		if("yellow")
			jobs_to_revolt = GLOB.engineering_positions
			nation_name = pick("Atomo", "Engino", "Power", "Teleco")
		if("purple")
			jobs_to_revolt = GLOB.science_positions
			nation_name = pick("Sci", "Griffa", "Geneti", "Explosi", "Mecha", "Xeno")
		if("brown")
			jobs_to_revolt = GLOB.supply_positions
			nation_name = pick("Cargo", "Guna", "Suppli", "Mule", "Crate", "Ore", "Mini", "Shaf")
		if("whatevercolorrepresentstheservicepeople") //the few, the proud, the technically aligned
			jobs_to_revolt = GLOB.service_positions.Copy() - list(JOB_ASSISTANT)
			nation_name = pick("Honka", "Boozo", "Fatu", "Danka", "Mimi", "Libra", "Jani", "Religi")

	nation_name += pick("stan", "topia", "land", "nia", "ca", "tova", "dor", "ador", "tia", "sia", "ano", "tica", "tide", "cis", "marea", "co", "taoide", "slavia", "stotzka")

	var/datum/team/nation/nation = new
	nation.name = nation_name

	for(var/i in GLOB.human_list)
		var/mob/living/carbon/human/H = i
		if(H.mind)
			var/datum/mind/M = H.mind
			if(M.assigned_role && !(M.has_antag_datum(/datum/antagonist)))
				for(var/job in jobs_to_revolt)
					if(M.assigned_role == job)
						citizens += H
						M.add_antag_datum(/datum/antagonist/separatist,nation)
						H.log_message("Was made into a separatist, long live [nation_name]!", LOG_ATTACK, color="red")

	if(citizens.len)
		var/message
		for(var/job in jobs_to_revolt)
			message += "[job],"
		message_admins("The nation of [nation_name] has been formed. Affected jobs are [message]")
