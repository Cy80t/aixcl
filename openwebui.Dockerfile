FROM node:20 AS build
WORKDIR /app
RUN git clone https://github.com/open-webui/open-webui.git .
RUN npm install --prefix frontend
RUN npm run build --prefix frontend

FROM python:3.11-slim
WORKDIR /app
RUN pip install open-webui
COPY --from=build /app/frontend/dist /app/frontend
ENV FRONTEND_BUILD_DIR=/app/frontend
CMD ["open-webui"]
