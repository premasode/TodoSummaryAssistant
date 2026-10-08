import React from 'react';
import '../styles/App.css'; // Assuming you'll add styles here

const Notification = ({ message, type }) => {
  if (!message) return null;

  return (
    <div className={`notification ${type}`}>
      {message}
    </div>
  );
};

export default Notification;