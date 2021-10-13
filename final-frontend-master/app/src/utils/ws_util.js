import React, { Component, useEffect, useState, useRef } from "react";
import Cookies from "js-cookie";

export function useWS() {
  const ws = useRef(null);
  useEffect(() => {
    ws.current = new WebSocket("ws://localhost:3007");

    ws.current.onopen = () => {
      console.log("ws opened");
      ws.current.send(`{"sessid":"${Cookies.get("sessid")}"}`);
    };
  }, []);
  return ws;
}
