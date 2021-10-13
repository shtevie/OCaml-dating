import React, { Component } from 'react';
import styled, { createGlobalStyle } from 'styled-components';
import Typing from 'react-typing-animation';
import background from './geometric-shapes-pink-and-blue-triangles-abstract.jpeg'

import { Link } from 'react-router-dom';

const GlobalStyle = createGlobalStyle`
  html {
    height: 100%
  }
  body {
    font-family: futura;
    background: transparent;
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


  display:block;


`;

const Header = styled.div`
  position: relative;
  display:flex;
  top: 30%;
  left: 10%;

  font-size: 60px;
`;

const LinkWrapper = styled.div`
  position: relative;
  display: flex;
  padding: 10 10;
  font-size: 20px;
  top: 40%;
  left: 10%;
`;

export class WelcomeBase extends Component {
  render() {

    return (
      <>
        <GlobalStyle />
        <MainWrapper>
          <Header>
            <Typing loop={true} delay={50} >
              <span>welcome to intrxn</span>
              <Typing.Delay ms={2000} />
              <Typing.Backspace count={20} />
            </Typing>

          </Header>

          <LinkWrapper>
            <Link to="/signup" style={{ textDecoration: 'none', color: 'white' }}>get started</Link>
          </LinkWrapper>

          <LinkWrapper>
            <Link to="/signin" style={{ textDecoration: 'none', color: 'white' }}>sign in</Link>
          </LinkWrapper>

        </MainWrapper>
      </>

    );
  }
}
export default WelcomeBase

