# Dragonbane Character Creator

A Swift-based command-line tool and library for generating and managing Dragonbane tabletop RPG characters using OpenAI APIs, with optional portrait image generation.

## Components

- **DragonbaneCharacterCore**: Core library defining the `Character` model and random generation helpers shared by both executables.
- **DragonbaneCharacterCLI**: Executable CLI for generating characters, querying saved characters, printing statistics, and generating character images.
- **DragonbaneCharacterPersistence**: GRDB/SQLite helpers used exclusively by the CLI to persist characters and images locally.
- **DragonbaneCharacterServer**: Vapor-based REST API and web UI backed by PostgreSQL for browsing, creating, and editing Dragonbane characters.

## Requirements

- Swift tools version 6.0 or later
- macOS 10.15+ (Linux support for the CLI has not been tested)
- Docker (24+) and Docker Compose v2 or Podman 4.9+ with podman-compose for running the web service locally

## Installation

Clone the repository and build:
```bash
git clone https://github.com/your-username/DragonbaneCharacterCreator.git
cd DragonbaneCharacterCreator
swift build -c release
```

You can also run directly without building:
```bash
swift run DragonbaneCharacterCLI [options]
```

## Configuration

The CLI is configured via command-line flags or environment variables:

- `--server`, `-s`: OpenAI server URL. Defaults to `http://192.168.86.220:1234` or the value of `OPENAI_SERVER`.
- `--api-key`, `-k`: OpenAI API key. Defaults to value of `OPENAI_API_KEY`.
- `--model`, `-m`: Model name for chat completions. Defaults to `deepseek-r1-distill-qwen-7b` or `OPENAI_MODEL`.

## Web Service & UI

The `DragonbaneCharacterServer` target exposes a REST API and static web UI for managing characters without invoking the OpenAI-powered embellishment pipeline. Characters generated through the service rely on the offline narrative helpers added to `DragonbaneCharacterCore`.

### Quick start with Docker/Podman Compose

```bash
# Docker
docker compose up --build

# Podman
podman-compose up --build
```

This builds the Swift server, provisions PostgreSQL 16, runs the Fluent migrations, and serves the UI at <http://localhost:8080>. Credentials can be customised through the `POSTGRES_*` environment variables in `docker-compose.yml`. Podman users do not need any additional changes because all container images are now referenced by their fully-qualified registry names, and the Dockerfile uses the stable `swift:6.0-jammy` base image.

### Manual execution

To run without Docker you must provide connection details for an existing PostgreSQL instance:

```bash
createdb dragonbane
export POSTGRES_HOST=localhost
export POSTGRES_DB=dragonbane
export POSTGRES_USER=your_user
export POSTGRES_PASSWORD=your_password
swift run DragonbaneCharacterServer
```

The server listens on port `8080` by default. Override with the `PORT` environment variable as needed.

### REST endpoints

| Method | Path | Description |
| ------ | ---- | ----------- |
| `GET`  | `/api/characters` | List recent characters (supports `kin`, `profession`, and `limit` query parameters). |
| `GET`  | `/api/characters/random` | Retrieve a random character, optionally constrained by kin/profession filters. |
| `POST` | `/api/characters/generate` | Generate, persist, and return a new character. Accepts optional `race`, `profession`, `age`, `name`, `appearance`, and `background` overrides. |
| `GET`  | `/api/characters/:id` | Fetch a single character by identifier. |
| `PUT`  | `/api/characters/:id` | Update stored character fields (e.g. name, appearance, background, weakness, memento, gear). |

The bundled front-end (`Public/index.html`) consumes these endpoints to deliver three workflows: draw a random entry, generate a new one, and edit an existing record.

## Usage

### Generate Characters

```bash
# Generate one character (default)
DragonbaneCharacterCLI

# Generate five characters
DragonbaneCharacterCLI --count 5

# Override server, key, and model
DragonbaneCharacterCLI --count 1 \ 
  --server https://api.openai.com \ 
  --api-key "$OPENAI_API_KEY" \ 
  --model gpt-4
```

### Inspect Saved Characters

```bash
# Print a random saved character
DragonbaneCharacterCLI --random

# Print database statistics
DragonbaneCharacterCLI --stats

# Print a specific character by ID
DragonbaneCharacterCLI --print-id 3
```

### Generate Character Portrait

```bash
# Generate and store a WebP portrait for character ID 3
DragonbaneCharacterCLI --image-id 3
```

This will:
- Call the OpenAI Images API (`model: gpt-image-1`, `quality: low`, `output_format: webp`).
- Store the WebP image blob in the `image` table (associated with the character ID).
- Write the image file to the current directory as `character_<characterId>_image_<imageRecordId>.webp`.

## Database Location

### CLI (SQLite)

On macOS, the CLI stores its SQLite database at:
```
~/Library/Application Support/Dragonbane/dragonbane.sqlite
```

Two tables are used:
- `character`: stores generated character data (attributes, appearance, background, etc.)
- `image`: stores WebP image blobs tied to `characterId`

### Web service (PostgreSQL)

The Vapor server uses PostgreSQL (default database name `dragonbane`). Tables are created automatically via Fluent migrations the first time the service starts.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.
