type t = Irmin.Contents.json

let to_string = function
  | `String (s : string) -> s
  | _ -> invalid_arg "expected string"

(** [assoc name obj] is the value at key [name] of json object [obj]*)
let assoc name obj = try List.assoc name obj with Not_found -> `Null

let to_assoc = function `O obj -> obj | _ -> invalid_arg "Expected object"

let member name = function
  | `O obj -> assoc name obj
  | _ -> invalid_arg "Can't get member of non-object type"

let to_bool = function `Bool x -> x | _ -> invalid_arg "expected `Bool"

let to_int = function
  | `Float f -> int_of_float f
  | _ -> invalid_arg "expected `Float"

let to_list = function `A l -> l | _ -> invalid_arg "Expected `A"

let to_opt f = function `Null -> None | o -> Some (f o)
