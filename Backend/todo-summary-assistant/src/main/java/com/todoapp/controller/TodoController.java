package com.todoapp.controller;

import com.todoapp.entity.Todo;
import com.todoapp.service.CohereService;
import com.todoapp.service.SlackService;
import com.todoapp.service.TodoService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/todos")
@CrossOrigin(origins = "http://localhost:3000") // Allow frontend access
public class TodoController {

    @Autowired
    private TodoService todoService;

    @Autowired
    private CohereService cohereService;

    @Autowired
    private SlackService slackService;

    @GetMapping
    public ResponseEntity<List<Todo>> getAllTodos() {
        return ResponseEntity.ok(todoService.getAllTodos());
    }

    @PostMapping
    public ResponseEntity<Todo> createTodo(@RequestBody Todo todo) {
        return new ResponseEntity<>(todoService.createTodo(todo), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Todo> updateTodo(@PathVariable Long id, @RequestBody Todo todoDetails) {
        return ResponseEntity.ok(todoService.updateTodo(id, todoDetails));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTodo(@PathVariable Long id) {
        todoService.deleteTodo(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/summarize")
    public ResponseEntity<String> summarizeAndSendToSlack() {
        try {
            List<Todo> pendingTodos = todoService.getPendingTodos();
            if (pendingTodos.isEmpty()) {
                return ResponseEntity.ok("No pending todos to summarize.");
            }

            // Prepare text for summarization
            String todosText = pendingTodos.stream()
                    .map(todo -> "- " + todo.getTitle() + ": " + todo.getDescription())
                    .collect(Collectors.joining("\n"));

            String summary = cohereService.summarizeText("Please summarize the following to-do items:\n" + todosText);

            boolean slackSuccess = slackService.sendSlackMessage("Todo Summary:\n" + summary);

            if (slackSuccess) {
                return ResponseEntity.ok("Summary generated and sent to Slack successfully!");
            } else {
                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Failed to send summary to Slack.");
            }
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Error processing summary: " + e.getMessage());
        }
    }
}
