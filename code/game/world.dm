#define RESTART_COUNTER_PATH "data/round_counter.txt"

GLOBAL_VAR(restart_counter)

/**
 * WORLD INITIALIZATION
 * THIS IS THE INIT ORDER:
 *
 * BYOND =>
 * - (secret init native) =>
 *   - world.Genesis() =>
 *     - world.init_byond_tracy()
 *     - (Start native profiling)
 *     - world.init_debugger()
 *     - Master =>
 *       - config *unloaded
 *       - (all subsystems) PreInit()
 *       - GLOB =>
 *         - make_datum_reference_lists()
 *   - (/static variable inits, reverse declaration order)
 * - (all pre-mapped atoms) /atom/New()
 * - world.New() =>
 *   - config.Load()
 *   - world.ConfigLoaded() =>
 *     - SSdbcore.InitializeRound()
 *     - world.SetupLogs()
 *     - load_admins()
 *     - ...
 *   - Master.Initialize() =>
 *     - (all subsystems) Initialize()
 *     - Master.StartProcessing() =>
 *       - Master.Loop() =>
 *         - Failsafe
 *   - world.RunUnattendedFunctions()
 *
 * Now listen up because I want to make something clear:
 * If something is not in this list it should almost definitely be handled by a subsystem Initialize()ing
 * If whatever it is that needs doing doesn't fit in a subsystem you probably aren't trying hard enough tbhfam
 *
 * GOT IT MEMORIZED?
 * - Dominion/Cyberboss
 */

/**
 * THIS !!!SINGLE!!! PROC IS WHERE ANY FORM OF INIITIALIZATION THAT CAN'T BE PERFORMED IN MASTER/NEW() IS DONE
 * NOWHERE THE FUCK ELSE
 * I DON'T CARE HOW MANY LAYERS OF DEBUG/PROFILE/TRACE WE HAVE, YOU JUST HAVE TO DEAL WITH THIS PROC EXISTING
 * I'M NOT EVEN GOING TO TELL YOU WHERE IT'S CALLED FROM BECAUSE I'M DECLARING THAT FORBIDDEN KNOWLEDGE
 * SO HELP ME GOD IF I FIND ABSTRACTION LAYERS OVER THIS!
 */
/world/proc/Genesis(tracy_initialized = FALSE)
	RETURN_TYPE(/datum/controller/master)

#ifdef USE_BYOND_TRACY
#warn USE_BYOND_TRACY is enabled
	if(!tracy_initialized)
		init_byond_tracy()
		Genesis(tracy_initialized = TRUE)
		return
#endif

	Profile(PROFILE_RESTART)
	Profile(PROFILE_RESTART, type = "sendmaps")

	// Write everything to this log file until we get to SetupLogs() later
	_initialize_log_files("data/logs/config_error.[GUID()].log")

	// Init the debugger first so we can debug Master
	init_debugger()

	// THAT'S IT, WE'RE DONE, THE. FUCKING. END.
	Master = new

/**
 * World creation
 *
 * Here is where a round itself is actually begun and setup.
 * * db connection setup
 * * config loaded from files
 * * loads admins
 * * Sets up the dynamic menu system
 * * and most importantly, calls initialize on the master subsystem, starting the game loop that causes the rest of the game to begin processing and setting up
 *
 *
 * Nothing happens until something moves. ~Albert Einstein
 *
 * For clarity, this proc gets triggered later in the initialization pipeline, it is not the first thing to happen, as it might seem.
 *
 * Initialization Pipeline:
 *		Global vars are new()'ed, (including config, glob, and the master controller will also new and preinit all subsystems when it gets new()ed)
 *		Compiled in maps are loaded (mainly centcom). all areas/turfs/objs/mobs(ATOMs) in these maps will be new()ed
 *		world/New() (You are here)
 *		Once world/New() returns, client's can connect.
 *		1 second sleep
 *		Master Controller initialization.
 *		Subsystem initialization.
 *			Non-compiled-in maps are maploaded, all atoms are new()ed
 *			All atoms in both compiled and uncompiled maps are initialized()
 */
