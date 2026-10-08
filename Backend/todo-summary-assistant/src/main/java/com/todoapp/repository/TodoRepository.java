package com.todoapp.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.todoapp.entity.Todo;

@Repository
public interface TodoRepository extends JpaRepository<Todo,Long>{
	List<Todo> findByCompletedFalse(); // For pending todos
	}

