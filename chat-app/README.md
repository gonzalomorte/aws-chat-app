# chat-app

Source code for the AWS Chat App: a real-time chat application split into a **SvelteKit frontend** and a **Spring Boot backend**.

## Structure

| Folder / File | Purpose |
|---|---|
| `frontend/` | SvelteKit + TypeScript app served on port 3000. Handles the chat UI, polls the backend for messages, and sends keyword alerts to the Lambda Function URL. |
| `backend/` | Spring Boot (Kotlin / Gradle) REST API on port 5000. Persists messages to PostgreSQL via Spring Data JPA. |
| `docker-compose.yml` | Runs both services locally for development (no AWS needed). |

## API endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/chat/all?username=X` | Load all messages in chronological order |
| `POST` | `/chat` | Store a new message |
| `DELETE` | `/chat` | Delete all messages |

## Environment variables

| Variable | Service | Description |
|---|---|---|
| `PUBLIC_API_BASE_URL` | Frontend | Base URL of the backend, injected at build time by ECS task definition |
| `PUBLIC_LAMBDA_URL` | Frontend | Lambda Function URL for keyword-triggered alerts |
| `DB_HOST` | Backend | RDS endpoint injected by ECS task definition |
| `DB_PASSWORD` | Backend | RDS password injected by ECS task definition |

## Local development

```bash
docker compose up --build
```

Frontend → http://localhost:3000  
Backend  → http://localhost:5000

For AWS deployment see the [root README](../README.md).
