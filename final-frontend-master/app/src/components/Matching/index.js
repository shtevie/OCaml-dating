import React, { Component, useEffect, useState } from "react";
import styled, { createGlobalStyle, css } from "styled-components";
import axios from "axios";
import { useWS } from "../../utils/ws_util";
import { useHistory } from "react-router";
import ReactLoading from "react-loading";

const MainWrapper = styled.div`
  font-family: helvetica;
  display: flex;
  flex-direction: column;
  align-items: center;
`;
const matchFailed = {
  message: "failed",
};

const matchSuccess = {
  message: "success",
  data: {},
};

const matchOngoing = {
  message: "matching",
};

async function getMatchState() {
  const resp = await axios.get("http://localhost:3000/matching/state");
  return resp.data;
}

export function Matching() {
  const [failed, setFailed] = useState(false);
  const history = useHistory();

  async function parseMatchState() {
    const matchState = await getMatchState();
    if (matchState.message === "failed") setFailed(true);
    else if (matchState.message === "success") history.push("/messaging");
  }

  useEffect(parseMatchState, []);

  useEffect(
    function () {
      if (failed) {
        window.alert("We couldn't find a match for you! Please try again.");
        history.push("/profile");
      }
    },
    [failed]
  );

  const ws = useWS();
  useEffect(function () {
    ws.current.onmessage = async function (event) {
      const d = JSON.parse(event.data);
      if (d.hasOwnProperty("event")) {
        if (d.event === "matched") {
          history.push("/messaging");
        } else if (d.event === "failed") {
          setFailed(true);
        }
      } else {
        // incorrect message suggests it is not in the correct state
        await parseMatchState();
      }
    };

    ws.current.onclose = async function () {
      await parseMatchState();
    };
  }, []);

  return (
    <>
      <MainWrapper>
        <h1>Waiting for a match...</h1>
        <h3>Do not leave this page!</h3>
        <ReactLoading type="bubbles" color="black" height={200} width={175} />
      </MainWrapper>
    </>
  );
}

export default Matching;
