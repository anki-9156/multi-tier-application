# backend/Dockerfile
FROM node:18

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Set default port (can be overridden by environment variable)
ENV PORT=5000

EXPOSE 5000
CMD ["npm", "start"]
