import "./modal.css";
import React, { Component, useState } from "react";
import Star from "./Star";
import axios from "axios";
import { Link } from "react-router-dom";
import { useHistory } from "react-router-dom";

/* Source (css, Stars.js) from:  https://dev.to/yosraskhiri/rating-stars-in-react-js-4dfg */

const Modal = ({ handleClose, show, children }) => {
  const showHideClassName = show ? "modal display-block" : "modal display-none";
  const [gradeIndex, setGradeIndex] = useState(-1);
  const GRADES = ["Poor", "Fair", "Good", "Very good", "Excellent"];
  const activeStar = {
    fill: "gray",
  };
  const history = useHistory();

  const changeGradeIndex = (index) => {
    console.log("set grade index,", index);
    setGradeIndex(index);
  };

  function handleSubmit() {
    console.log("grade", parseInt(gradeIndex) + 1);
    const ratingSubmit = {
      rating: parseInt(gradeIndex) + 1,
    };
    axios
      .post(`http://localhost:3000/rating`, JSON.stringify(ratingSubmit))
      .then((res) => {
        console.log(res);
        console.log(res.data);
        alert("submitted grade!");
        history.push("/profile");
      })
      .catch((error) => {
        console.log(error.response);
      });
  }

  return (
    <div className={showHideClassName}>
      <section className="modal-main">
        <br></br>
        Rate your match!
        <h1 className="result">
          {GRADES[gradeIndex] ? GRADES[gradeIndex] : "You didn't review yet"}
        </h1>
        <div className="stars">
          {GRADES.map((grade, index) => (
            <Star
              index={index}
              key={grade}
              changeGradeIndex={changeGradeIndex}
              style={gradeIndex >= index ? activeStar : {}}
            />
          ))}
        </div>
        <button type="button" onClick={handleSubmit}>
          Leave This Chat
        </button>
      </section>
    </div>
  );
};
export default Modal;
