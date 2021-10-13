(** Functions for handling user ratings *)

open Tables

(** [rate_error_response] is the response returned by [rate] when a bad
    rating is requested. *)
val rate_error_response : Opium.Response.t

(** [rate user_id value] finds and updates an active rating from [user_id]
    and updates the corresponding [user_rating]. On a successful rating,
    this returns a success response, otherwise a [error_response]. *)
val rate : id -> int -> Opium.Response.t Lwt.t

(** [average_user_rating user_id] is the average rating of a the user with
    [user_id], or [0] if the user has not been rated. *)
val average_rating : id -> float Lwt.t

(** [update_user_rating user_id value] adds the rating with [value] to the
    [user_rating] with [user_id]. *)
val update_user_rating : id -> int -> unit Lwt.t

(** [update_rating rating value] updates [rating] so that [waiting] is false
    and its [value] is [Some value]. *)
val update_rating : rating obj -> int -> unit Lwt.t

(** [average_user_rating_from_name username] is the average rating of a user
    with [username], or [Failure] if that user is found. *)
val average_rating_from_username : string -> float Lwt.t

(** [find_rating from_id] is [Some r] where [r] is the rating object that is
    [waiting] and whose [from_id] is [from_id], or [None] if no such rating
    exists. *)
val find_rating : id -> rating obj option Lwt.t

(** [cancel_rating r] updates [r] so that its [waiting] field is false. *)
val cancel_rating : rating obj -> unit Lwt.t

(** [cancel_existing_ratings user] updates each rating [r] whose [from_id]
    is [user] so that its [waiting] field is false. *)
val cancel_existing_ratings : id -> unit Lwt.t

(** [create_ratings chat_id u1_id u2_id] creates a waiting rating from
    [u1_id] to [u2_id] and vice-versa using [chat_id]. *)
val create_ratings : id -> id -> id -> (rating obj * rating obj) Lwt.t
