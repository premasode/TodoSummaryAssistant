import React from 'react';

const TodoList = ({ todos, deleteTodo, setEditingTodo, toggleComplete }) => {
  return (
    <div className="todo-list">
      {todos.map((todo) => (
        <div key={todo.id} className={`todo-item ${todo.completed ? 'completed' : ''}`}>
          <h3>{todo.title}</h3>
          <p>{todo.description}</p>
          <div className="todo-actions">
            <button onClick={() => toggleComplete(todo.id, !todo.completed)}>
              {todo.completed ? 'Mark Pending' : 'Mark Complete'}
            </button>
            <button onClick={() => setEditingTodo(todo)}>Edit</button>
            <button onClick={() => deleteTodo(todo.id)}>Delete</button>
          </div>
        </div>
      ))}
    </div>
  );
};

export default TodoList;