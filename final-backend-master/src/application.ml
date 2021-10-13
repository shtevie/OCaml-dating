module Auth' = Auth
open Opium
module Auth = Auth'
open Yojson.Safe.Util
open Lwt.Syntax
open Tables
open Opium_util
open Mserver
open Lwt
open Matcher

(** [signin_handler] is the user signin endpoint. *)
let signin_handler req =
  with_params req (fun r ->
      (* extract parameters *)
      let username = r |> member "username" |> to_string in
      let password = r |> member "password" |> to_string in
      let* o = Db.find_one_s users "username" username in
      match
        (* [None] if user doesn't exist, and [Some false] if passwords don't
           match. [Some true] if they do.*)
        Option.map
          (fun (u : Tables.user Tables.obj) -> (u, u.o.password = password))
          o
      with
      | Some (u, true) ->
          let r = success_response "signin success" in
          let+ _, r = Auth.login u.id r in
          r
      | None | Some (_, false) ->
          error_response "incorrect username or password" |> Lwt.return)

(** [special_char_list] is a list of special chars. *)
let special_char_list =
  [
    '!';
    '#';
    '$';
    '%';
    '&';
    '(';
    ')';
    '*';
    '+';
    '-';
    '.';
    '/';
    ':';
    ';';
    '<';
    '=';
    '>';
    '?';
    '@';
    '[';
    '\\';
    ']';
    '^';
    '_';
    '`';
    '{';
    '|';
    '\'';
    '\"';
    '}';
    '~';
  ]

(** [is_password_valid pass] is true if [pass] follows some security
    specifications. *)
let is_password_valid pass =
  let check_whitespace = Str.split (Str.regexp "[ \n\r\x0c\t]+") pass in
  if List.length check_whitespace <> 1 || List.hd check_whitespace <> pass
  then false
  else
    let has_upper = ref false in
    let has_special = ref false in
    let len = String.length pass >= 8 in
    for i = 0 to String.length pass - 1 do
      if List.mem pass.[i] special_char_list then has_special := true;
      if Char.code pass.[i] >= 65 && Char.code pass.[i] <= 90 then
        has_upper := true
    done;
    if !has_special && !has_upper && len then true else false

(** [create_user_handler] is the confirmation that a user is created and is
    then directed to the user's profile page*)
let create_user_handler req =
  with_params req (fun r ->
      (* get fields *)
      let username = r |> member "username" |> to_string in
      let name = r |> member "name" |> to_string in
      let password = r |> member "password" |> to_string in
      (* check if username is already exists *)
      let* u = Db.find_one_s users "username" username in
      match u with
      | Some _ -> error_response "username taken" |> Lwt.return
      | None ->
          (*check if password is well-formed*)
          if is_password_valid password then
            (* create user *)
            let* u = Db.create users { username; name; password } in
            let r = success_response "user created" in
            let+ _, r = Auth.login u.id r in
            r
          else error_response "invalid password" |> Lwt.return)

(** [get_current_user_handler req] is an authentication required handler
    that returns the user whose session is associated with the [req]. *)
let get_current_user_handler =
  Auth.require_auth (fun user _ ->
      let+ rating = Rating.average_rating user.id in
      Response.of_json
        (`Assoc
          [
            ("name", `String user.o.name);
            ("username", `String user.o.username);
            ("rating", `Float rating);
          ]))

(** [new_match] is whether a new survey should be generated *)
let new_match = ref false

(** [current_survey] is a ref that stores the current survey served out to
    potential matches *)
let current_survey = ref (Survey.new_survey ())

(** [toggle_survey] provies a new survey for after a match has been made *)
let toggle_survey () = current_survey := Survey.new_survey ()

