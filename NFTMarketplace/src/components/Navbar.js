import React, { Component } from 'react';

class Navbar extends Component {

  render() {
    return (
      <div>
        <div className="left-side">
          <h1>App to Display NFTs</h1>
        </div>
        <div className="right-side">
          <p>Account: {this.props.data}</p>
        </div>
      </div>
    );
  }

}

export default Navbar;