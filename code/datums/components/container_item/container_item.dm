/// Container item, an item which can be stored by specialized containers.
/datum/component/container_item

/datum/component/container_item/Initialize(mapload)
	. = ..()
	RegisterSignal(parent, COMSIG_CONTAINER_TRY_ATTACH, PROC_REF(try_attach))

/// Called when parent is added to the container.
/datum/component/container_item/proc/try_attach(datum/source, atom/container, mob/user)
	SIGNAL_HANDLER
	return FALSE
