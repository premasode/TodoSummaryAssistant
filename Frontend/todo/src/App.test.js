import { render, screen, act } from '@testing-library/react';
import App from './App';
import todoService from './services/todoService';

jest.mock('./services/todoService');

test('renders Todo Summary Assistant title', async () => {
  todoService.getAllTodos.mockResolvedValue({ data: [] });
  
  await act(async () => {
    render(<App />);
  });

  const headerElement = screen.getByText(/Todo Summary Assistant/i);
  expect(headerElement).toBeInTheDocument();
});
