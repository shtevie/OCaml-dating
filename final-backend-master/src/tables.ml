open Json_util

type id = int

type 'a obj = {
  id : id;
  o : 'a;
}

type user = {
  name : string;
  username : string;
  password : string;
}

type session = {
  sessid : string;
  user_id : id;
}

type choice = { text : string }

type question = {
  text : string;
  choices : choice list;
}

type message = {
  user_id : id;
  content : string;
}

type chatlog = {
  chat_id : id;
  messages : message list;
}

type chat = {
  active : bool;
  user_one : id;
  user_two : id;
}

type response = {
  username : string;
  question_text : string;
  choice_id : id;
}

type match_summary = {
  chat_id : id;
  user_one_questions : question list;
  user_two_questions : question list;
  user_one_responses : response list;
  user_two_responses : response list;
}

type rating = {
  waiting : bool;
  from_id : id;
  to_id : id;
  chat_id : id;
  value : int option;
}

type user_rating = {
  user_id : id;
  count : int;
  total_ratings : int;
}

type active_user = { user_id : id }

type 'a table = {
  name : string;
  a_of_json : Json_util.t -> 'a;
  json_of_a : 'a -> Json_util.t;
}

let users =
  {
    name = "users";
    a_of_json =
      (fun o ->
        {
          name = member "name" o |> to_string;
          username = member "username" o |> to_string;
          password = member "password" o |> to_string;
        });
    json_of_a =
      (fun user ->
        `O
          [
            ("name", `String user.name);
            ("username", `String user.username);
            ("password", `String user.password);
          ]);
  }

let sessions =
  {
    name = "sessions";
    json_of_a =
      (fun session ->
        `O
          [
            ("sessid", `String session.sessid);
            ("user_id", `Float (float_of_int session.user_id));
          ]);
    a_of_json =
      (fun o ->
        {
          sessid = member "sessid" o |> to_string;
          user_id = member "user_id" o |> to_int;
        });
  }

let parse_choices o =
  o |> to_list
  |> List.map (fun o -> { text = member "text" o |> to_string })

let questions =
  {
    name = "questions";
    a_of_json =
      (fun o ->
        {
          text = member "text" o |> to_string;
          choices = member "choices" o |> parse_choices;
        });
    json_of_a =
      (fun q ->
        `O
          [
            ("text", `String q.text);
            ( "choices",
              `A
                (q.choices
                |> List.map (fun (c : choice) ->
                       `O [ ("text", `String c.text) ])) );
          ]);
  }

let responses =
  {
    name = "responses";
    a_of_json =
      (fun o ->
        {
          username = member "username" o |> to_string;
          question_text = member "question_text" o |> to_string;
          choice_id = member "choice_id" o |> to_int;
        });
    json_of_a =
      (fun q ->
        `O
          [
            ("username", `String q.username);
            ("question_text", `String q.question_text);
            ("choice_id", `Float (float_of_int q.choice_id));
          ]);
  }

let active_users =
  {
    name = "active_users";
    a_of_json = (fun o -> { user_id = member "user_id" o |> to_int });
    json_of_a =
      (fun q -> `O [ ("user_id", `Float (float_of_int q.user_id)) ]);
  }

let chats =
  {
    name = "chats";
    a_of_json =
      (fun o ->
        {
          user_one = member "user_one" o |> to_int;
          user_two = member "user_two" o |> to_int;
          active = member "active" o |> to_bool;
        });
    json_of_a =
      (fun chat ->
        `O
          [
            ("user_one", `Float (float_of_int chat.user_one));
            ("user_two", `Float (float_of_int chat.user_two));
            ("active", `Bool chat.active);
          ]);
  }

let parse_messages o =
  o |> to_list
  |> List.map (fun o ->
         {
           user_id = member "user_id" o |> to_int;
           content = member "content" o |> to_string;
         })

let chatlogs =
  {
    name = "chatlogs";
    a_of_json =
      (fun o ->
        {
          chat_id = member "chat_id" o |> to_int;
          messages = member "messages" o |> parse_messages;
        });
    json_of_a =
      (fun chat ->
        `O
          [
            ("chat_id", `Float (float_of_int chat.chat_id));
            ( "messages",
              `A
                (chat.messages
                |> List.map (fun (m : message) ->
                       `O
                         [
                           ("user_id", `Float (float_of_int m.user_id));
                           ("content", `String m.content);
                         ])) );
          ]);
  }

let match_summaries =
  {
    name = "match_summaries";
    a_of_json =
      (fun o ->
        {
          chat_id = member "chat_id" o |> to_int;
          user_one_questions =
            member "user_one_questions" o
            |> to_list
            |> List.map questions.a_of_json;
          user_two_questions =
            member "user_two_questions" o
            |> to_list
            |> List.map questions.a_of_json;
          user_one_responses =
            member "user_one_responses" o
            |> to_list
            |> List.map responses.a_of_json;
          user_two_responses =
            member "user_two_responses" o
            |> to_list
            |> List.map responses.a_of_json;
        });
    json_of_a =
      (fun a ->
        `O
          [
            ("chat_id", `Float (float_of_int a.chat_id));
            ( "user_one_questions",
              `A (a.user_one_questions |> List.map questions.json_of_a) );
            ( "user_two_questions",
              `A (a.user_two_questions |> List.map questions.json_of_a) );
            ( "user_one_responses",
              `A (a.user_one_responses |> List.map responses.json_of_a) );
            ( "user_two_responses",
              `A (a.user_two_responses |> List.map responses.json_of_a) );
          ]);
  }

let ratings =
  {
    name = "ratings";
    a_of_json =
      (fun o ->
        {
          waiting = member "waiting" o |> to_bool;
          to_id = member "to_id" o |> to_int;
          from_id = member "from_id" o |> to_int;
          chat_id = member "chat_id" o |> to_int;
          value = member "value" o |> to_opt to_int;
        });
    json_of_a =
      (fun a ->
        `O
          [
            ("waiting", `Bool a.waiting);
            ("to_id", `Float (float_of_int a.to_id));
            ("from_id", `Float (float_of_int a.from_id));
            ("chat_id", `Float (float_of_int a.chat_id));
            ( "value",
              match a.value with
              | None -> `Null
              | Some v -> `Float (float_of_int v) );
          ]);
  }

let user_ratings =
  {
    name = "user_ratings";
    a_of_json =
      (fun o ->
        {
          user_id = member "user_id" o |> to_int;
          count = member "count" o |> to_int;
          total_ratings = member "total_ratings" o |> to_int;
        });
    json_of_a =
      (fun a ->
        `O
          [
            ("user_id", `Float (float_of_int a.user_id));
            ("count", `Float (float_of_int a.count));
            ("total_ratings", `Float (float_of_int a.total_ratings));
          ]);
  }
