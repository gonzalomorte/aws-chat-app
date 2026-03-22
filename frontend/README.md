## SvelteKit Chat Application

This is an application created for educational purposes to be hosted using various cloud services. It is a demonstrative application that **contains many anti-patterns in web application design, which should not be replicated.**

---

## Prerequisites

- **Node.js**
- **npm**
- **Docker**

---

## Project Setup

1. **Enter the folder:**

   ```bash
   cd frontend
   ```

2. **Install dependencies:**

   ```bash
   npm install
   ```

---

## Environment Variables

The application uses dynamic environment variables (via `$env/dynamic/public`) to set the API base URL at runtime. This allows you to override the value without rebuilding the project.

- **PUBLIC_API_BASE_URL**: API base URL used by the app.

You can create a local `.env` file for development (note that for Docker deployments, the variable can be passed directly):

```dotenv
PUBLIC_API_BASE_URL=http://localhost:8080/
```

*Note:* The SvelteKit dynamic public environment variables allow changes at runtime when using the Node adapter.

---

## Development Mode

To run the application in development mode, use:

```bash
npm run dev
```

The app will be available at [http://localhost:8081/](http://localhost:8081/).

---

## Production Build & Run

The project uses the `@sveltejs/adapter-node` adapter to build a production-ready Node.js server.

# How to Dockerize and run 
[https://dev.to/code42cate/how-to-dockerize-sveltekit-3oho](https://dev.to/code42cate/how-to-dockerize-sveltekit-3oho)
