import React, { Component } from 'react';
import styled, { createGlobalStyle, css } from 'styled-components';
import axios from 'axios'
import background from './profilewallpaper.jpeg'



const GlobalStyle = createGlobalStyle`
  html {
    height: 100%
  }
  body {
    font-family: futura;
    background: #FFFFFF;
    height: 100%;
    margin: 0;
    color: #555;
  }
`;

const MainWrapper = styled.div`

  width: 100%;
  height:100%;
  background-image: url(${background});
  height: 100vh;
  background-position: center;
  background-repeat: no-repeat;
  background-size: cover;

`;
const Field = styled.h3`
  position: relative;
  top: 100px;

`
const Button = styled.button`
position: relative;
margin-top: 130px;
`
export class UserProfile extends Component {
  constructor(props) {
    super(props);
    this.state = {
      username: '',
      password: '',
      name: '',
      rating: '',
    };
    this.handleSubmit = this.handleSubmit.bind(this)
  }

  componentDidMount() {
    console.log("in profile now")
    axios.get(`http://localhost:3000/user`)
      .then(res => {
        console.log("in profile after")
        console.log(res);
        console.log("resdata", res.data);
        this.setState({
          username: res.data.username,
          name: res.data.name,
          rating: res.data.rating.toFixed(1),
        })
      }).catch(error => {
        console.log("err", error);
        console.log(error.response);

      });
  }
  handleSubmit() {
    this.props.history.push("/survey");
  }
  render() {
    return (
      <>
        <GlobalStyle />
        <MainWrapper>
          <h1 style={{ position: "relative", top: "100px" }}>profile</h1>
          <Field>name: {this.state.name}</Field>
          <Field>username: {this.state.username}</Field>
          <Field>rating: {this.state.rating}</Field>
          <Button onClick={this.handleSubmit}>Take me to my next hot date</Button>
        </MainWrapper>
      </>

    );
  }
}
export default UserProfile

