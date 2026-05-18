# CMS / Collaboration Tools

A schema-driven collaboration tool with kanban boards, sprints, documents, and project hierarchy. The backend is a generic property graph engine with no hardcoded entity types — `schema.config` is the single source of truth that drives both the Dart/Shelf HTTP API and the Flutter web frontend.

## Tech Stack
- Backend: Dart (Shelf HTTP, PostgreSQL via Docker)
- Frontend: Flutter web (Riverpod state management, GoRouter navigation)
- Database: PostgreSQL (port 5433 locally)
- Deploy: GCP Cloud Run (multi-stage Docker build)

## Setup
```bash
docker-compose up -d
dart pub get
DATABASE_URL=postgresql://outlier:outlier@localhost:5433/outlier dart run bin/server.dart

# Frontend (from frontend/)
flutter pub get
flutter run -d chrome
```

## License
MIT
