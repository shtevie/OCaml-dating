open Tables
open Lwt.Syntax
open Lwt

type match_state =
  | Matching
  | Matched of chat obj
  | Inactive

(** [responses_by_user] represents all the responses of a given user *)
type responses_by_user = {
  response_user_id : id;
  response_lst : response obj list;
}

(** [aggregate_responses] is the list of all sets of responses for each user *)
let aggregate_responses () =
  let* user_lst = Db.all users in
  let rec helper (lst : user obj list) acc =
    match lst with
    | h :: t ->
        let* user_responses = Db.find_s responses "username" h.o.username in
        let r_by_user =
          { response_user_id = h.id; response_lst = user_responses }
        in
        helper t (r_by_user :: acc)
    | [] -> Lwt.return acc
  in
  helper user_lst []

(** [same_answer text id responses] is whether the question with question
    text [text] and answer choice [id] is also present in [responses] *)
let rec same_answer text id responses =
  match responses with
  | h :: t ->
      if h.o.question_text = text && id = h.o.choice_id then true
      else same_answer text id t
  | [] -> false

(** [count_matches responses1 responses2] counts how many answers are in
    common between lists [responses1] and [responses2] *)
let count_matches
    (responses1 : response obj list)
    (responses2 : response obj list) =
  let rec helper count lst =
    match lst with
    | h :: t ->
        if same_answer h.o.question_text h.o.choice_id responses1 then
          helper (count + 1) t
        else helper count t
    | [] -> count
  in
  helper 0 responses2

(** [unwrap_obj_list lst acc] is the list of ids within a list of objects
    [obj] *)
let rec unwrap_obj_list (lst : active_user obj list) acc =
  match lst with
  | h :: t -> unwrap_obj_list t (h.o.user_id :: acc)
  | [] -> acc

let most_compatible user_id =
  let* this_user = Db.get users user_id in
  let* active_users = Db.all active_users in
  let active_ids = unwrap_obj_list active_users [] in
  if not (List.exists (fun x -> x = user_id) active_ids) then
    Lwt.return_none
  else
    let* resp = Db.find_s responses "username" this_user.o.username in
    let* aggregated = aggregate_responses () in
    let rec helper (lst : responses_by_user list) max_matches match_id =
      match lst with
      | { response_user_id = usr_id; response_lst = rspnse_lst } :: t ->
          let matches = count_matches resp rspnse_lst in
          if
            matches >= max_matches && usr_id <> user_id
            && List.exists (fun x -> x = usr_id) active_ids
          then helper t matches usr_id
          else helper t max_matches match_id
      | [] -> match_id
    in
    Lwt.return (Some (helper aggregated 0 (-1)))

(** [questions_of_responses acc responses] is the list of question objects
    that are responded to by [responses] *)
let rec questions_of_responses acc = function
  | h :: t -> (
      let* q = Db.find_one_s questions "text" h.o.question_text in
      match q with
      | None -> questions_of_responses acc t
      | Some obj -> questions_of_responses (obj.o :: acc) t)
  | [] -> Lwt.return acc

(** [total_responses rl] is the response list of all the response objs in
    [rl] *)
let rec responses_of_response_objs acc = function
  | h :: t -> responses_of_response_objs (h.o :: acc) t
  | [] -> acc

(** [populate_summary] is the match summary object with [chat_id] as the
    chat id, [questions_list1] and [questions_list2] as the lists of
    questions for each user, and [response_list1] and [response_list1] as
    the lists of responses for each user *)
let populate_summary
    new_chat_obj
    questions_list1
    questions_list2
    response_list1
    response_list2 =
  {
    chat_id = new_chat_obj.id;
    user_one_questions = questions_list1;
    user_two_questions = questions_list2;
    user_one_responses = response_list1;
    user_two_responses = response_list2;
  }

(** [generate_match_summary this_user pal_id] is the match_summary for
    [this_user] and the user with id [pal_id] *)
let generate_match_summary (this_user : user obj) pal_id =
  let new_chat =
    { user_one = this_user.id; user_two = pal_id; active = true }
  in
  let username = this_user.o.username in
  let* new_chat_obj = Db.create chats new_chat in
  let new_chat_log = { chat_id = new_chat_obj.id; messages = [] } in
  let* _ = Db.create chatlogs new_chat_log in
  let* rl1 = Db.find_s responses "username" username in
  let* pal_obj = Db.get users pal_id in
  let* rl2 = Db.find_s responses "username" pal_obj.o.username in
  let* questions_list1 = questions_of_responses [] rl1 in
  let+ questions_list2 = questions_of_responses [] rl2 in
  let response_list1 = responses_of_response_objs [] rl1 in
  let response_list2 = responses_of_response_objs [] rl2 in
  let new_match_summary =
    populate_summary new_chat_obj questions_list1 questions_list2
      response_list1 response_list2
  in
  new_match_summary

