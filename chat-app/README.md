[![Open in Codespaces](https://classroom.github.com/assets/launch-codespace-2972f46106e565e64193e422d61a12cf1da4916b45550586e14ef0a7c637dd04.svg)](https://classroom.github.com/open-in-codespaces?assignment_repo_id=23242382)
# Cloud programming assignment

This repository contains two subfolders:
- backend (backend application written in Java)
- frontend (frontend application written in JavaScript)


### 1. Build containers
To build or rebuild images for all services defined in compose.yaml, run:
`docker compose build`


### 2. Run containers
To start the entire stack in the background (detached mode):
`docker compose up -d`


### 3. Configuration to do a succesful build
1- Public IP: Update PUBLIC_API_BASE_URL in compose.yaml to the current server IP (e.g., http://3.80.232.124:5000/).
2- Dependencies: Ensure all frontend packages (like @sveltejs/adapter-auto) are listed in frontend/package.json.
3- Network ports: External access requires ports 3000 (Frontend) and 5000 (Backend) to be open in AWS Security Groups / Firewall.
4. Vite Hosting: The frontend CMD must include --host to allow traffic from outside the container.


### What We Learned
1. build: vs image:
We learned that image: chat-backend tells Docker to find an image, but build: ./backend tells Docker to create one from your source code. Using both allows you to name the image you just built.

2. Orchestration vs. Individual Containers
We moved from thinking about individual docker build commands to using Docker Compose.

3. Listen Anywhere Rule (0.0.0.0)
We realized that localhost (127.0.0.1) inside a container is not the same as localhost on your computer. If Svelte or Spring Boot app is configured to listen on localhost, it will only talk to itself inside the isolated container box. The '0.0.0.0' tells the application to accept traffic from any network interface, allowing the Docker "bridge" to pass external requests through.


### Problems Encountered
1.
Problem "Exited (1) / Module Not Found": SvelteKit was looking for an adapter (adapter-static or auto) that wasn't in package.json.
Fix: Ran npm install for the missing adapter and rebuilt the image.

2.
[npm,: not found: A missing comma in the CMD array in the Dockerfile.
Corrected JSON syntax: ["npm", "run", "dev", "--", "--host"].





