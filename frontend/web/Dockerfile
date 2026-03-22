FROM node:20-slim

WORKDIR /app

# Node deps
COPY package.json ./
RUN npm install 2>/dev/null || echo "No package.json deps yet"

COPY . .

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
