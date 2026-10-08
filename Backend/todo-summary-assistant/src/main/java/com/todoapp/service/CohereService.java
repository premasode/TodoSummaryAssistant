package com.todoapp.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import okhttp3.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

@Service
public class CohereService {

    @Value("${cohere.api.key}")
    private String cohereApiKey;

    private final OkHttpClient httpClient;
    private final ObjectMapper objectMapper;

    public CohereService() {
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build();
        this.objectMapper = new ObjectMapper();
    }

    public String summarizeText(String text) throws IOException {
        String url = "https://api.cohere.ai/v1/summarize"; // Check Cohere's latest API endpoint

        ObjectNode requestBodyJson = objectMapper.createObjectNode();
        requestBodyJson.put("text", text);
        requestBodyJson.put("length", "long"); // "short", "medium", "long"
        requestBodyJson.put("format", "paragraph"); // "paragraph", "bullets"
        requestBodyJson.put("model", "command"); // Or "command-light"

        RequestBody body = RequestBody.create(
                requestBodyJson.toString(),
                MediaType.parse("application/json; charset=utf-8")
        );

        Request request = new Request.Builder()
                .url(url)
                .header("Authorization", "Bearer " + cohereApiKey)
                .header("Content-Type", "application/json")
                .post(body)
                .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Unexpected code " + response + " Body: " + response.body().string());
            }
            String responseBody = response.body().string();
            JsonNode jsonNode = objectMapper.readTree(responseBody);
            return jsonNode.has("summary") ? jsonNode.get("summary").asText() : "No summary found.";
        }
    }
}