let match_summary user_id =
  let* this_user = Db.get users user_id in
  let* pal = most_compatible user_id in
  match pal with
  | None -> Lwt.return_none
  | Some pal_id ->
      let* new_match_summary = generate_match_summary this_user pal_id in
      let+ summary = Db.create match_summaries new_match_summary in
      Some summary

let find_chat user_id =
  let* c1 = Db.find_i chats "user_one" user_id in
  let* c2 = Db.find_i chats "user_two" user_id in
  let+ _ = match_summary user_id in
  let l = List.filter (fun c -> c.o.active) (c1 @ c2) in
  List.nth_opt l 0

let match_state (user_id : id) =
  Logs.info (fun m -> m "get match state");
  (* check whether user is being actively matched *)
  let* u = Db.find_one_i active_users "user_id" user_id in
  if u <> None then Lwt.return Matching
  else
    (* check whether user is in an active chat *)
    let* c1 = Db.find_i chats "user_one" user_id in
    let* c2 = Db.find_i chats "user_two" user_id in
    match List.filter (fun c -> c.o.active) (c1 @ c2) with
    | [ c ] -> Matched c |> return
    | _ -> return Inactive

(** [users_string chat_obj] describes the users that are matched in
    [chat_obj] *)
let users_string chat_obj =
  let* user1 = Db.get users chat_obj.o.user_one in
  let+ user2 = Db.get users chat_obj.o.user_two in
  "This wonderful match was made between " ^ user1.o.username ^ " and "
  ^ user2.o.username ^ ".\n\n"

(** [all_questions_string ms] describes all the questions users answered in
    [ms] *)
let all_questions_string ms =
  let questions_asked =
    List.filter
      (fun y -> List.exists (fun x -> x = y) ms.user_one_questions)
      ms.user_two_questions
  in
  let question_texts = List.map (fun x -> x.text) questions_asked in
  "The questions you both answered were:\n\n"
  ^ List.fold_left (fun acc x -> x ^ acc ^ "\n\n") "" question_texts

(** [find_common_choices] resolves to the list of choices from
    [common_questions_texts] and the choices with id in [common_choice_ids] *)
let find_common_choices common_questions_texts common_choice_ids =
  Lwt_list.map_s
    (fun (x, y) ->
      let+ q = Db.find_one_s questions "text" x in
      match q with
      | Some obj -> List.nth obj.o.choices y
      | None -> failwith "question does not exist")
    (List.combine common_questions_texts common_choice_ids)

(** [common_questions_responses] is a tuple where the first element is the
    string describing common questions and the second element is the string
    describing common choices given the list [responses_in_common]*)
let common_questions_responses responses_in_common =
  let common_questions_texts =
    List.map (fun x -> x.question_text) responses_in_common
  in
  let common_questions_display =
    "The questions you gave the same responses to were:\n\n"
    ^ List.fold_left
        (fun acc x -> x ^ acc ^ "\n\n")
        "" common_questions_texts
  in
  let common_choice_ids =
    List.map (fun x -> x.choice_id) responses_in_common
  in
  let+ common_choices =
    find_common_choices common_questions_texts common_choice_ids
  in
  let choices_display =
    "...to which you both responded with:\n\n"
    ^ List.fold_left
        (fun acc (x : choice) -> x.text ^ acc ^ "\n")
        "" common_choices
  in
  (common_questions_display, choices_display)

let match_details (ms : match_summary) =
  let* chat_obj = Db.get chats ms.chat_id in
  let* matched_users_display = users_string chat_obj in
  let questions_display = all_questions_string ms in
  let responses_in_common =
    List.filter
      (fun y ->
        List.exists
          (fun x ->
            x.question_text = y.question_text && x.choice_id = y.choice_id)
          ms.user_two_responses)
      ms.user_two_responses
  in
  let+ common_questions_display, choices_display =
    common_questions_responses responses_in_common
  in
  matched_users_display ^ questions_display ^ common_questions_display
  ^ choices_display
