(** Helper functions for handling json responses for a request *)

open Yojson.Safe
open Opium

(** [error_json msg] is the json object of an error message [msg] *)
val error_json : string -> t

(** [message_json] is the json object of a message [msg] *)
val message_json : string -> t

(** [error_response ?status msg] is a response with error status [?status]
    and error json holding message [msg] *)
val error_response : ?status:Httpaf.Status.t -> string -> Response.t

(** [success_response msg] is a response with a message json holding message
    [msg]*)
val success_response : string -> Response.t

(** [with_params req f] is [f r] where [r] is t he body of [req] or an
    appropriate error response if [req] does not have a body or if any
    exceptions are raised during parsing or otherwise. *)
val with_params : Request.t -> (t -> Response.t Lwt.t) -> Response.t Lwt.t
