open Lwt.Syntax
open Lwt
open Json_util
open Tables

let info = Irmin_unix.info

(** Irmin data store type. *)
module S = Irmin_unix.Git.FS.KV (Irmin.Contents.Json_value)

(** Json_tree of [S] for easier access. *)
module T = Irmin.Json_tree (S)

let dev_db = "./_db/"

let test_db = "./_test_db/"

(* [config] sets different location for the database based on environment
   variable. *)
let config =
  let testing =
    Sys.getenv_opt "ENV" |> function Some "test" -> true | _ -> false
  in
  let location = if testing then test_db else dev_db in
  Irmin_git.config location ~bare:true

(** The actual database object. *)
let t = Lwt_main.run (S.Repo.v config >>= S.master)

(** [init_table t table] creates [table] in tree [t] *)
let init_table t table =
  let tab =
    `O [ ("next_id", `Float 0.); ("cnt", `Float 0.); ("objs", `O []) ]
  in
  T.set_tree t [ table.name ] tab

(** [init_tables] initializes all the tables in the database *)
let init_tables t =
  S.get_tree t [] >>= fun tr ->
  let* tr = init_table tr users in
  let* tr = init_table tr sessions in
  let* tr = init_table tr questions in
  let* tr = init_table tr responses in
  let* tr = init_table tr active_users in
  let* tr = init_table tr chats in
  let* tr = init_table tr chatlogs in
  let* tr = init_table tr match_summaries in
  let* tr = init_table tr ratings in
  let* tr = init_table tr user_ratings in
  S.set_tree_exn t [] tr ~info:(info "init tables")

(** [tree_find t path] is the json value of [t] at [path] in an option or
    None of it does not exist *)
let tree_find t path =
  catch
    (fun () ->
      let+ x = T.get t path in
      Some x)
    (fun _ -> return None)

let init () =
  tree_find t [ "initialized" ] >>= function
  | Some (`Bool false) | None ->
      init_tables t >>= fun () ->
      T.set t [ "initialized" ] (`Bool true) ~info:(info "finish init")
  | _ -> return_unit

let reset () =
  let* commit =
    S.last_modified t [ "initialized" ] >|= fun l -> List.hd l
  in
  S.Head.set t commit

(** [inc_dec] increments or decrements values at [path] in a tree [t] *)
let inc_dec t path inc =
  T.get_tree t path >>= fun x ->
  let x = if inc then to_int x + 1 else to_int x - 1 in
  T.set_tree t path (`Float (float_of_int x))

(** [obj_of_a id a] is the object with id [id] and contents [a] *)
let obj_of_a id a = { id; o = a }

(** [json_of_obj tab o] is the json object of the object [o] in [table]*)
let json_of_obj tab o : t = `O [ ("o", tab.json_of_a o.o) ]

(** [obj_of_json] is the object of json [j] with [id] in [tab] *)
let obj_of_json tab id j = { id; o = member "o" j |> tab.a_of_json }

(** [objs_list table] is the list of objects in [table]*)
let objs_list table = T.get t [ table.name; "objs" ] >|= fun o -> to_assoc o

let all table =
  let+ l = objs_list table in
  List.map (fun (id, x) -> obj_of_json table (int_of_string id) x) l

let cnt table =
  T.get t [ table.name; "cnt" ] >>= fun x -> to_int x |> return

let create table a =
  let* tr = S.get_tree t [ table.name ] in
  (* get the id to store the object *)
  let* i = T.get_tree tr [ "next_id" ] in
  let id = to_int i in
  (* create the json and store the obj ect *)
  let obj = obj_of_a id a in
  let json = json_of_obj table obj in
  let* tr = T.set_tree tr [ "objs"; string_of_int id ] json in
  (* increment count and next_id *)
  let* tr = inc_dec tr [ "next_id" ] true in
  let* tr = inc_dec tr [ "cnt" ] true in
  let info = Irmin_unix.info "create obj in %s with id=%d" table.name id in
  let+ () = S.set_tree_exn t [ table.name ] tr ~info in
  obj

let delete table id =
  let* tr = S.get_tree t [ table.name ] in
  let* tr = S.Tree.remove tr [ "objs"; string_of_int id ] in
  (* check whether objs was removed *)
  let* objs = S.Tree.find_tree tr [ "objs" ] in
  let* tr =
    match objs with
    | None -> T.set_tree tr [ "objs" ] (`O [])
    | Some _ -> Lwt.return tr
  in
  let* tr = inc_dec tr [ "cnt" ] false in
  S.set_tree_exn t [ table.name ] tr
    ~info:(info "remove %d from %s" id table.name)

let delete_all table =
  let* tr = S.get_tree t [ table.name ] in
  let* tr = T.set_tree tr [ "objs" ] (`O []) in
  let* tr = T.set_tree tr [ "cnt" ] (`Float 0.) in
  S.set_tree_exn t [ table.name ] tr ~info:(info "delete all %s" table.name)

let get_opt table id =
  let+ o = tree_find t [ table.name; "objs"; string_of_int id ] in
  Option.map (obj_of_json table id) o

let get table id =
  let+ o = get_opt table id in
  match o with None -> raise Not_found | Some v -> v

let update table id a =
  let j = table.json_of_a a in
  T.set t
    [ table.name; "objs"; string_of_int id; "o" ]
    j
    ~info:(info "update object %d in %s" id table.name)

(** [check_field field json_to_v v (_, obj)] is true when the [json_to_v x]
    where [x] is the [field] of [obj] is equal to [v], false otherwise. *)
let check_field field json_to_v v (_, obj) =
  member "o" obj |> member field |> json_to_v |> ( = ) v

let find table field v json_to_v =
  let+ assoc_lst = objs_list table in
  List.filter (check_field field json_to_v v) assoc_lst
  |> List.map (fun (id, x) -> obj_of_json table (int_of_string id) x)

let find_one table field v json_to_v =
  let+ l = find table field v json_to_v in
  match l with [] -> None | h :: _ -> Some h

let find_s t f v = find t f v to_string

let find_one_s t f v = find_one t f v to_string

let find_i t f v = find t f v to_int

let find_one_i t f v = find_one t f v to_int
