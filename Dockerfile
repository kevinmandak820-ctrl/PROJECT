FROM node:20-alpine

WORKDIR /app

# Install dependencies for Backend service
COPY Backend/package*.json ./
RUN npm install --omit=dev

# Copy backend application source code
COPY Backend/ ./

# Expose server port (Railway dynamically injects PORT)
ENV PORT=3000
EXPOSE 3000

# Start production server
CMD ["node", "index.js"]