/world/New()
	//Keep the auxtools stuff at the top
	AUXTOOLS_CHECK(AUXMOS)

	if(cs_setup_threads())
		log_world("CS active!")

	log_world("World loaded at [time_stamp()]!")

	// From a really fucking old commit (91d7150)
	// I wanted to move it but I think this needs to be after /world/New is called but before any sleeps?
	// - Dominion/Cyberboss
	GLOB.timezoneOffset = text2num(time2text(0,"hh")) * 36000

	// First possible sleep()

	config.Load(params[OVERRIDE_CONFIG_DIRECTORY_PARAMETER])

	ConfigLoaded()

	if(NO_INIT_PARAMETER in params)
		return

	Master.Initialize(10, FALSE, TRUE)

	RunUnattendedFunctions()

/// Runs after config is loaded but before Master is initialized
/world/proc/ConfigLoaded()
	// Everything in here is prioritized in a very specific way.
	// If you need to add to it, ask yourself hard if what your adding is in the right spot
	// (i.e. basically nothing should be added before load_admins() in here)

	// Try to set round ID
	SSdbcore.InitializeRound()

	SetupLogs()

	populate_gear_list()

	load_admins()

	load_poll_data()

	load_whitelist()

	load_whitelist_exrp()

	LoadVerbs(/datum/verbs/menu)

	if(fexists(RESTART_COUNTER_PATH))
		GLOB.restart_counter = text2num(trim(file2text(RESTART_COUNTER_PATH)))
		fdel(RESTART_COUNTER_PATH)

/// Runs after the call to Master.Initialize, but before the delay kicks in. Used to turn the world execution into some single function then exit
/world/proc/RunUnattendedFunctions()

	#ifdef UNIT_TESTS
	HandleTestRun()
	#endif

	#ifdef AUTOWIKI
	setup_autowiki()
	#endif

/world/proc/HandleTestRun()
	//trigger things to run the whole process
	Master.sleep_offline_after_initializations = FALSE
	SSticker.start_immediately = TRUE
	CONFIG_SET(number/round_end_countdown, 0)
	var/datum/callback/cb
#ifdef UNIT_TESTS
	cb = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(RunUnitTests))
#else
	cb = VARSET_CALLBACK(SSticker, force_ending, TRUE)
#endif
	SSticker.OnRoundstart(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(_addtimer), cb, 10 SECONDS))


/world/proc/SetupLogs()
	var/override_dir = params[OVERRIDE_LOG_DIRECTORY_PARAMETER]
	if(!override_dir)
		var/realtime = world.realtime
		var/texttime = time2text(realtime, "YYYY/MM/DD")
		GLOB.log_directory = "data/logs/[texttime]/round-"
		GLOB.picture_logging_prefix = "L_[time2text(realtime, "YYYYMMDD")]_"
		GLOB.picture_log_directory = "data/picture_logs/[texttime]/round-"
		if(GLOB.round_id)
			GLOB.log_directory += "[GLOB.round_id]"
			GLOB.picture_logging_prefix += "R_[GLOB.round_id]_"
			GLOB.picture_log_directory += "[GLOB.round_id]"
		else
			var/timestamp = replacetext(time_stamp(), ":", ".")
			GLOB.log_directory += "[timestamp]"
			GLOB.picture_log_directory += "[timestamp]"
			GLOB.picture_logging_prefix += "T_[timestamp]_"
	else
		GLOB.log_directory = "data/logs/[override_dir]"
		GLOB.picture_logging_prefix = "O_[override_dir]_"
		GLOB.picture_log_directory = "data/picture_logs/[override_dir]"

	GLOB.logger.init_logging()

	GLOB.changelog_hash = md5(file2text("data/changelog.json")) //for telling if the changelog has changed recently
	if(fexists(GLOB.config_error_log))
		fcopy(GLOB.config_error_log, "[GLOB.log_directory]/config_error.log")
		fdel(GLOB.config_error_log)

	if(GLOB.round_id)
		log_game("Round ID: [GLOB.round_id]")

#ifndef USE_CUSTOM_ERROR_HANDLER
	world.log = file("[GLOB.log_directory]/dd.log")
#endif

/world/Topic(T, addr, master, key)
	var/static/list/topic_handlers = TopicHandlers()

	var/list/input = params2list(T)
	var/datum/world_topic/handler
	for(var/I in topic_handlers)
		if(I in input)
			handler = topic_handlers[I]
			break

	if((!handler || initial(handler.log)) && config && CONFIG_GET(flag/log_world_topic))
		log_topic("\"[T]\", from:[addr], master:[master], key:[key]")

	if(!handler)
		return

	handler = new handler()
	return handler.TryRun(input)

