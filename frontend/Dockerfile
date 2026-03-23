FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
# Use the dev command as specified in the lab 
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]