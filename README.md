# Dragonbane Character Creator

A Swift-based command-line tool and library for generating and managing Dragonbane tabletop RPG characters using OpenAI APIs, with optional portrait image generation.

## Components

- **DragonbaneCharacterCore**: Core library defining the `Character` model, database schema, and persistence layer using SQLite via GRDB.
- **DragonbaneCharacterCLI**: Executable CLI for generating characters, querying saved characters, printing statistics, and generating character images.

## Requirements

- Swift tools version 6.1 or later
- macOS 10.15+ (Linux support has not been tested)

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

On macOS, the SQLite database is located at:
```
~/Library/Application Support/Dragonbane/dragonbane.sqlite
```

Two tables are used:
- `character`: stores generated character data (attributes, appearance, background, etc.)
- `image`: stores WebP image blobs tied to `characterId`

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.