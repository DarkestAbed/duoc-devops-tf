FROM node:18-alpine
WORKDIR /app
COPY package.json .
COPY server.js .
RUN npm install --production
EXPOSE 3001
CMD ["node","server.js"]