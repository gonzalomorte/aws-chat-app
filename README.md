[![Open in Codespaces](https://classroom.github.com/assets/launch-codespace-2972f46106e565e64193e422d61a12cf1da4916b45550586e14ef0a7c637dd04.svg)](https://classroom.github.com/open-in-codespaces?assignment_repo_id=23242382)
# Cloud programming assignment

This repository contains two subfolders:

- backend (backend application written in Java)
- frontend (frontend application written in JavaScript)

Please refer to `README.md` file inside each subfolder to learn more about each application.

### 1. Build containers
- Frontend:
Navigate to the frontend/ directory and run: `docker build -t chat-frontend.`

- Backend:
Navigate to the backend/ directory and run: `docker build -t chat-backend.`


### 2. Run containers
- Frontend:
`docker run -d -p 5000:5000 --name backend-container chat-backend`

- Backend:
`docker run -d -p 3000:80 --name frontend-container chat-frontend`


### 3. Configuration to do a succesful build
- Frontend:
Environment Variable: The PUBLIC_API_BASE_URL must point to the AWS Public IP of the instance so the browser can reach the backend.

- Backend: 
The gradlew script must be granted execution permissions (chmod +x gradlew).


### Orchestration with Docker Compose
To start both services and the internal network simultaneously:
Run `docker compose up --build -d`


### What We Learned

- Multi-stage Builds: How to use a heavy JDK image for building and then move only the final JAR to a slim JRE image, significantly reducing the storage footprint.
- Container Networking: We understood that while containers talk to each other via service names (e.g., http://backend:5000), the user's browser (Frontend) must talk to the Backend via a Public IP.
- Docker Caching: Using --mount=type=cache for Gradle dependencies drastically speeds up subsequent builds in a cloud environment.


### Problems Encountered
SvelteKit adapter-auto failure: The initial build failed because the default adapter didn't create a static folder for Nginx. We resolved this by installing @sveltejs/adapter-static and updating the config.
