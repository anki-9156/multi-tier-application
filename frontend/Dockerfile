FROM node:18-alpine as builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Build arguments for environment variables
ARG REACT_APP_API_URL
ARG GENERATE_SOURCEMAP=false
ARG REACT_APP_ENV=production

# Set environment variables for build
ENV REACT_APP_API_URL=$REACT_APP_API_URL
ENV GENERATE_SOURCEMAP=$GENERATE_SOURCEMAP
ENV REACT_APP_ENV=$REACT_APP_ENV

RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
