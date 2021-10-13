(** Database functions for interacting with the database and its tables *)

open Tables

(** [init] initializes the database, adding tables if not done already. *)
val init : unit -> unit Lwt.t

(** [reset] resets the database to its initial state (that is, the one after
    [init ()]). *)
val reset : unit -> unit Lwt.t

(* BASIC QUERY/UPDATE *)

(** [all tab] is a list of all objects stored in the table [tab]. *)
val all : 'a table -> 'a obj list Lwt.t

(** [create tab a] stores [a] into the database at table [tab] and returns
    the newly created object. *)
val create : 'a table -> 'a -> 'a obj Lwt.t

(** [delete tab id] deletes the entry of [id] in the table [tab]. *)
val delete : 'a table -> id -> unit Lwt.t

(** [delete_all tab] deletes all objects from the table [tab]. *)
val delete_all : 'a table -> unit Lwt.t

(** [get tab id] is the object stored in the table [tab] at [id]. Raises
    [Not_found] if [id] is invalid. *)
val get : 'a table -> id -> 'a obj Lwt.t

(** [get_opt tab id] is [Some x] where x is the object stored in the
    database table [tab] at [id] or [None] if [id] is invalid. *)
val get_opt : 'a table -> id -> 'a obj option Lwt.t

(** [cnt tab] is the number of objects stored in [tab]. *)
val cnt : 'a table -> int Lwt.t

(** [update tab id a] updates the object stored at the table [tab] with [id]
    with the fields of [a]. *)
val update : 'a table -> id -> 'a -> unit Lwt.t

(** [find tab field v json_to_b] is a list where each element [x] is an
    object stored in the table [tab] with [v] stored at [field]. The
    comparison uses [=] with [json_to_v] applied on the actual stored json
    value and [v]. Requires that [field] is valid. *)
val find :
  'a table -> string -> 'b -> (Json_util.t -> 'b) -> 'a obj list Lwt.t

(** [find_one tab field v json_to_v] is [Some x] where [x] is an object
    stored in the table [tab] with [v] stored at [field]. See [find] for
    details on comparison. Requires that [field] is valid. *)
val find_one :
  'a table -> string -> 'b -> (Json_util.t -> 'b) -> 'a obj option Lwt.t

(** Like [find] but with string fields. *)
val find_s : 'a table -> string -> string -> 'a obj list Lwt.t

(** Like [find_one] but with string fields. *)
val find_one_s : 'a table -> string -> string -> 'a obj option Lwt.t

(** Like [find] but with int fileds. *)
val find_i : 'a table -> string -> int -> 'a obj list Lwt.t

(** Like [find_one] but with int fields. *)
val find_one_i : 'a table -> string -> int -> 'a obj option Lwt.t
