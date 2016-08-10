/obj/machinery/photocopier
	name = "photocopier"
	icon = 'icons/obj/library.dmi'
	icon_state = "bigscanner"
	var/insert_anim = "bigscanner1"
	var/opened = 0
	anchored = 1
	density = 1
	use_power = 1
	idle_power_usage = 30
	active_power_usage = 200

	New()
		..()
		component_parts = list()
		component_parts += new /obj/item/weapon/circuitboard/photocopier(src)
		component_parts += new /obj/item/weapon/stock_parts/manipulator(src)
		component_parts += new /obj/item/weapon/stock_parts/scanning_module(src)
		component_parts += new /obj/item/weapon/light/tube(src)
		RefreshParts()

	RefreshParts()
		for(var/obj/item/weapon/stock_parts/manipulator/M in component_parts)	// Up to 30 copies at once!
			maxcopies += M.rating*10
		for(var/obj/item/weapon/stock_parts/scanning_module/M in component_parts)	// Instantaneous Copying!
			copydelay -= M.rating*10

	power_channel = EQUIP
	var/obj/item/copyitem = null	//what's in the copier!
	var/copies = 1	//how many copies to print!
	var/toner = 30 //how much toner is left! woooooo~
	var/copydelay = 30 // Can be sped up using better parts.
	var/maxcopies = 0	//how many copies can be copied at once- idea shamelessly stolen from bs12's copier!
	var/form_index = 0 //Index of current form (how many forms have we printed).

/obj/machinery/photocopier/attack_ai(mob/user as mob)
	return attack_hand(user)

/obj/machinery/photocopier/attack_hand(mob/user as mob)
	user.set_machine(src)

	var/dat = "Photocopier<BR><BR>"
	dat += "<a href='byond://?src=\ref[src];form=1'>Print Form</a><BR>"
	if(copyitem)
		dat += "<a href='byond://?src=\ref[src];remove=1'>Remove Item</a><BR>"
		if(toner)
			dat += "<a href='byond://?src=\ref[src];copy=1'>Copy</a><BR>"
			dat += "Printing: [copies] copies."
			dat += "<a href='byond://?src=\ref[src];min=1'>-</a> "
			dat += "<a href='byond://?src=\ref[src];add=1'>+</a><BR><BR>"
	else if(toner)
		dat += "Please insert something to copy.<BR><BR>"
	if(istype(user,/mob/living/silicon))
		dat += "<a href='byond://?src=\ref[src];aipic=1'>Print photo from database</a><BR><BR>"
	dat += "Current toner level: [toner]"
	if(!toner)
		dat +="<BR>Please insert a new toner cartridge!"
	user << browse(dat, "window=copier")
	onclose(user, "copier")
	return

/obj/machinery/photocopier/Topic(href, href_list)
	if(href_list["copy"])
		if(stat & (BROKEN|NOPOWER))
			return

		for(var/i = 0, i < copies, i++)
			if(toner <= 0)
				break

			if (istype(copyitem, /obj/item/weapon/paper))
				copy(copyitem)
				sleep(copydelay)
			else if (istype(copyitem, /obj/item/weapon/photo))
				photocopy(copyitem)
				sleep(copydelay)
			else if (istype(copyitem, /obj/item/weapon/paper_bundle))
				var/obj/item/weapon/paper_bundle/B = bundlecopy(copyitem)
				sleep(copydelay*B.amount)
			else
				usr << "<span class='warning'>\The [copyitem] can't be copied by \the [src].</span>"
				break

			use_power(active_power_usage)
		updateUsrDialog()
	//Print a form from the list
	else if(href_list["form"])
		if(stat & (BROKEN|NOPOWER))
			return

		//The form selection stuff
		var/form = input("Select form:") as null|anything in public_forms
		var/copies = input("Number of copies ?") as null|num
		if(isnull(form)||isnull(copies))
			usr << "<span class='warning'>User input error!</span>"
			return
		if(copies > toner)
			usr << "<span class='warning'>Not enough toner for the amount of copies selected.</span>"
			return

		var/formContent = public_forms[form]

		for(var/i = 0, i < copies, i++)
			//This should never happen but you never know what magic people may pull.
			if(toner <= 0)
				break
				usr << "<span class='warning'>The [src] is out of toner.</span>"
			var/obj/item/weapon/paper/form/publicForm/pForm = new(formContent, print_date( universe.date ), usr, form_index)
			pForm.loc = src.loc
			pForm.name = form
			toner -= 1
			form_index += 1
			sleep(copydelay)

	else if(href_list["remove"])
		if(copyitem)
			copyitem.loc = usr.loc
			usr.put_in_hands(copyitem)
			usr << "<span class='notice'>You take \the [copyitem] out of \the [src].</span>"
			copyitem = null
			updateUsrDialog()
	else if(href_list["min"])
		if(copies > 1)
			copies--
			updateUsrDialog()
	else if(href_list["add"])
		if(copies < maxcopies)
			copies++
			updateUsrDialog()
	else if(href_list["aipic"])
		if(!istype(usr,/mob/living/silicon)) return
		if(stat & (BROKEN|NOPOWER)) return

		if(toner >= 5)
			var/mob/living/silicon/tempAI = usr
			var/obj/item/device/camera/siliconcam/camera = tempAI.aiCamera

			if(!camera)
				return
			var/obj/item/weapon/photo/selection = camera.selectpicture()
			if (!selection)
				return

			var/obj/item/weapon/photo/p = photocopy(selection)
			if (p.desc == "")
				p.desc += "Copied by [tempAI.name]"
			else
				p.desc += " - Copied by [tempAI.name]"
			toner -= 5
			sleep(15)
		updateUsrDialog()

