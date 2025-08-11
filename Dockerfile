
FROM node:20-alpine AS builder
WORKDIR /app

# Install deps (include dev for TypeScript build)
COPY package*.json ./
RUN npm ci --include=dev

# Copy source and build
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Install only production deps
COPY package*.json ./
RUN npm ci --omit=dev

# Copy built app
COPY --from=builder /app/dist ./dist

# If you need non-compiled assets, copy them here as well
# COPY --from=builder /app/sql ./sql

# Cloud Run expects the service to listen on $PORT
ENV PORT=8080
EXPOSE 8080

CMD ["node", "dist/server.js"]


