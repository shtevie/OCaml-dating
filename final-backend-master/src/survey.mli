(** Functions for handling question population and survey generation *)

open Tables

(** The type of a survey which includes a list of questions *)
type t = { questions : question list }

(** [load_questions] stores questions from [file] to the database.
    Invariant: there will always be at least 4 questions in the bank *)
val load_questions : string -> unit Lwt.t

(** [new_survey] resolves to a newly generated survey *)
val new_survey : unit -> t Lwt.t