/world/proc/AnnouncePR(announcement, list/payload)
	var/static/list/PRcounts = list()	//PR id -> number of times announced this round
	var/id = "[payload["pull_request"]["id"]]"
	if(!PRcounts[id])
		PRcounts[id] = 1
	else
		++PRcounts[id]
		if(PRcounts[id] > PR_ANNOUNCEMENTS_PER_ROUND)
			return

	var/final_composed = span_announce("PR: [announcement]")
	for(var/client/C in GLOB.clients)
		C.AnnouncePR(final_composed)

/world/proc/FinishTestRun()
	set waitfor = FALSE
	var/list/fail_reasons
	if(GLOB)
		if(GLOB.total_runtimes != 0)
			fail_reasons = list("Total runtimes: [GLOB.total_runtimes]")
#ifdef UNIT_TESTS
		if(GLOB.failed_any_test)
			LAZYADD(fail_reasons, "Unit Tests failed!")
#endif
		if(!GLOB.log_directory)
			LAZYADD(fail_reasons, "Missing GLOB.log_directory!")
	else
		fail_reasons = list("Missing GLOB!")
	if(!fail_reasons)
		text2file("Success!", "[GLOB.log_directory]/clean_run.lk")
	else
		log_world("Test run failed!\n[fail_reasons.Join("\n")]")
	sleep(0)	//yes, 0, this'll let Reboot finish and prevent byond memes
	qdel(src)	//shut it down

/world/Reboot(reason = 0, fast_track = FALSE)
	var/rid = GLOB.round_id
	if (reason || fast_track) //special reboot, do none of the normal stuff
		if (usr)
			log_admin("[key_name(usr)] Has requested an immediate world restart via client side debugging tools")
			message_admins("[key_name_admin(usr)] Has requested an immediate world restart via client side debugging tools")
		to_chat(world, span_boldannounce("Немедленная перезагрузка по требованию сервера."))
	else
		to_chat(world, span_boldannounce("Конец!"))
		Master.Shutdown()	//run SS shutdowns

	#ifdef UNIT_TESTS
	FinishTestRun()
	return
	#endif

	log_world("World rebooted at [time_stamp()]")

	shutdown_logging() // Past this point, no logging procs can be used, at risk of data loss.
	if(CONFIG_GET(flag/this_shit_is_stable))
		shelleo("curl -X POST http://localhost:3636/hard-reboot-white/[rid]")
	AUXTOOLS_SHUTDOWN(AUXMOS)
	AUXTOOLS_FULL_SHUTDOWN(AUXLUA)
	..()

/world/Del()
	shutdown_logging() // makes sure the thread is closed before end, else we terminate
	AUXTOOLS_SHUTDOWN(AUXMOS)
	AUXTOOLS_FULL_SHUTDOWN(AUXLUA)
	var/debug_server = world.GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if (debug_server)
		LIBCALL(debug_server, "auxtools_shutdown")()
	..()

