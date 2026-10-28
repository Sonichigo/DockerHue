FROM node:22-alpine
LABEL dockerhue.lang=node
WORKDIR /app
COPY server.js .
USER node
EXPOSE 8080
CMD ["node", "server.js"]
