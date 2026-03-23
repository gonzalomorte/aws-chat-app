# Stage 1: Build
FROM node:18-alpine AS build
WORKDIR /app

# 1. Copy package files
COPY package*.json ./

# 2. Force-install the static adapter inside the container
# This avoids you having to run 'npm install' on your host machine
RUN npm install && npm install -D @sveltejs/adapter-static

# 3. Copy the rest of the code
COPY . .

# 4. Build the app
# Note: You still need to manually edit svelte.config.js once in Cloud9 
# to change 'adapter-auto' to 'adapter-static'
RUN npm run build

# Stage 2: Production (Nginx)
FROM nginx:stable-alpine
# Copy from the 'build' folder created by adapter-static
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
