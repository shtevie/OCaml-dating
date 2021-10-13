open Tables
open Lwt.Syntax

let sessid_bytes = 24

(* Initialize PRNG. *)
let _ = Mirage_crypto_rng_lwt.initialize ()

let gen_sessid () =
  Mirage_crypto_rng.generate sessid_bytes
  |> Cstruct.to_string |> Base64.encode_exn

let new_session user =
  let session : session = { user_id = user; sessid = gen_sessid () } in
  Db.create sessions session

let user_of_sessid sessid =
  let* o = Db.find_one_s sessions "sessid" sessid in
  match o with
  | None -> Lwt.return_none
  | Some s ->
      let+ u = Db.get users s.o.user_id in
      Some u

let sessid_cookie_name = "sessid"

let user_of_request req =
  match Opium.Request.cookie sessid_cookie_name req with
  | None -> Lwt.return_none
  | Some sessid -> user_of_sessid sessid

let add_auth_headers session res =
  Opium.(
    let cookie =
      Cookie.make ~scope:(Uri.of_string "/")
        (sessid_cookie_name, session.sessid)
      |> Cookie.to_set_cookie_header
    in
    Response.add_header cookie res)

let login user res =
  let+ s = new_session user in
  (s, add_auth_headers s.o res)

let require_auth handler req =
  Opium.(
    let* u = user_of_request req in
    match u with
    | None ->
        Response.of_json
          (`Assoc [ ("error", `String "not logged in or invalid session") ])
          ~status:`Unauthorized
        |> Lwt.return
    | Some u -> handler u req)