(** [json_map x] is [x] in json format. *)
let json_map (x : question) =
  `Assoc
    [
      ("text", `String x.text);
      ( "choices",
        `List
          (List.map
             (fun (y : choice) -> `Assoc [ ("text", `String y.text) ])
             x.choices) );
    ]

(** [get_survey_handler] resolves to the JSON object of a survey. *)
let get_survey_handler =
  Auth.require_auth (fun _ _ ->
      let* surv =
        if !new_match = true then (
          toggle_survey ();
          new_match := false;
          !current_survey)
        else !current_survey
      in
      let json_lst = List.map json_map surv.questions in
      Response.of_json (`Assoc [ ("questions", `List json_lst) ])
      |> Lwt.return)

(** [active_user_cond] is notified whenever an active user is created with
    [add_active_user]. *)
let active_user_cond : id Lwt_condition.t = Lwt_condition.create ()

(** [add_active_user user_id] creates an active user with [user_id] and
    broadcasts [user_id] to [active_user_cond]. *)
let add_active_user user_id =
  let* a = Db.find_one_i active_users "user_id" user_id in
  (if a = None then Db.create active_users { user_id } >|= fun _ -> ()
  else Lwt.return_unit)
  >|= fun _ -> Lwt_condition.broadcast active_user_cond user_id

(** [match_cond] is notified when a match is found by [matching_loop]. *)
let match_cond = Lwt_condition.create ()

(** [remove_active_user user_id] removes the active user with [user_id]. *)
let remove_active_user user_id =
  let* active1 = Db.find_one_i active_users "user_id" user_id in
  let active1 = Option.get active1 in
  Db.delete active_users active1.id

(** [remove_active_users chat] deletes the two active users in [chat]. *)
let remove_active_users chat =
  let* u1 = Db.get users chat.o.user_one in
  let* u2 = Db.get users chat.o.user_two in
  let* () = remove_active_user u1.id in
  let+ () = remove_active_user u2.id in
  (u1, u2)

(** [matching_loop] waits until there are two active users and then tries to
    match the latest one. If successful, the two matched active users are
    removed and [match_cond] is broadcasted.*)
let rec matching_loop () =
  let* u1_id = Lwt_condition.wait active_user_cond in
  let* active_users_cnt = Db.cnt active_users in
  if active_users_cnt >= 2 then (
    Logs.info (fun m -> m "start matching with user %d" u1_id);
    let* summary = Matcher.match_summary u1_id in
    (match summary with
    | Some summary ->
        (* remove users from active users *)
        let* chat = Db.get chats summary.o.chat_id in
        let+ u1, u2 = remove_active_users chat in
        (* print usernames *)
        Logs.info (fun m -> m "matched %s %s" u1.o.username u2.o.username);
        Lwt_condition.broadcast match_cond ();
        new_match := true
    | None -> Lwt.return_unit)
    >>= fun () -> matching_loop ())
  else matching_loop ()

(** [submit_survey_handler] handles logging survey information into the
    database *)
let submit_survey_handler =
  Auth.require_auth (fun u req ->
      with_params req (fun r ->
          (* get fields *)
          let username = u.o.username in
          let questions = r |> member "questions" |> to_list in
          Lwt_list.iter_s
            (fun q ->
              let question_text =
                q |> member "question_text" |> to_string
              in
              let choice_id = q |> member "choice_id" |> to_int in
              (* create response *)
              let* _ =
                Db.create responses { username; question_text; choice_id }
              in
              Lwt.return_unit)
            questions
          >>= fun () ->
          let r = success_response "response recorded" in
          add_active_user u.id >>= fun () -> Lwt.return r))

(** [get_match_summary_details] retrieves the information about a given
    match *)
let get_match_summary_details =
  Auth.require_auth (fun u _ ->
      let* chat = find_chat u.id in
      match chat with
      | None -> Lwt.return (error_response "summary generation failed")
      | Some c ->
          let* summary = Db.find_one_i match_summaries "chat_id" c.id in
          let sum = Option.get summary in
          let+ details = match_details sum.o in
          Response.of_json (`Assoc [ ("details", `String details) ]))

(** [create_active_user_handler] handles creating a new active users table
    with the a new active user *)
let create_active_user_handler req =
  with_params req (fun r ->
      (* get fields *)
      let user_id = r |> member "user_id" |> to_int in
      (* create new active user *)
      let+ _ = Db.create active_users { user_id } in
      let r = success_response "active user added" in
      r)

(** [user_rating_handler] handles rating a user *)
let user_rating_handler =
  Auth.require_auth (fun user req ->
      with_params req (fun r ->
          let rating_value = r |> member "rating" |> to_int in
          Rating.rate user.id rating_value))

(** [delete_active_user_handler] handles deleting an inactive user from the
    active users table *)
let delete_active_user_handler req =
  with_params req (fun r ->
      (* get fields *)
      let user_id = r |> member "user_id" |> to_int in
      (* delete inactive user *)
      let* usr = Db.get users user_id in
      let* inactive_user = Db.find_one_i active_users "user_id" usr.id in
      match inactive_user with
      | None -> Lwt.return (error_response "user does not exist")
      | Some obj ->
          let+ _ = Db.delete active_users obj.id in
          let r = success_response "inactive user deleted" in
          r)

(** [get_chats_handler] handles sending a json response of the list of chats *)
let get_chats_handler =
  Auth.require_auth (fun user_obj _ ->
      let user_id = user_obj.id in
      Db.find_i chats "user_one" user_id >>= fun u1 ->
      Db.find_i chats "user_two" user_id >>= fun u2 ->
      let json_lst1 =
        List.map
          (fun (x : chat obj) -> `Assoc [ ("text", `Int x.o.user_two) ])
          u1
      in
      let json_lst2 =
        List.map
          (fun (x : chat obj) -> `Assoc [ ("text", `Int x.o.user_one) ])
          u2
      in
      let matched_chats = json_lst1 @ json_lst2 in
      Response.of_json (`Assoc [ ("chats", `List matched_chats) ])
      |> Lwt.return)

(** [sockaddr] is the address used for [Mserver]. *)
let sockaddr = Unix.ADDR_INET (Unix.inet_addr_loopback, 12345)

(** [socks] maps user ids to sockets, if they are connected. *)
let socks : (id, Mserver.msocket) Hashtbl.t = Hashtbl.create 128

let update_chatlog chat_id user_id msg =
  (* retrieve chatlog *)
  let* chatlog = Db.find_one_i chatlogs "chat_id" chat_id in
  let chatlog = Option.get chatlog in

  (* store message *)
  let msg_obj : message = { user_id; content = msg } in
  let new_list = msg_obj :: chatlog.o.messages in
  let new_chatlog_obj : chatlog = { chatlog.o with messages = new_list } in
  Db.update chatlogs chatlog.id new_chatlog_obj

(** [get_match_state_handler] handles sending the state of a match *)
let get_match_state_handler =
  Auth.require_auth (fun u _ ->
      let+ st = match_state u.id in
      let msg =
        match st with
        | Matching -> "matching"
        | Matched _ -> "success"
        | Inactive -> "failed"
      in
      success_response msg)

(** [max_rating_time] is the timeout for rating; that is, after a chat ends,
    users have a [max_rating_time] to rate each other. *)
let max_rating_time = 15. *. 60.
(* 15 minutes *)

let print_exc ?(header = "") exc =
  Logs.err (fun m -> m "%s%s" header (Printexc.to_string exc))

(** [end_chat chat user_id other_id] ends the given [chat] and starts
    waiting ratings. *)
let end_chat chat user_id other_id =
  Db.update chats chat.id { chat.o with active = false } >>= fun () ->
  (* close the other chat *)
  (Hashtbl.find socks other_id).close ();
  Rating.cancel_existing_ratings user_id >>= fun () ->
  let+ r1, r2 = Rating.create_ratings chat.id user_id other_id in
  Lwt.dont_wait
    (fun () ->
      (* first sleep *)
      Lwt_unix.sleep max_rating_time >>= fun () ->
      (* then cancel rating *)
      let* () = Rating.cancel_rating r1 in
      Rating.cancel_rating r2)
    print_exc

(** [read_message msock user_id other_id chat_id] reads a message sent from
    [user_id] from [msock], sends it to the socket under user [other_id],
    and logs it in the database in the chatlog contained by [chat_id]. *)
let read_message msock user_id other_id chat_id =
  (* read next message *)
  let* msg = msock.read () in

  (* relay message to other user *)
  (Hashtbl.find socks other_id).write msg;

  let msg = msg |> member "message" |> to_string in
  update_chatlog user_id chat_id msg

(** [start_chat msock user_id chat] continuously reads messages from
    [user_id] from [chat] with [msock]. *)
let start_chat msock user_id chat =
  let other_id =
    if chat.o.user_one = user_id then chat.o.user_two else chat.o.user_one
  in
  let rec read_loop () =
    Lwt.catch
      (fun () ->
        let* () = read_message msock user_id other_id chat.id in
        (* read again *)
        read_loop ())
      (function
        | Lwt_stream.Empty ->
            (* stream was closed, end chat *)
            end_chat chat user_id other_id
        | exc -> Lwt.fail exc)
  in
  read_loop ()

(** [wait_until_not_matching user_id] resolves only when
    [match_state user_id] is not [Matching]. *)
let rec wait_until_not_matching user_id =
  let* st = match_state user_id in
  if st <> Matching then Lwt.return st
  else
    Lwt_condition.wait match_cond >>= fun () ->
    wait_until_not_matching user_id

(** [matching msock user_id] is called when [match_state user_id] is
    [Matching] and uses [msock] to complete the chatting protocol. *)
let matching msock user_id =
  let write_event event_name =
    msock.write (`Assoc [ ("event", `String event_name) ])
  in
  wait_until_not_matching user_id >|= function
  | Matched _ -> write_event "matched"
  | Inactive -> write_event "failed"
  | Matching -> failwith "Impossible"

(** [mserver_handler msock] handles the chatting protocols. *)
let mserver_handler msock =
  let user_id = msock.user_id in
  Logs.info (fun m -> m "user connected: %d" user_id);
  (* add to stored socks *)
  Hashtbl.add socks user_id msock;

  let* st = match_state user_id in
  match st with
  | Inactive -> Lwt.return_unit
  | Matched c -> start_chat msock user_id c (* start chat if matched *)
  | Matching -> matching msock user_id

(** [auth sessid] is [Some id] of the user attached to the session with
    [sessid], or [None] if [sessid] is invalid. *)
let auth sessid =
  let+ u = Auth.user_of_sessid sessid in
  Option.map (fun u -> u.id) u

(** [init_mserver] starts the [Mserver]. *)
let init_mserver () = Mserver.start sockaddr auth mserver_handler

let init () =
  init_mserver () >|= fun () ->
  Lwt.dont_wait matching_loop (fun exn ->
      Logs.err (fun m -> m "MATCHING LOOP: %s" (Printexc.to_string exn)))

let app =
  App.empty
  |> App.middleware Opium.Middleware.logger
  |> App.middleware
       (Opium.Middleware.allow_cors ~origins:[ "http://localhost:3006" ] ())
  (* routes *)
  |> App.post "/users/create" create_user_handler
  |> App.post "/users/signin" signin_handler
  |> App.get "/user" get_current_user_handler
  |> App.get "/survey" get_survey_handler
  |> App.post "/survey/submit" submit_survey_handler
  |> App.post "/rating" user_rating_handler
  |> App.post "/active-users/add" create_active_user_handler
  |> App.delete "/active-users/delete" delete_active_user_handler
  |> App.get "/matching/state" get_match_state_handler
  |> App.get "/user/chats" get_chats_handler
  |> App.get "/matching/details" get_match_summary_details
