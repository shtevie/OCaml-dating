import React, { Component } from "react";
import styled, { createGlobalStyle, css } from "styled-components";
import axios from "axios";
import smokeVid from "./Smoke_Dark_11_Videvo.mov";

const Question = styled.div`
  font-family: futura;
  font-size: 100;
  margin: 10px;
  color: white;
`;

const AnswerChoices = styled.div`
  display: flex;
  justify-content: center;
`;
const Answer = styled.div`
  font-family: futura;
  color: white;
`;
const StyledButton = styled.button`
  border: 1px solid black;
  &:hover {
    background-color: white;
    color: black;
    cursor: pointer;
  }
  margin: 30px auto;
`;
const SurveyWrapper = styled.div`
  position: relative;
  top: 50px;
  width: 600px;
  margin: auto;
  padding: 10px;
  background-color: rgba(255, 255, 255, 0.4);
`;
const Header = styled.div`
  position: relative;
  top: 40px;
  font-size: 50px;
  color: white;
`;
const SurveyContent = styled.div`
  position: relative;
  margin-top: 60px;
`;
const Video = styled.video`
  position: absolute;
  left: 0px;
  width: 1400px;
`;

export class Survey extends Component {
  constructor(props) {
    super(props);
    this.state = {
      questionChoices: [], //array containing dictionaries of {question: _, answers: [choice1, choice2]}
      userAnswers: {}, //question#: answer
    };
    this.parseQuestions = this.parseQuestions.bind(this);
    this.onInputChange = this.onInputChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  componentDidMount() {
    axios
      .get(`http://localhost:3000/survey`)
      .then((res) => {
        console.log("in survey success");
        console.log(res);
        this.parseQuestions(res.data.questions);
      })
      .catch((error) => {
        console.log(error.response);
      });
  }
  parseQuestions(data) {
    let questionChoices = [];
    let userAnswers = {};

    data.forEach((val, index) => {
      userAnswers["question" + index] = -1;
      const choiceArr = val.choices;
      const questionText = val.text;
      let choiceTextArr = [];
      choiceArr.forEach((choice) => {
        choiceTextArr.push(choice.text);
      });
      questionChoices.push({
        question: questionText,
        answers: choiceTextArr,
      });
    });
    this.setState({
      questionChoices: questionChoices,
      userAnswers: userAnswers,
    });
    console.log("questionChoices", this.state.questionChoices);
  }
  onInputChange(e) {
    let modAnswers = this.state.userAnswers;
    modAnswers[e.target.name] = parseInt(e.target.getAttribute("data-id"));
    this.setState({
      userAnswers: modAnswers,
    });
    console.log(this.state.userAnswers);
  }
  handleSubmit() {
    const self = this;
    const data = {
      questions: this.state.questionChoices.map(function (q, i) {
        return {
          question_text: q.question,
          choice_id: self.state.userAnswers["question" + i],
        };
      }),
    };
    console.log(data);
    axios
      .post("http://localhost:3000/survey/submit", data)
      .then(() => self.props.history.push("/matching"));
  }
  render() {
    return (
      <div style={{ fontFamily: "futura" }}>
        <Video className="videoTag" autoPlay loop muted>
          <source src={smokeVid} type="video/mp4" />
        </Video>

        <SurveyWrapper>
          <Header>Survey time!</Header>

          <SurveyContent>
            {this.state.questionChoices.map((question, qidx) => {
              return (
                <div key={"question" + qidx}>
                  <Question>{question.question}</Question>
                  <AnswerChoices>
                    {question.answers.map((answer, aidx) => {
                      return (
                        <Answer>
                          <input
                            key={"question" + qidx + "_" + aidx}
                            type="radio"
                            value={answer}
                            name={"question" + qidx}
                            checked={
                              this.state.userAnswers["question" + qidx] === aidx
                            }
                            onChange={this.onInputChange}
                            data-id={aidx}
                          />{" "}
                          {answer}
                        </Answer>
                      );
                    })}
                  </AnswerChoices>
                </div>
              );
            })}
          </SurveyContent>

          <StyledButton onClick={this.handleSubmit}>Submit</StyledButton>
        </SurveyWrapper>
      </div>
    );
  }
}
export default Survey;