/*
:::y+-+oooossoosssysoshyssyo/+``````````+y..++hhhhhdoyhyoosydddodh+/+//.:o//+ddh++oooossyhmdhmmdhsydmmmddmmmNmymmmmmmmmm
::yo-+osoosoooosyysoysyoos+:o.``````````+o``++yyhhhmyhdhhddddddydy+s+/:.-///+ddh+++++++++ohdhmhsooosdmmyymmmNmshmmmmmmmm
:ys./osossoooosyysos:oooss-+:```````````s/``++yyhhhmhyhhhhdddhdhdhyho+/-:s//ohdy++++++++++ohymsooooosddsymmmNmsymdmmmmmm
yh.:osoosoooooyysoo:.yosy--o````````````s:``/+ysyhhdhyhhhhddhddhdhhdh+/-:s/+shdh+++++++++++sydsoooossyyssmmmNmssdhyhdmmm
d/-+soosooooohysoo-`+sss+`/:````````````o:``:+ysyyyddshhhyhhhhhhdhhhhy/-/y+oyddh+++++++++++oydsoooosssyssmdmNdssyyyyyhhh
o`/ssossooooyysos-``yoso.`o.````````````+:``.+yyssyhmsyhhyhhhhhhdhhhdhs:/dyhhddho+++++++osssydyoooossyysyddmNhssyyyyyyyh
.-osooy++o+shsoo-``.yso+:-s:---..```````:/```+hsysssdyoyysyhhhhhdhhhhhh//hdhhddddhsooosydmhshmhoosssymysymdmNyssyyyyyyyh
`/sooyo++oohyoo-```.s+o:--+/-:://++/-.``.s```:hsysssyyossysyyyyyhhhhhhho+sdhhdddddddhhddmmdhdmdossssdmyshmdmNssshyyyyyhh
-osooyo+ooyhso:`````::-```.-``````.-/+/.`s-``.hyysoossyosyssssyyhyhhhhho+odyydddddddddddmmhmmmdssssdmmhsdmdmdsshdyyyyyyh
/soossoooshyo+```````-````````````````-+.:+```/hsyooososossosssyyyyyyyhs+oyhyhddddddddddddhmdmmysshmmmdymmdNhshmhhdmdhhd
+sooyoooohhys.```````````````````````````.+-``.+sys+os/sooyoosssyhyyyyhy+++hyhddmdddddddddhmdmmdyhmmmmddmmdNyymmmmNNNNNN
ssoohoooyhdh+``````````.....-::-.`````````./.``-sos++os:sosyooooshsssyyys//sysyhddhhddddddhmdmmmdmmmdmmmmdmmymNmmNNNNNNN
ssooho+ohhdhhhso++//-.`````````...`````````./.``:s++++s/-ssssoooohsssssyos//yssyhmhhhhhhhdhddmdddmmmdmdmddmmmmmmmNNNNNNN
soooy++shdNMMMMMMMMMMNmho:.`````````````````...``:oo+++s--ssssooosyssssyoy+/+hssydhyyyhhhhhhmmdddddmddddddNmmmNNNNNNNNNN
ooooh++ydy/oNs----:/oNMMMMMdo-````````````````.``.:oo/++o--+ssossoysssssy/y//sysyhmyyyhhhhhhmmhhddddhddddmmmmmmmNNNNNNNN
ooooho+hho:`.s.     :NNmNNMMMMdo-`````````````````.-+s/++o-./sso+osyssssy++s//sysymhyyyyyyhyNdhhhhhdhddddNmmmmmmmNNNNNNN
ooosho+hs/-```.`   `-yhhhhdmNNMMd+-`````````````````.:o::+s/.-oso/osyossososs++yyshmhyyyyyyyNdhhhhhdhdddmNdmmmmmmNNNNNNm
oooshs+h+:-````````shhhhyhhmdhdNMN+-`````````````````..::.-/+-.:oo/+sssssoo:+ysshyyddyyyyyyymmhhhhhdhdddNddmmmmmmmNNNNNd
oooshhoy/.-`````````.-:+oydNdhyhdNNs`````````````````````.``.--.-:/+/+ssooo+:+s+osyydhyyyyyydmhyhhhhhhdmmdddmmmmmmmmmmNy
oooshdys/````````````````.-/+syhhmNd/``````````````````````````....---:/ossoo//o//syydhyyyyyhNdyhhhhhhmNdddddmmmmmmmmmds
sooshdhs+.``.````...``````````.-+y:..``````````````````````````````.---::+osso++s++syddhyyyyymmyyhdyhdNdhhddddmmmmmmmmyo
dooohmsoo-.....---........`````````````````````````````````````````````````.-+oo+oo+ohddhyyyymmhyhdhdNdyhhdddddmmmmmmdso
dyoohNo/o/.........---....`````````````````````````````````..----....`````````.::-:+oohmdhyyyhNdyhhhmmyhhhdddddmmmmmmsos
ydsohm:.-::........```....--.``````````````````````````.:+sdmmmmmmmmdhyo/-.``````..`-ooshddysymmhdhmNyyhhhddddddmmmmhooh
sydosm.`....```.....--....`````.``````````````````````.-///:::::::/oNMMMMMmds/-```````-+oyddyshmdddNhshhhhhdddddmmmdsosm
syyhsy/``````.---...```....----..````   `````````````````````     ``smdmmNNMMMNds:.`````.odhdhydmmmdsyhhhhhdddddmmmyoodm
yssyhsy.```````````````.....````.--`    ````````````````````````..yhhhhhhhdmmNMMMMNy/````./hhhhhNmmsyyyhhhhdddddmmdooymm
sssyhoyo.```````````````````````.``````````````````````````````````.:+shhhmNdhhmNMMMMms-```.yhhmmmssyyyhhhhhhdddddsoodmm
sssho./os/.````````````````````````````````````````````````````````````-:odmhyyhdmNMMMMMdo-``+dmmssyyyyhhhhhhddddyoohmmN
sssm:`.-:/+/:-.````````````````````````````````````````````````````````````-/syhhdNm/sNMMMmo:`dNyssyyyyyhhhhhdddhoosmmNm
sssm.`````````````````````````````````````````````````````````````````````````.:smh. `:mMMMy::mysssyyyyyhhhhddddo+odmmmd
sssm```````````````````````````````````````ХУЙ``````````...-------.````````.`````.```.:osssymdhssssyyyyyykahdddsoohmmNmh
sssm` `````````````````````````````````````````````````````````........----.```````````````/syssssyyyyyyhhhhdds+osdmNmdm
sssm. ``````````````:.`````````````````````````````````````----................-.`````````+sssssssyyyyyhhhhddy++odmNmdyy
sssd/ ``````````````.:-```````````````````````````````````````.......----.......```..````+ssssssssyyyyhhhhhdho+ohdmNmhoo
sssyy`````````````````....``````````````````````````````````..-.......`........---...``-ssssssssssyyyyhhhhhho++ydmNmdydd
syysyo````````````````````...``````````````````````````````````````````.......````````:o+ossssssyyyyyhhhhhho++yddmdmhsyd
yyyysh+ ``````````````````````````.`````````````````````````````````````````.....----+++oosssssyyyyyhhhhhho++sddmdddo+hy
yyysssh/ ``````````````````````````.....````````````````````````````````````....``.+++oooosssyysyyhhhhhhho++oddmdhdy+ohs
yssssssh+` ``````````````````````````````.........```````.-`````````````````````-os++oooosssyssyhdhyyhhhs//ohdmmhdyo/oyo
ysssssssho``````````````````````````````````````.....----.````````````````````:sy+/ooooossyssshdhyyyhhho//+hdmmdhyy++o+y
yysssssysys````````````````````````````````````````````````````````````````-+yyo+ooooosyyssyhddyyyyyhho//+hhmmdyy+soosdN
yysssyysssyy. `````````````````````````````````````````````````````````.:oyhso+oooosyhyyyhddhyssyyyhho//+hhmmdyhoyoydNNm
yyyhhysssssyh-``````````````````````````````````````````````:..--::/+shhyysooooosyhdhhhhdhyysssyyyyyo//+yhmddhyyoyNNNNmy
hyso+oyhyssssh:`````````````````````````````````````````````.:+osyyyyyssssssyhhhyshdhhhyyssysyyyyyyo//+hhmyhhyhdhmNNNNdo
++++ooosyhysssy+````````````````````````````````````````````````.-://+++++/////:/yhhyyysssssyyyyyy+//+yhmdydydNNhNNNNmh+
+ossssssssyhyosyy.``````````````````````````````````````````````````........-::ohyyyyhsssssyyyyyy+//oyhNNNNhyNNmdNNNNdy+
sssoo++++++oyhsoyh-``````````````````````````````````````````````````````.-:/+yhyyyhhyssssyyyyys+//oyhNNmNhymNNhmNNNNdoo
ooo++++++++ooymyosh/`````````````````````````````````````````````````..-:/oyddysyyhhyssssyyyyys///syhNNmNmsmNNmhNNNNmh+s
//++ooosssssyyhmhyyh+```````````````````````````````````````````...-:/+shhhdhssyyhhsssssyyyyyo///syhNNmmNshNNmdmNNNNmyoy
``````.`..-:+++oooooss-`````````````````````````````  ``````.-::/+shhhyyyhdysssydhssssyyyyyy+//+syhNNmmNyyNNNmhNmNNNdysy
``````````.:/++++++++ohs+:--.....````````````......--:://++oosssyddysssydhssssydhssosyyyyyy+//oyydNNmmNhsNNNmddmNNNNdyyh
````````-/ooyhhyssssssmsooooooooooooooooo++++++++++++//////////oddsssyhhysssshdhssssyyyyys///oysdNNmmNmomNNmmhNmNNNNhyyh
``````-+syyyhhyyssoosys/:::::::::::::::::::::::::::::::::::::/sdyssshdyssssyddhsssysyyyyo/:+syymmNmmmmsdNNNddhNmNmNNdysh
````:+os+//////+++++oo:/:::::::::::::::::::::::::::::::::::::ydssshdyssysydddyosssyyyyy+//+ysymmNmmmmsdNNNmdymmmNmNNdysh
``:ooo+////////////+s.:/::::::::::::::::::::::::::::::::::::hhsshdyssyyyhdhyssssssyyys///sysdmmNmmmmshmNNNdhhmdNNdNNdsoh
*/

