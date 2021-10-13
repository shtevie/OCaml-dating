import "./App.css";
import WelcomeBase from "./components/Welcome";
import { BrowserRouter as Router, Switch, Route } from "react-router-dom";
import SignUpBase from "./components/SignUp";
import UserProfile from "./components/UserProfile";
import SignInBase from "./components/SignIn";
import Messaging from "./components/Messaging";
import axios from "axios";
import Matching from "./components/Matching";
import Survey from "./components/Survey";

axios.defaults.withCredentials = true;

function App() {
  return (
    <div className="App">
      <Router>
        <Switch>
          <Route path="/" exact component={WelcomeBase} />
          <Route path="/signup" exact component={SignUpBase} />
          <Route path="/signin" exact component={SignInBase} />
          <Route path="/profile" exact component={UserProfile} />
          <Route path="/messaging" exact component={Messaging} />
          <Route path="/survey" exact component={Survey} />
          <Route path="/matching" exact component={Matching} />
        </Switch>
      </Router>
    </div>
  );
}

export default App;
