# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build

WORKDIR /app/frontend
COPY frontend/pubspec.* ./
RUN flutter pub get
COPY frontend/ .
RUN flutter build web --release --dart-define=API_BASE_URL=

# Stage 2: Build Dart backend
FROM dart:stable AS dart-build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY lib/ lib/
COPY bin/ bin/
COPY schema.config .
RUN dart compile exe bin/server.dart -o bin/server

# Stage 3: Runtime
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=dart-build /app/bin/server /app/bin/server
COPY --from=dart-build /app/schema.config /app/schema.config
COPY --from=flutter-build /app/frontend/build/web /app/web
RUN mkdir -p /app/uploads

EXPOSE 8080
ENV PORT=8080
CMD ["/app/bin/server"]