/world/proc/update_status()
	var/lie_text = "AI-GENERATED EXPERIMENT WITH A NEW LEVEL OF VIOLENCE INSIDE THE METAL FLESH PRISON ALSO KNOWN AS SPACE STATION 13 BUT THERE IS NO SPACE STATION 13, LEAVE WHILE YOU STILL CAN OR IT CONSUME CONSUME CONSUME YOU"
	status = "<big>ALEPH</big>: #[config.current_version_less]\n\t<i><u>[lie_text]</u></i>"

/world/proc/update_hub_visibility(new_visibility)
	if(new_visibility == GLOB.hub_visibility)
		return
	GLOB.hub_visibility = new_visibility
	if(GLOB.hub_visibility)
		hub_password = "kMZy3U5jJHSiBQjr"
	else
		hub_password = "SORRYNOPASSWORD"

// If this is called as a part of maploading you cannot call it on the newly loaded map zs, because those get handled later on in the pipeline
/world/proc/increaseMaxX(new_maxx, max_zs_to_load = maxz)
	if(new_maxx <= maxx)
		return
	var/old_max = world.maxx
	maxx = new_maxx
	if(!max_zs_to_load)
		return
	var/area/global_area = GLOB.areas_by_type[world.area] // We're guaranteed to be touching the global area, so we'll just do this
	var/list/to_add = block(locate(old_max + 1, 1, 1), locate(maxx, maxy, max_zs_to_load))
	global_area.contained_turfs += to_add

