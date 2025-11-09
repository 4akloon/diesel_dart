## Overview
This repository will host an ORM for Dart inspired by Diesel from the Rust ecosystem. The workflow centers on defining database migrations (`up` and `down` steps). After applying migrations, the tool will generate a Dart schema that captures table structures, column types, and relationships. Developers will then create their own strongly typed data classes tied to that schema and use `build_runner`—similar to the `json_serializable` workflow—to generate boilerplate and bindings automatically.

## Project Goals
- Develop the schema format used for describing tables, columns, relations, and metadata.
- Build the foundational ORM engine that interprets the schema and coordinates with the database.
- Design the input data class format for create/update operations with strong typing guarantees.
- Craft a CLI for managing migrations and generating the Dart schema code.
- Implement a type-safe query builder targeting SQL databases, starting with SQLite support.

## Static Typing and SQL Focus
Type safety is a core design constraint: every layer, from migration definitions to generated schema and user-defined models, should leverage Dart’s static typing to prevent runtime surprises. The ORM targets SQL databases, with SQLite as the initial backend to validate the architecture before expanding to additional engines.

## Planned CLI and Tooling
The CLI will orchestrate migrations, inspect database state, and trigger schema generation. Build tooling will ensure data classes stay in sync with their schema definitions, allowing generated code to provide compile-time guarantees about available columns, relationships, and query shapes.

## Roadmap Notes
The items above outline the immediate milestones. As the project matures, expect additional tasks such as integration testing against multiple SQL drivers, documentation, and examples showcasing end-to-end usage from migrations through query execution.
