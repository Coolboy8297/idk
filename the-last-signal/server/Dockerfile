FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=8787
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY index.js ./
USER node
EXPOSE 8787
CMD ["node", "index.js"]
