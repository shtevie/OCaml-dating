(** Functions for user authentication and handling sessions *)

open Tables
open Opium

(** [new_session user_id] is a new session for the given user with id
    [user_id]. Requires that [user_id] is valid. *)
val new_session : id -> session obj Lwt.t

(** [user_of_sessid sessid] is [Some x] where [x] is the user associated
    with the session with session id [sessid] or [None] if [sessid] is
    invalid. *)
val user_of_sessid : string -> user obj option Lwt.t

(** [require_auth handler] is [handler] but returns an [`Unauthorized]
    response if the request is not linked to a valid session. *)
val require_auth :
  (user obj -> Request.t -> Response.t Lwt.t) ->
  Request.t ->
  Response.t Lwt.t

(** [user_of_request r] -> is [Some x] where [x] is the user associated with
    the session id of [r] if any or [None] if [r] is unauthenticated or the
    session is invalid. *)
val user_of_request : Request.t -> user obj option Lwt.t

(** [add_auth_headers res s] is [res] with the headers that attach
    authentication headers associated with [session]. *)
val add_auth_headers : session -> Response.t -> Response.t

(** [login user_id res] creates a new session for user with id [user_id] and
    attaches it to [res]. *)
val login : id -> Response.t -> (session obj * Response.t) Lwt.t
