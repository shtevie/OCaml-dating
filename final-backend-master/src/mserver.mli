(** [Mserver] uses UNIX sockets to implement server-side MProtocol. *)

open Lwt_io

(** [msg_body] are the types of [messages] specified by the MProtocol. *)
type msg_body =
  | Auth of string
  | Data of Yojson.Safe.t

(** [msocket] represents a connection between mserver and a client. *)
type msocket = {
  user_id : Tables.id;
  write : Yojson.Safe.t -> unit;
      (** [write msg] pushes the message [msg] to the client. *)
  read : unit -> Yojson.Safe.t Lwt.t;
      (** [read] is the next message from the client. *)
  close : unit -> unit;
      (** [close] closes the connection to the client. Further calls to read
          or write will result in noops or stalls. *)
}

(** [Invalid_message_format] is raised when data received from a client
    connection is invalid. *)
exception Invalid_message_format

(** [parse_auth ic buf] is a [Auth] packet parsed from [ic] using [buf] as
    intermediate storage. Raises [End_of_file] if the channel closes or
    [Invalid_message_format] if the data is invalid. *)
val parse_auth : input_channel -> Bytes.t -> msg_body Lwt.t

(** [parse_data ic buf] is a [Data] packet parsed from [ic] using [buf] as
    intermediate storage. Raises [End_of_file] if the channel closes or
    [Invalid_message_format] if the data is invalid. *)
val parse_data : input_channel -> Bytes.t -> msg_body Lwt.t

(** [encode oc msg] encodes [msg] over [oc] according to the MProtocol. *)
val encode : output_channel -> msg_body -> unit Lwt.t

(** [read ic] is [Some x] where [x] is a message read from [ic], or [None]
    if [ic] closes or an incorrectly formatted message is read. *)
val read : input_channel -> msg_body option Lwt.t

(** [parse_msg ic] is the next message from [ic] or raises [Channel_closed]
    if the channel closes and [Invalid_message_format] if the data is
    invalid. *)
val parse_msg : input_channel -> msg_body Lwt.t

(** [hanshake read] is [Some s] where [s] is the sessid from a successful
    handshake using [read] to retrieve messages, or [None] otherwise. *)
val handshake : (unit -> msg_body option Lwt.t) -> string option Lwt.t

(** [handler] is the handler for new connections to the mserver. *)
type handler = msocket -> unit Lwt.t

(** [start sockaddr auth handler] listens for connections at [sockaddr].
    When a client connects and successfully handshakes so that [auth sessid]
    is true where [sessid] is from the opening handshake, [handler s] is
    evaluated where [s] represents the client connection. *)
val start :
  Unix.sockaddr ->
  (string -> Tables.id option Lwt.t) ->
  handler ->
  unit Lwt.t
