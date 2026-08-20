FROM node:18-alpine
WORKDIR /app
RUN npm install express mongoose cors
COPY server.js .
EXPOSE 5000
CMD ["node", "server.js"]

