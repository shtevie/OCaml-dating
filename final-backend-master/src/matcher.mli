(** Handler for matching users with the matching algorithm. *)

open Tables

(** the state a match is in *)
type match_state =
  | Matching
  | Matched of chat obj
  | Inactive

(** [most_compatible username] resolves to the most compatible user to be
    matched with the user [username] *)
val most_compatible : id -> id option Lwt.t

(** [match_summary username] resolves to the match summary with the most
    compatible user for [username] *)
val match_summary : id -> match_summary obj option Lwt.t

(** [get_match_state user_id] is the match state of the user with id
    [user_id]. *)
val match_state : id -> match_state Lwt.t

(** [match_details ms] is the string that describes the details of [ms] *)
val match_details : match_summary -> string Lwt.t

(** [find_chat user_id] is [Some x] where [x] is a chat that contains
    [user_id] as either [user_one] or [user_two], or [None] if no such chat
    exists. *)
val find_chat : id -> chat obj option Lwt.t
