(*
 * Copyright (C) Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)

(* Ensure domain 0 has a sensible uuid *)
let check_domain0_uuid () =
	let xc = Xenctrl.interface_open () in
	let uuid =
		try
			Inventory.lookup Inventory._control_domain_uuid
		with _ ->
			let uuid = Uuidm.(to_string (create `V4)) in
			Inventory.update Inventory._control_domain_uuid uuid;
			uuid in
	Xenctrl.domain_sethandle xc 0 uuid;
	(* make the minimum entries for dom0 *)
	let kvs = [
		"/local/domain/0/domid", "0";
		"/local/domain/0/vm", "/vm/" ^ uuid;
		"/local/domain/0/name", "Domain-0";
		Printf.sprintf "/vm/%s/uuid" uuid, uuid;
		Printf.sprintf "/vm/%s/name" uuid, "Domain-0";
		Printf.sprintf "/vm/%s/domains/0" uuid, "/local/domain/0";
		Printf.sprintf "/vm/%s/domains/0/create-time" uuid, "0"
	] in
	let open Xenstore in
	with_xs (fun xs ->
		List.iter (fun (k, v) -> xs.Xs.write k v) kvs
	);
	(* before daemonizing we need to forget the xenstore client
	   because the background thread will be gone after the fork() *)
	forget_client ()

let make_vnc_dir () =
	Xl_path.vnc_dir := Filename.concat (Xenops_utils.get_root ()) "vnc";
	Unixext.mkdir_rec !Xl_path.vnc_dir 0o0755

let make_var_run_xen () =
	Unixext.mkdir_rec "/var/run/xen" 0o0755

(* Start the program with the xenlight backend *)
let _ =
	Xenops_interface.queue_name := !Xenops_interface.queue_name ^ ".xenlight";
	Xenops_utils.set_root "xenopsd/xenlight";
	Xenopsd.configure
		~specific_essential_paths:Xl_path.essentials
		~specific_nonessential_paths:Xl_path.nonessentials
		();
	check_domain0_uuid ();
	make_vnc_dir ();
	make_var_run_xen ();
	Xenopsd.main
		(module Xenops_server_xenlight: Xenops_server_plugin.S)

