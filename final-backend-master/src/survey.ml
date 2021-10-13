open Tables
open Lwt.Infix
open Lwt.Syntax

type t = { questions : question list }

(** [parse_choices] is the list of choices corresponding to the json [o] *)
let parse_choices o =
  Yojson.Basic.Util.(
    o |> to_list
    |> List.map (fun o -> { text = member "text" o |> to_string }))

(** [parse_question] is the question that corresponds to json [j] *)
let parse_question j : question =
  Yojson.Basic.Util.
    {
      text = member "text" j |> to_string;
      choices = member "choices" j |> parse_choices;
    }

let load_questions file =
  let j = Yojson.Basic.from_file file in
  Lwt_list.iter_s
    (fun o ->
      parse_question o |> Db.create questions >>= fun _ -> Lwt.return_unit)
    (Yojson.Basic.Util.to_list j)

let new_survey () =
  let* bank_size = Db.cnt questions in
  let* questions_lst = Db.all questions in
  let rec select_unique_rands counter lst =
    if counter < 4 then
      let rand_index = Random.int bank_size in
      if List.exists (fun x -> x = rand_index) lst then
        select_unique_rands counter lst
      else select_unique_rands (counter + 1) (rand_index :: lst)
    else lst
  in
  let rands = select_unique_rands 0 [] in
  let rec generate counter acc =
    if counter < 4 then
      let q_obj = List.nth questions_lst (List.nth rands counter) in
      generate (counter + 1) (q_obj.o :: acc)
    else acc
  in
  Lwt.return { questions = generate 0 [] }
