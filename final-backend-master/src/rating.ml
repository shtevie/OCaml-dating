open Tables
open Lwt.Syntax
open Opium_util
open Yojson.Safe.Util
open Lwt

let average_rating user_id =
  Db.find_one_i user_ratings "user_id" user_id >|= fun obj ->
  match obj with
  | Some x -> float_of_int x.o.total_ratings /. float_of_int x.o.count
  | None -> 0.0

let find_rating from_id =
  let* ratings = Db.find_i ratings "from_id" from_id in
  let filtered = List.filter (fun r -> r.o.waiting) ratings in
  List.nth_opt filtered 0 |> Lwt.return

let rate_error_response =
  error_response ~status:`Unauthorized "cannot rate this user"

let update_user_rating user_id value =
  Db.find_one_i user_ratings "user_id" user_id >>= fun obj ->
  match obj with
  | Some x ->
      Db.update user_ratings x.id
        {
          x.o with
          count = x.o.count + 1;
          total_ratings = x.o.total_ratings + value;
        }
  | None ->
      Db.create user_ratings { user_id; count = 1; total_ratings = value }
      >>= fun _ -> Lwt.return_unit

let update_rating rating value =
  Db.update ratings rating.id
    { rating.o with waiting = false; value = Some value }

let rate user_id value =
  let* rating_opt = find_rating user_id in
  match rating_opt with
  | None ->
      Logs.err (fun m ->
          m "rate: could not find active rating from user %d" user_id);
      rate_error_response |> return
  | Some rating ->
      let* () = update_user_rating rating.o.to_id value in
      let* () = update_rating rating value in
      success_response "success" |> return

let average_rating_from_username username =
  Db.find_one_s users "username" username >>= fun obj ->
  match obj with
  | Some u -> average_rating u.id
  | None ->
      failwith "User doesn't exist in table - this should not be possible"

let cancel_rating rating_obj =
  Db.update ratings rating_obj.id { rating_obj.o with waiting = false }

let cancel_existing_ratings user_id =
  let* existing = Db.find_i ratings "from_id" user_id in
  Lwt_list.iter_s
    (fun r -> if r.o.waiting then cancel_rating r else return_unit)
    existing

let create_ratings chat_id user_id other_id =
  let rating =
    {
      chat_id;
      to_id = other_id;
      from_id = user_id;
      waiting = true;
      value = None;
    }
  in
  let* rating_obj1 = Db.create ratings rating in
  let+ rating_obj2 =
    Db.create ratings { rating with to_id = user_id; from_id = other_id }
  in
  (rating_obj1, rating_obj2)