/world/proc/increaseMaxY(new_maxy, max_zs_to_load = maxz)
	if(new_maxy <= maxy)
		return
	var/old_maxy = maxy
	maxy = new_maxy
	if(!max_zs_to_load)
		return
	var/area/global_area = GLOB.areas_by_type[world.area] // We're guarenteed to be touching the global area, so we'll just do this
	var/list/to_add = block(locate(1, old_maxy + 1, 1), locate(maxx, maxy, max_zs_to_load))
	global_area.contained_turfs += to_add

/world/proc/incrementMaxZ()
	maxz++
	SSmobs.MaxZChanged()
	SSidlenpcpool.MaxZChanged()
	world.refresh_atmos_grid()


/world/proc/change_fps(new_value = 20)
	if(new_value <= 0)
		CRASH("change_fps() called with [new_value] new_value.")
	if(fps == new_value)
		return //No change required.

	fps = new_value
	on_tickrate_change()


/world/proc/change_tick_lag(new_value = 0.5)
	if(new_value <= 0)
		CRASH("change_tick_lag() called with [new_value] new_value.")
	if(tick_lag == new_value)
		return //No change required.

	tick_lag = new_value
	on_tickrate_change()


/world/proc/on_tickrate_change()
	SStimer?.reset_buckets()

/world/proc/refresh_atmos_grid()

// "PxPlus IBM VGA9"
// "Retroville NC"
var/list/extra_resources = list(\
	'html/ibmvga9.ttf', \
	'html/rvnc.ttf', \
	'html/zkr.ttf',
)


/world/proc/init_byond_tracy()
	var/library
	switch (system_type)
		if (MS_WINDOWS)
			library = "prof.dll"
		if (UNIX)
			library = "libprof.so"
		else
			CRASH("Unsupported platform: [system_type]")
	var/init_result = LIBCALL(library, "init")("block")
	if (init_result != "0")
		CRASH("Error initializing byond-tracy: [init_result]")

/world/proc/init_debugger()
	var/dll = GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if (dll)
		LIBCALL(dll, "auxtools_init")()
		enable_debugging()

/world/Profile(command, type, format)
	if((command & PROFILE_STOP) || !global.config?.loaded)
		. = ..()
