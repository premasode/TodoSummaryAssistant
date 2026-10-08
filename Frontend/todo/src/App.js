import React, { useState, useEffect } from 'react';
import TodoForm from './components/TodoForm';
import TodoList from './components/TodoList';
import Notification from './components/Notification';
import todoService from './services/todoService';
import './styles/App.css';

function App() {
  const [todos, setTodos] = useState([]);
  const [editingTodo, setEditingTodo] = useState(null);
  const [notification, setNotification] = useState({ message: '', type: '' });

  useEffect(() => {
    fetchTodos();
  }, []);

  const fetchTodos = async () => {
    try {
      const response = await todoService.getAllTodos();
      setTodos(response.data);
    } catch (error) {
      console.error('Error fetching todos:', error);
      showNotification('Error fetching todos.', 'error');
    }
  };

  const addTodo = async (todo) => {
    try {
      const response = await todoService.createTodo(todo);
      setTodos([...todos, response.data]);
      showNotification('Todo added successfully!', 'success');
    } catch (error) {
      console.error('Error adding todo:', error);
      showNotification('Error adding todo.', 'error');
    }
  };

  const updateTodo = async (id, updatedTodo) => {
    try {
      const response = await todoService.updateTodo(id, updatedTodo);
      setTodos(todos.map((todo) => (todo.id === id ? response.data : todo)));
      showNotification('Todo updated successfully!', 'success');
    } catch (error) {
      console.error('Error updating todo:', error);
      showNotification('Error updating todo.', 'error');
    }
  };

  const deleteTodo = async (id) => {
    try {
      await todoService.deleteTodo(id);
      setTodos(todos.filter((todo) => todo.id !== id));
      showNotification('Todo deleted successfully!', 'success');
    } catch (error) {
      console.error('Error deleting todo:', error);
      showNotification('Error deleting todo.', 'error');
    }
  };

  const toggleComplete = async (id, completed) => {
    const todoToUpdate = todos.find(todo => todo.id === id);
    if (todoToUpdate) {
      const updatedTodo = { ...todoToUpdate, completed: completed };
      try {
        const response = await todoService.updateTodo(id, updatedTodo);
        setTodos(todos.map(todo => (todo.id === id ? response.data : todo)));
        showNotification('Todo status updated!', 'success');
      } catch (error) {
        console.error('Error toggling todo completion:', error);
        showNotification('Error updating todo status.', 'error');
      }
    }
  };

  const summarizeAndSendToSlack = async () => {
    try {
      const response = await todoService.summarizeTodos();
      showNotification(response.data, 'success');
    } catch (error) {
      console.error('Error summarizing and sending to Slack:', error);
      showNotification('Failed to summarize and send to Slack.', 'error');
    }
  };

  const showNotification = (message, type) => {
    setNotification({ message, type });
    setTimeout(() => {
      setNotification({ message: '', type: '' });
    }, 5000); // Hide after 5 seconds
  };

  return (
    <div className="App">
      <h1>Todo Summary Assistant</h1>
      <Notification message={notification.message} type={notification.type} />
      <TodoForm addTodo={addTodo} updateTodo={updateTodo} editingTodo={editingTodo} setEditingTodo={setEditingTodo} />
      <button onClick={summarizeAndSendToSlack} className="summary-button">
        Summarize Pending Todos & Send to Slack
      </button>
      <TodoList todos={todos} deleteTodo={deleteTodo} setEditingTodo={setEditingTodo} toggleComplete={toggleComplete} />
    </div>
  );
}

export default App;