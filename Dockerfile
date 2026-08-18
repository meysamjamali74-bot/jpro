FROM node:22-bookworm-slim
WORKDIR /app
COPY apps/api/package*.json ./apps/api/
RUN cd apps/api && npm install --omit=dev
COPY apps/api ./apps/api
COPY apps/web ./apps/web
COPY database ./database
ENV NODE_ENV=production
EXPOSE 8080
CMD ["node", "apps/api/src/server.js"]
