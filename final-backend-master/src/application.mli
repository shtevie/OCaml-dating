(** Main application module that runs the backend server *)

open Opium

(** [app] is the application with all of the endpoints for interacting with
    the backend *)
val app : App.t

(** [init] starts the server and the matching loop *)
val init : unit -> unit Lwt.t

(** [update_chatlog chat_id user_id msg] adds a message to the chatlog
    contained by the chat with id [chat_id]. *)
val update_chatlog : Tables.id -> Tables.id -> string -> unit Lwt.t
