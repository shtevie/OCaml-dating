(** Representations of tables and the types of objects stored in tables. *)

(** id for each entry in database table *)
type id = int

(** [obj] represents a database object *)
type 'a obj = {
  id : id;
  (* TODO: other fields like created_at, modified_at, etc. *)
  o : 'a;
}

(** [user] is a database user object representing a user*)
type user = {
  name : string;
  username : string;
  password : string;
}

(** [session] is a database session object representing a session *)
type session = {
  sessid : string;
  user_id : id;
}

(** [choice] is a database choice object representing a choice to respond a
    question *)
type choice = { text : string }

(** [question] is a database question object representing a survey question*)
type question = {
  text : string;
  choices : choice list;
}

(** [response] is a database response object representing a response to a
    question*)
type response = {
  username : string;
  question_text : string;
  choice_id : id;
}

(** [active user] is a databse active user object. Invariant: an active user
    must have recorded a response in the responses table *)
type active_user = { user_id : id }

(** [chat] is a database chat object representing a chat between 2 users *)
type chat = {
  active : bool;
  user_one : id;
  user_two : id;
}

(** [message] is a database message object representing a message from a
    user *)
type message = {
  user_id : id;
  content : string;
}

(** [chatlog] is a database chat log object representing a log of a chat*)
type chatlog = {
  chat_id : id;
  messages : message list;
}

(** [match_summary] is a database match summary object representing the
    details of a match *)
type match_summary = {
  chat_id : id;
  user_one_questions : question list;
  user_two_questions : question list;
  user_one_responses : response list;
  user_two_responses : response list;
}

(** [user_rating] is the total ratings of a particular user. *)
type user_rating = {
  user_id : id;
  count : int;
  total_ratings : int;
}

(** [rating] is a singular rating of a user to another user. *)
type rating = {
  waiting : bool;
  from_id : id;
  to_id : id;
  chat_id : id;
  value : int option;
}

(** [table] represents a table of an object in the database *)
type 'a table = {
  name : string;
  a_of_json : Json_util.t -> 'a;
  json_of_a : 'a -> Json_util.t;
}

(** [users] is a table of user objects *)
val users : user table

(** [sessions] is a table of session objects *)
val sessions : session table

(** [questions] is a table of question objects *)
val questions : question table

(** [responses] is a table of response objects *)
val responses : response table

(** [active_users] is a table of active user objects*)
val active_users : active_user table

(** [chats] is a table of chat objects *)
val chats : chat table

(** [chatlogs] is a table of chatlog objects*)
val chatlogs : chatlog table

(** [match_summaries] is a table of match summary objects*)
val match_summaries : match_summary table

(** [ratings] is a table of rating objects *)
val ratings : rating table

(** [user_ratings] is a table of user rating objects*)
val user_ratings : user_rating table
