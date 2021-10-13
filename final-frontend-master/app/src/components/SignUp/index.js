import React, { Component } from "react";
import styled, { createGlobalStyle } from "styled-components";
import { Link, Redirect } from "react-router-dom";
import axios from "axios";
import background from "../Welcome/geometric-shapes-pink-and-blue-triangles-abstract.jpeg";

const GlobalStyle = createGlobalStyle`
  html {
    height: 100%
  }
  body {
    font-family: futura;
    background: #FFFFFF;
    height: 100%;
    margin: 0;
    color: white;
  }
`;

const MainWrapper = styled.div`
  background-image: url(${background});
  height: 100vh;
  background-position: center;
  background-size: cover;
  margin-top: 0px;
  position: relative;
`;
const Header = styled.div`
  display: flex;
  top: 90px;
  left: 10%;

  font-size: 60px;
  position: relative;
`;

const StyledButton = styled.button`
  font-family: futura;
  background-color: black;
  color: #ffffff;
  font-size: 0.7rem;
  border: 0;
  border-radius: 5px;
  padding: 5px 20px;
  box-sizing: border-box;
  width: 100%;
  margin-top: 20px;

  &:hover {
    background-color: white;
    color: black;
    cursor: pointer;
  }
`;

const StyledInput = styled.input`
  background-color: white;
  height: 40px;
  border-radius: 5px;
  border: 1px solid #ddd;
  margin: 10px 0px 10px 0px;
  padding: 20px;
  box-sizing: border-box;
`;
const StyledForm = styled.form`
  display: block;
  position: relative;
`;
const FormContainer = styled.div`
  width: 188px;
  margin-top: 100px;
  margin-left: 10%;
  position: relative;
`;
const StyledLabel = styled.div`
  float: left;
`;
const ErrMsg = styled.div`
position: relative;
width: 300px;
  top: -80px;
  text-align: left;
`

export class SignUpBase extends Component {
  constructor(props) {
    super(props);
    this.state = {
      username: "",
      password: "",
      name: "",
      submitMessage: "",
    };

    this.handleUserChange = this.handleUserChange.bind(this);
    this.handlePwdChange = this.handlePwdChange.bind(this);
    this.handleNameChange = this.handleNameChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }
  handleUserChange(event) {
    this.setState({ username: event.target.value });
  }
  handlePwdChange(event) {
    this.setState({ password: event.target.value });
  }

  handleNameChange(event) {
    this.setState({ name: event.target.value });
  }
  handleIncorrectField(errMsg) {
    let msg = "Something is incorrect with your fields! "
    if (errMsg === "invalid password") {
      msg = "Password must contain an uppercase letter, special character, and no whitespaces.";
    }
    if (errMsg === "username taken") {
      msg = "This username is already taken."
    }
    this.setState({
      submitMessage: msg,
    })


  }

  handleSubmit(event) {
    event.preventDefault();

    // data object of user information
    const data = {
      username: this.state.username,
      name: this.state.name,
      password: this.state.password,
    };

    axios
      .post(`http://localhost:3000/users/create`, JSON.stringify(data))
      .then((res) => {
        console.log(res);
        console.log(res.data);
        alert("Welcome! You will now be directed to your profile page.");
        this.props.history.push("/profile");
        return;
      }).catch(error => {
        console.log(error.response);
        this.handleIncorrectField(error.response.data.error);
      });
  }

  render() {
    return (
      <>
        <GlobalStyle />
        <MainWrapper>
          <Header>sign up</Header>

          <FormContainer>
            <StyledForm onSubmit={this.handleSubmit}>
              <StyledLabel>name </StyledLabel>
              <StyledInput
                type="text"
                value={this.state.name}
                onChange={this.handleNameChange}
              />
              <StyledLabel>username </StyledLabel>
              <StyledInput
                type="text"
                value={this.state.username}
                onChange={this.handleUserChange}
              />
              <StyledLabel>password </StyledLabel>
              <StyledInput
                type="text"
                value={this.state.password}
                onChange={this.handlePwdChange}
              />
              <StyledButton name="connect">sign up</StyledButton>

            </StyledForm>
            <ErrMsg id="submitMessage">{this.state.submitMessage}</ErrMsg>

          </FormContainer>
        </MainWrapper>
      </>
    );
  }
}
export default SignUpBase;
