# Imagen deliberadamente antigua para que el laboratorio tenga un hallazgo
# reproducible relacionado con software fuera de soporte (EOL).
FROM node:16-alpine

WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --omit=dev
COPY server.js ./

EXPOSE 9090
CMD ["node", "server.js"]
