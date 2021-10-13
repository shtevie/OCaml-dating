module Auth' = Auth
open Opium
module Auth = Auth'
open Lwt.Infix

let error_json (msg : string) = `Assoc [ ("error", `String msg) ]

let message_json (msg : string) = `Assoc [ ("message", `String msg) ]

let error_response ?(status = `Bad_request) msg =
  Response.of_json (error_json msg) ~status

let success_response msg = Response.of_json (message_json msg)

let with_params req f =
  Request.to_json req >>= function
  | Some r -> (
      try f r with
      | Yojson.Safe.Util.Type_error (o, j) ->
          error_response (o ^ Yojson.Safe.pretty_to_string j) |> Lwt.return
      | e ->
          print_endline (Printexc.to_string e);
          error_response "bad request" ~status:`Internal_server_error
          |> Lwt.return)
  | None -> error_response "no body" |> Lwt.return
