/datum/keybinding/client/communication
	category = CATEGORY_COMMUNICATION

/datum/keybinding/client/communication/say
	hotkey_keys = list("F3", "T")
	name = SAY_CHANNEL
	full_name = "Сказать"
	keybind_signal = COMSIG_KB_CLIENT_SAY_DOWN

/datum/keybinding/client/communication/say/down(client/user)
	. = ..()
	if(.)
		return
	winset(user, null, "command=[user.tgui_say_create_open_command(SAY_CHANNEL)]")
	return TRUE

/datum/keybinding/client/communication/radio
	hotkey_keys = list("Y")
	name = RADIO_CHANNEL
	full_name = "Радио (;)"
	keybind_signal = COMSIG_KB_CLIENT_RADIO_DOWN

/datum/keybinding/client/communication/radio/down(client/user)
	. = ..()
	if(.)
		return
	winset(user, null, "command=[user.tgui_say_create_open_command(RADIO_CHANNEL)]")
	return TRUE

/datum/keybinding/client/communication/ooc
	hotkey_keys = list("O")
	name = OOC_CHANNEL
	full_name = "Out Of Character (OOC)"
	keybind_signal = COMSIG_KB_CLIENT_OOC_DOWN

/datum/keybinding/client/communication/ooc/down(client/user)
	. = ..()
	if(.)
		return
	winset(user, null, "command=[user.tgui_say_create_open_command(OOC_CHANNEL)]")
	return TRUE

/datum/keybinding/client/communication/me
	hotkey_keys = list("F4", "M")
	name = ME_CHANNEL
	full_name = "Эмоция (/Действия)"
	keybind_signal = COMSIG_KB_CLIENT_ME_DOWN

/datum/keybinding/client/communication/me/down(client/user)
	. = ..()
	if(.)
		return
	winset(user, null, "command=[user.tgui_say_create_open_command(ME_CHANNEL)]")
	return TRUE
