import React, { useState, useEffect } from 'react';

const TodoForm = ({ addTodo, updateTodo, editingTodo, setEditingTodo }) => {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [completed, setCompleted] = useState(false);

  useEffect(() => {
    if (editingTodo) {
      setTitle(editingTodo.title);
      setDescription(editingTodo.description);
      setCompleted(editingTodo.completed);
    } else {
      setTitle('');
      setDescription('');
      setCompleted(false);
    }
  }, [editingTodo]);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!title.trim()) return;

    const todo = { title, description, completed };

    if (editingTodo) {
      updateTodo(editingTodo.id, todo);
      setEditingTodo(null); // Clear editing state
    } else {
      addTodo(todo);
    }
    setTitle('');
    setDescription('');
    setCompleted(false);
  };

  return (
    <form onSubmit={handleSubmit} className="todo-form">
      <input
        type="text"
        placeholder="Todo Title"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        required
      />
      <textarea
        placeholder="Todo Description (Optional)"
        value={description}
        onChange={(e) => setDescription(e.target.value)}
      ></textarea>
      {editingTodo && (
        <label>
          <input
            type="checkbox"
            checked={completed}
            onChange={(e) => setCompleted(e.target.checked)}
          />
          Completed
        </label>
      )}
      <button type="submit">{editingTodo ? 'Update Todo' : 'Add Todo'}</button>
    </form>
  );
};

export default TodoForm;