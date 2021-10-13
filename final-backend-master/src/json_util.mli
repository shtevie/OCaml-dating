(** Utility functions for using Irmin json objects *)

(** the type of the json representation*)
type t = Irmin.Contents.json

(** [to_string j] is a string representing the json object [j] or fails if
    it is not a string json *)
val to_string : t -> string

(** [to_assoc obj] is association list representing json object [obj]*)
val to_assoc : t -> (string * t) list

(** [member name j] is the value at [name] of json object [j]*)
val member : string -> t -> t

(** [to_bool j] is the boolean representing the json object [j] or fials if
    it is not a boolean json *)
val to_bool : t -> bool

(** [to_int j] is the integer representing the json object [j] or fials if
    it is not a integer json *)
val to_int : t -> int

(** [to_list j] is the list representing the json object [j] or fials if it
    is not a list json *)
val to_list : t -> t list

(** [to_opt f j] applies [f] to json object [j] and wraps the result in an
    option. None results in when [j] has json type Null. *)
val to_opt : (t -> 'a) -> t -> 'a option
