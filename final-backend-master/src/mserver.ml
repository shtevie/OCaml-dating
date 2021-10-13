open Lwt.Syntax
open Lwt
open Lwt_io

type msg_body =
  | Auth of string
  | Data of Yojson.Safe.t

type msocket = {
  user_id : Tables.id;
  write : Yojson.Safe.t -> unit;
  read : unit -> Yojson.Safe.t Lwt.t;
  close : unit -> unit;
}

type handler = msocket -> unit Lwt.t

exception Invalid_message_format

(** [read_bytes ic buf n] is the string representation of [n] number of
    bytes in [ic] with intermediate storage in [buf]. *)
let read_bytes ic buf n =
  Lwt_io.read_into_exactly ic buf 0 n >|= fun () -> Bytes.sub_string buf 0 n

let parse_auth ic buf =
  Logs.info (fun m -> m "auth message parsed");
  let+ sessid = read_bytes ic buf 32 in
  Auth sessid

let parse_data ic buf =
  Logs.info (fun m -> m "data message parsed");
  read_into_exactly ic buf 0 4 >>= fun () ->
  let len = Bytes.get_int32_be buf 0 |> Int32.to_int in
  read_into_exactly ic buf 0 len >|= fun () ->
  let body = Bytes.sub_string buf 0 len in
  Data (Yojson.Safe.from_string body)

let parse_msg ic =
  let buf = Bytes.create 1024 in
  read_into_exactly ic buf 0 1 >>= fun () ->
  let c = Bytes.get buf 0 |> Char.code in
  match c with
  | 0 -> parse_auth ic buf
  | 1 -> parse_data ic buf
  | x ->
      Logs.err (fun m -> m "invalid message format %d" x);
      raise Invalid_message_format |> return

(** [encode] is the string form of a message body type *)
let encode oc (msg : msg_body) =
  let set_type_byte ty = ty |> Char.chr |> Lwt_io.write_char oc in
  match msg with
  | Auth sessid ->
      let* () = set_type_byte 0 in
      Lwt_io.write_from_string_exactly oc sessid 0 (String.length sessid)
  | Data json ->
      set_type_byte 1 >>= fun () ->
      let str = Yojson.Safe.to_string json in
      let len = String.length str in
      let len_bytes = Bytes.create 4 in
      Bytes.set_int32_be len_bytes 0 (len |> Int32.of_int);
      Lwt_io.write_from_exactly oc len_bytes 0 4 >>= fun () ->
      Lwt_io.write_from_string_exactly oc str 0 len

let read ic =
  Lwt.catch
    (fun () ->
      let+ msg = parse_msg ic in
      Some msg)
    (function
      | Invalid_message_format ->
          Logs.err (fun m -> m "Invalid message format");
          Lwt.return_none
      | Channel_closed _ | End_of_file | _ ->
          Logs.err (fun m -> m "Connection ended");
          Lwt.return_none)

let handshake read =
  let* (msg : msg_body option) = read () in
  match msg with
  | Some (Auth sessid) -> return_some sessid
  | _ -> return_none

(** [try_handshake ic after_handshake] is [after_handshake sessid] where
    [sessid] is obtained by a successful handshake, otherwise unit. *)
let try_handshake ic after_handshake =
  let* sessid = handshake (fun () -> read ic) in
  match sessid with
  | Some sessid ->
      Logs.info (fun m -> m "handshake with sessid %s" sessid);
      after_handshake sessid
  | None ->
      Logs.info (fun m -> m "handshake failed");
      return_unit

(** [create_data_in_stream ic] is a stream that reads [Data] messages from
    [ic]. *)
let create_data_in_stream ic =
  let rec read_data () =
    let* m = read ic in
    match m with
    | Some (Data x) -> Some x |> return
    | None -> return None
    | _ -> read_data ()
  in
  Lwt_stream.from read_data

(** [try_auth auth sessid after_auth] is [after_auth id] where [id] is the
    result of a successful authentication of [sessid] with [auth], otherwise
    unit. *)
let try_auth auth sessid after_auth =
  let* auth = auth sessid in
  match auth with
  | Some id ->
      Logs.info (fun m -> m "sucessful handshake for user %d" id);
      after_auth id >|= fun _ ->
      Logs.info (fun m -> m "connection with user %d TERMINATED" id)
  | None ->
      Logs.info (fun m ->
          m "failed to authenticate sessid %s after handshake" sessid);
      return_unit

(** [print_exc_prom f] creates a promise that applies [f ()] and upon
    rejection logs the error and reraises it.*)
let print_exc_prom f =
  Lwt.catch f (fun exc ->
      Logs.err (fun m -> m "%s" (Printexc.to_string exc));
      Lwt.fail exc)

(** [make_msock] is an msock created with the given arguments. *)
let make_msock user_id in_stream out_fn close_cond =
  {
    user_id;
    write = (fun x -> Some (Data x) |> out_fn);
    read = (fun () -> Lwt_stream.next in_stream);
    close = (fun () -> Lwt_condition.broadcast close_cond ());
  }

(** [data_connect f user_id ic oc] creates an [msocket] [x] and applies
    [f x]. *)
let connect_handler f user_id ic oc =
  let in_stream = create_data_in_stream ic in
  let out_stream, out_fn = Lwt_stream.create () in

  let close_cond = Lwt_condition.create () in
  let res : msocket = make_msock user_id in_stream out_fn close_cond in
  Lwt.pick
    [
      Lwt.join
        [
          Lwt_stream.closed in_stream;
          print_exc_prom (fun () -> f res);
          Lwt_stream.iter_s (encode oc) out_stream;
        ];
      Lwt_condition.wait close_cond;
    ]

let start sockaddr auth f =
  establish_server_with_client_address sockaddr (fun _ (ic, oc) ->
      try_handshake ic (fun sessid ->
          try_auth auth sessid (fun id -> connect_handler f id ic oc)))
  >>= fun _ -> Lwt.return_unit