/obj/machinery/photocopier/attackby(obj/item/O as obj, mob/user as mob)
	if (istype(O, /obj/item/weapon/screwdriver))
		if (!opened)
			opened = 1
			user << "You open the maintenance hatch of [src]."
		else
			opened = 0
			user << "You close the maintenance hatch of [src]."
		return
	if (opened)
		if(istype(O, /obj/item/weapon/crowbar))
			playsound(src.loc, 'sound/items/Crowbar.ogg', 50, 1)
			var/obj/machinery/constructable_frame/machine_frame/M = new /obj/machinery/constructable_frame/machine_frame(src.loc)
			M.state = 2
			M.icon_state = "box_1"
			for(var/obj/I in component_parts)
				if(I.reliability != 100 && crit_fail)
					I.crit_fail = 1
				I.loc = src.loc
			for(var/obj/item/I in contents)
				I.loc = src.loc
			qdel(src)
			return 1
		else
			user << "<span class='alert'>You can't load the [src.name] while its panel is opened.</span>"
			return 1

	if(istype(O, /obj/item/weapon/paper) || istype(O, /obj/item/weapon/photo) || istype(O, /obj/item/weapon/paper_bundle))
		if(!copyitem)
			user.drop_item()
			copyitem = O
			O.loc = src
			user << "<span class='notice'>You insert \the [O] into \the [src].</span>"
			flick(insert_anim, src)
			updateUsrDialog()
		else
			user << "<span class='notice'>There is already something in \the [src].</span>"
	else if(istype(O, /obj/item/device/toner))
		if(toner <= 10) //allow replacing when low toner is affecting the print darkness
			user.drop_item()
			user << "<span class='notice'>You insert the toner cartridge into \the [src].</span>"
			var/obj/item/device/toner/T = O
			toner += T.toner_amount
			qdel(O)
			updateUsrDialog()
		else
			user << "<span class='notice'>This cartridge is not yet ready for replacement! Use up the rest of the toner.</span>"
	else if(istype(O, /obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, 1)
		anchored = !anchored
		user << "<span class='notice'>You [anchored ? "wrench" : "unwrench"] \the [src].</span>"
	return

/obj/machinery/photocopier/ex_act(severity)
	switch(severity)
		if(1.0)
			qdel(src)
		if(2.0)
			if(prob(50))
				qdel(src)
			else
				if(toner > 0)
					new /obj/effect/decal/cleanable/blood/oil(get_turf(src))
					toner = 0
		else
			if(prob(50))
				if(toner > 0)
					new /obj/effect/decal/cleanable/blood/oil(get_turf(src))
					toner = 0
	return

/obj/machinery/photocopier/blob_act()
	if(prob(50))
		qdel(src)
	else
		if(toner > 0)
			new /obj/effect/decal/cleanable/blood/oil(get_turf(src))
			toner = 0
	return

/obj/machinery/photocopier/proc/copy(var/obj/item/weapon/paper/copy)
	var/obj/item/weapon/paper/c = new /obj/item/weapon/paper (loc)
	if(toner > 10)	//lots of toner, make it dark
		c.info = "<font color = #101010>"
	else			//no toner? shitty copies for you!
		c.info = "<font color = #808080>"
	var/copied = html_decode(copy.info)
	copied = replacetext(copied, "<font face=\"[c.deffont]\" color=", "<font face=\"[c.deffont]\" nocolor=")	//state of the art techniques in action
	copied = replacetext(copied, "<font face=\"[c.crayonfont]\" color=", "<font face=\"[c.crayonfont]\" nocolor=")	//This basically just breaks the existing color tag, which we need to do because the innermost tag takes priority.
	c.info += copied
	c.info += "</font>"
	c.name = copy.name // -- Doohl
	c.fields = copy.fields
	c.stamps = copy.stamps
	c.stamped = copy.stamped
	c.ico = copy.ico
	c.offset_x = copy.offset_x
	c.offset_y = copy.offset_y
	var/list/temp_overlays = copy.overlays       //Iterates through stamps
	var/image/img                                //and puts a matching

	if( copy.ico && copy.ico.len )
		for (var/j = 1, j <= temp_overlays.len, j++) //gray overlay onto the copy
			if (findtext(copy.ico[j], "cap") || findtext(copy.ico[j], "cent"))
				img = image('icons/obj/bureaucracy.dmi', "paper_stamp-circle")
			else if (findtext(copy.ico[j], "deny"))
				img = image('icons/obj/bureaucracy.dmi', "paper_stamp-x")
			else
				img = image('icons/obj/bureaucracy.dmi', "paper_stamp-dots")
			img.pixel_x = copy.offset_x[j]
			img.pixel_y = copy.offset_y[j]
			c.overlays += img

	c.updateinfolinks()
	toner--
	if(toner == 0)
		visible_message("<span class='notice'>A red light on \the [src] flashes, indicating that it is out of toner.</span>")
	return c


/obj/machinery/photocopier/proc/photocopy(var/obj/item/weapon/photo/photocopy)
	var/obj/item/weapon/photo/p = photocopy.copy()
	p.loc = src.loc

	var/icon/I = icon(photocopy.icon, photocopy.icon_state)
	if(toner > 10)	//plenty of toner, go straight greyscale
		I.MapColors(rgb(77,77,77), rgb(150,150,150), rgb(28,28,28), rgb(0,0,0))		//I'm not sure how expensive this is, but given the many limitations of photocopying, it shouldn't be an issue.
		p.img.MapColors(rgb(77,77,77), rgb(150,150,150), rgb(28,28,28), rgb(0,0,0))
		p.tiny.MapColors(rgb(77,77,77), rgb(150,150,150), rgb(28,28,28), rgb(0,0,0))
	else			//not much toner left, lighten the photo
		I.MapColors(rgb(77,77,77), rgb(150,150,150), rgb(28,28,28), rgb(100,100,100))
		p.img.MapColors(rgb(77,77,77), rgb(150,150,150), rgb(28,28,28), rgb(100,100,100))
		p.tiny.MapColors(rgb(77,77,77), rgb(150,150,150), rgb(28,28,28), rgb(100,100,100))
	p.icon = I
	toner -= 5	//photos use a lot of ink!
	if(toner < 0)
		toner = 0
		visible_message("<span class='notice'>A red light on \the [src] flashes, indicating that it is out of toner.</span>")

	return p

//If need_toner is 0, the copies will still be lightened when low on toner, however it will not be prevented from printing. TODO: Implement print queues for fax machines and get rid of need_toner
/obj/machinery/photocopier/proc/bundlecopy(var/obj/item/weapon/paper_bundle/bundle, var/need_toner=1)
	var/obj/item/weapon/paper_bundle/p = new /obj/item/weapon/paper_bundle (src)
	for(var/obj/item/weapon/W in bundle)
		if(toner <= 0 && need_toner)
			toner = 0
			visible_message("<span class='notice'>A red light on \the [src] flashes, indicating that it is out of toner.</span>")
			break

		if(istype(W, /obj/item/weapon/paper))
			W = copy(W)
		else if(istype(W, /obj/item/weapon/photo))
			W = photocopy(W)
		W.loc = p
		p.amount++
	//p.amount--
	p.loc = src.loc
	p.update_icon()
	p.icon_state = "paper_words"
	p.name = bundle.name
	p.pixel_y = rand(-8, 8)
	p.pixel_x = rand(-9, 9)
	return p

/obj/item/device/toner
	name = "toner cartridge"
	icon_state = "tonercartridge"
	var/toner_amount = 30
