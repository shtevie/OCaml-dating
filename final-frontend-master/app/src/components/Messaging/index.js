import React, { Component, useEffect, useState, useRef } from "react";
import styled from "styled-components";
import "./messages.css";
import Cookies from "js-cookie";
import { Navigation } from "react-minimal-side-navigation";
import "react-minimal-side-navigation/lib/ReactMinimalSideNavigation.css";
import Modal from "./Modal.js";

import { useWS } from "../../utils/ws_util";
import axios from "axios";
import { useHistory } from "react-router-dom";

//css taken from https://stackoverflow.com/questions/19400183/how-to-style-chat-bubble-in-iphone-classic-style-using-css-only

const MainWrapper = styled.div`
  font-family: helvetica;
  display: flex;
  flex-direction: column;
  align-items: center;
`;
const Profiles = styled.div`
  position: fixed;
  left: 0px;
  height: 100%;
  width: 300px;
  border-right: 1px solid lightgray;
`;
const Title = styled.div`
  font-size: 20px;
  position: fixed;
  top: 0px;
  left: 300px;
  height: 40px;
  padding-top: 11px;
  width: 658px;
  margin: auto;
  text-align: center;
  vertical-align: center;
  background-color: white;
  z-index: 4;
  border-bottom: 1px solid lightgray;
  border-left: 1px solid lightgray;
`;

const Chat = styled.div`
  position: absolute;
  width: 600px;
  left: 300px;
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 28px;
  //*border: 1px solid lightgray;
`;

const LeftWrapper = styled.div`
  position: fixed;
  right: 0%;
  height: 100%;
  width: 320px;
  border-left: 1px solid lightgray;
`;

const Details = styled.div`
  position: absolute;
  left: 0px;
  opacity: 1;
  padding: 7px;
  top: 0px;
  font-family: helvetica;
  text-align: left;
`;
const FormWrapper = styled.div`
  height: 50px;
  position: absolute;
  left: 0px;
  display: inline-block;
  vertical-align: middle;
  bottom: 0;
  opacity: 1;
  background-color: white;
  width: 600px;
  border-top: 1px solid lightgray;
`;
const MessageListWrapper = styled.div`
  position: relative;
  top: 40px;
  width: 100%;
  //*border: 1px solid red;
`;
const Marker = styled.div`
  position: absolute;
  bottom: 40px;
  float: left;
  clear: both;
`;

const DUMMY_DATA = [
  {
    senderId: "perborgen",
    text: "hello ur a hot babe",
  },
  {
    senderId: "jane",
    text: "ew",
  },
];

async function getMatchState() {
  const resp = await axios.get("http://localhost:3000/matching/state");
  return resp.data;
}

export function Messaging() {
  const [show, setShow] = useState(false);
  const [messages, setMessages] = useState(DUMMY_DATA);
  const [value, setValue] = useState("");
  const [matchDetails, setMatchDetails] = useState("Match Details");
  const messagesEnd = useRef(null);
  const history = useHistory();
  const user = "jane";
  const userClassification = { perborgen: "them", jane: "me", other: "them" };

  function showModal() {
    setShow((a) => true);
  }

  function hideModal() {
    setShow((a) => false);
  }

  function addMessage(text) {
    console.log(text);
    setMessages((a) => [...a, text]);
  }

  function sendMessage(text) {
    ws.current.send(`{"message":"${text.text}"}`);
    addMessage(text);
    console.log(`sending ${text}`);
  }

  function handleChange(e) {
    setValue(e.target.value);
  }

  function handleSubmit(e) {
    e.preventDefault();
    const text = {
      senderId: user,
      text: value,
    };
    console.log(text);
    sendMessage(text);
    setValue("");
  }

  function failed() {
    window.alert("You are not in an active chatting session!");
    history.push("/profile");
  }

  async function parseMatchState() {
    const matchState = await getMatchState();

    if (matchState.message === "failed") failed();
    else if (matchState.message === "success") {
      axios
        .get(`http://localhost:3000/matching/details`)
        .then((res) => {
          console.log(res);
          console.log(res.data);
          setMatchDetails(res.data.details);
        })
        .catch((error) => {
          console.log(error.response);
        });
    }
  }

  useEffect(parseMatchState, []);

  const ws = useWS();
  useEffect(() => {
    ws.current.onmessage = (e) => {
      console.log(e.data);
      const data = JSON.parse(e.data);
      if (data.hasOwnProperty("message"))
        addMessage({ text: data.message, senderId: "other" });
      else failed();
    };

    ws.current.onclose = () => {
      console.log("chat ended");
    };

    return () => {
      ws.current.close();
    };
  }, [ws]);

  useEffect(() => {
    messagesEnd.current.scrollIntoView({ behavior: "smooth" });
  });
  /*loading ? (
    <MainWrapper>
      <Title>Connecting you with your next hot date</Title>
      <ReactLoading type="bubbles" color="black" height={200} width={175} />
      <div ref={messagesEnd}>
      </div>
    </MainWrapper>

    style={{ float: "left", clear: "both", border: "5px solid blue" }}
  ) : */

  return (
    <div>
      <Profiles>
        <Navigation
          // you can use your own router's api to get pathname
          activeItemId="/moveOn"
          onSelect={({ itemId }) => {
            console.log(itemId);
            if (itemId === "/moveOn") {
              showModal();
            }
          }}
          items={[
            {
              title: "Dashboard",
              itemId: "/dashboard",
              // you can use your own custom Icon component as well
              // icon is optional
            },
            {
              title: "Profile",
              itemId: "/profiles",

              subNav: [
                {
                  title: "Me",
                  itemId: "/profiles/me",
                },
                {
                  title: "You",
                  itemId: "/profiles/you",
                },
              ],
            },
            {
              title: "Move On",
              itemId: "/moveOn",
            },
          ]}
        />
      </Profiles>
      <Modal show={show} handleClose={hideModal}>
        <p>Modal</p>
      </Modal>

      <MainWrapper>
        <Chat height={(window.innerHeight - 80).toString().concat("px")}>
          <Title>Messaging Chat</Title>
          <MessageListWrapper>
            <MessageList
              messages={messages}
              userClassification={userClassification}
            />
            <Marker ref={messagesEnd}></Marker>
          </MessageListWrapper>
        </Chat>
        <LeftWrapper>
          {/* <Details>{matchDetails}</Details> */}

          <FormWrapper>
            <form onSubmit={handleSubmit}>
              <input
                type="text"
                value={value}
                onChange={handleChange}
                placeholder=" Hit ENTER to send"
                style={{
                  width: "290px",
                  marginRight: "10px",
                  float: "left",
                  borderRadius: "25px",
                  padding: "10px",
                  height: "25px",
                }}
              />
              <input
                type="submit"
                onClick={handleSubmit}
                value="Submit"
                style={{
                  display: "none",
                  marginLeft: "10px",
                  width: "100px",
                }}
              />
            </form>
          </FormWrapper>
        </LeftWrapper>
      </MainWrapper>
    </div>
  );
}

class MessageList extends Component {
  render() {
    return (
      <div className="section">
        {this.props.messages.map((message, index) => {
          const styClass =
            this.props.userClassification[message.senderId] === "me"
              ? "from-me"
              : "from-them";
          return (
            <div key={index}>
              <div className={styClass}>{message.text}</div>
              <div className="clear"></div>
            </div>
          );
        })}
      </div>
    );
  }
}

export default Messaging;
