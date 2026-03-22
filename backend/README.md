# Spring Boot Chat Application

This is an application created for educational purposes to be hosted using various cloud services. It is a demonstrative application that **contains many anti-patterns in web application design, which should not be replicated**.

## Overview

The chat application exposes three main endpoints:
- **GET /chat/all?username={username}**: Retrieves all chat messages.
- **GET /chat?username={username}&after={timestamp}**: Retrieves messages created after the specified timestamp (ISO-8601 format).
- **POST /chat**: Accepts a JSON payload with `username` and `message` to store a new message.

## Prerequisites

- **Java JDK 11** or later
- **Maven** or **Gradle** (depending on your build tool)
- **Docker** (if deploying using Docker)
- **Git** (for cloning the repository)

## Building the Application

### Using Gradle

Run the following command to build the executable JAR:

```bash
./gradlew clean build
```

The JAR file will be generated in the `build/libs` directory.

## Running the Application

### Locally

After building, you can run the application locally using the executable JAR:

```bash
java -jar build/libs/ChatApp-0.0.1-SNAPSHOT.jar
```

## Configuration

### Environment Variables

The Spring Boot application can be configured entirely via environment variables, allowing you to override any property defined in your configuration files. This is especially useful in production and containerized environments.

For example, to override the data source URL in production, you can set the environment variable before starting the application:

```bash
export SPRING_DATASOURCE_URL=jdbc:postgresql://yourhost:5432/yourdb
java -jar app.jar
```

When running your application inside a Docker container, pass the necessary environment variables at runtime. For example:

```bash
docker run -d -p 8080:8080 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://yourhost:5432/yourdb \
  chat-application
```

[https://www.baeldung.com/spring-boot-properties-env-variables](https://www.baeldung.com/spring-boot-properties-env-variables)

## API Endpoints

### Retrieve All Messages

- **URL:** `/chat/all`
- **Method:** GET
- **Query Parameter:** `username`
- **Description:** Returns all chat messages.

### Retrieve New Messages

- **URL:** `/chat`
- **Method:** GET
- **Query Parameters:**
    - `username`
    - `after` (ISO-8601 formatted timestamp)
- **Description:** Returns messages created after the given timestamp.

### Send a New Message

- **URL:** `/chat`
- **Method:** POST
- **Request Body:** JSON object containing:
    - `username`
    - `message`
- **Example:**

```json
{
  "username": "JohnDoe",
  "message": "Hello, world!"
}
```