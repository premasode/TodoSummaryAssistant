package com.todoapp.dto;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class SummaryRequest {
    private String summaryText; // This will hold the generated summary from Cohere
}
