## ORM Research Notes

### Ruby on Rails – Active Record
- **Schema format**: Rails maintains schema state as Ruby DSL in `db/schema.rb`, regenerated after each migration. For database-specific features, teams can opt into `db/structure.sql`, a raw SQL dump. Migrations live under `db/migrate` as timestamped Ruby classes with `up`/`down` or `change` methods.  
  Docs: https://guides.rubyonrails.org/active_record_migrations.html
- **Architecture**: Each model inherits from `ActiveRecord::Base`, binding class name to table name by convention. Querying uses a composable method-chain DSL (`where`, `joins`, `includes`) returning lazy `Relation` objects. The ORM ships with lifecycle callbacks, declarative validations, and association macros (`has_many`, `belongs_to`). Type coercion relies on column metadata supplied by the schema, including support for custom attribute types.  
  Docs: https://guides.rubyonrails.org/active_record_basics.html
- **Tooling**: `rails db:migrate` orchestrates migrations; `rails db:schema:load` rebuilds schema from `schema.rb`; `rails generate model` scaffolds schema and model code together.

### Python – SQLAlchemy
- **Schema format**: SQLAlchemy Core models tables via `Table` objects and metadata. The ORM’s declarative layer wraps that metadata with Python classes using `Column` instances. Alembic, the companion migration tool, stores migration scripts (Python files defining `upgrade`/`downgrade`) plus a version table in the database.  
  Docs: https://docs.sqlalchemy.org/en/latest/orm/declarative_tables.html  
  Alembic: https://alembic.sqlalchemy.org/en/latest/
- **Architecture**: Split between Core (SQL expression language, schema metadata) and ORM (object mapper). The `Session` implements unit-of-work and identity map patterns, tracking pending changes until `commit`. Lazy loading, eager loading strategies, and relationship configuration are explicit via mapper options. Developers can choose pure Core usage, hybrid Core+ORM, or even custom compilation pipelines.  
  Docs: https://docs.sqlalchemy.org/en/latest/orm/session.html
- **Tooling**: `alembic revision --autogenerate` diffing mode reads SQLAlchemy metadata to propose migrations. SQLAlchemy 2.0 emphasises typed constructs and async-friendly patterns.

### Python – Django ORM
- **Schema format**: Models extend `django.db.models.Model` and declare fields (e.g., `models.CharField`). Running `makemigrations` compares model definitions against stored migration state to produce migration modules with operations like `CreateModel`, `AddField`, `AlterField`. A migration graph ensures deterministic ordering and dependency tracking.  
  Docs: https://docs.djangoproject.com/en/stable/topics/migrations/  
  Models: https://docs.djangoproject.com/en/stable/topics/db/models/
- **Architecture**: QuerySets offer lazy evaluation and chainable filters. The ORM integrates with the Django app registry, settings, and form/validation layers. Managers provide custom entry points for queries, while signals and validators add extensibility. Transactions, select-related prefetching, and automatic schema reflection tie directly into the framework’s request lifecycle.  
  Docs: https://docs.djangoproject.com/en/stable/topics/db/queries/
- **Tooling**: `manage.py` commands manage migrations, database inspection, and shell interactions. Third-party packages extend schema fields (e.g., Postgres-specific types).

### Java – Hibernate / JPA
- **Schema format**: JPA annotations (`@Entity`, `@Table`, `@Column`, `@OneToMany`) or XML mapping files describe how Java classes map to tables. Hibernate can auto-generate schema DDL based on mappings (`hibernate.hbm2ddl.auto`) but enterprise teams often rely on Liquibase or Flyway migrations for controlled evolution.  
  Docs: https://docs.jboss.org/hibernate/orm/current/userguide/html_single/Hibernate_User_Guide.html  
  JPA: https://jakarta.ee/specifications/persistence/
- **Architecture**: Implements JPA concepts: `EntityManager`/`Session`, persistence context, unit-of-work, dirty checking, and lazy loading via proxies. Offers HQL/JPQL (object-oriented query language) plus Criteria API (typesafe builder). Integrates with second-level cache providers, transaction managers, and custom type converters.  
  Docs: https://docs.jboss.org/hibernate/stable/core.old/reference/en/html_single/
- **Tooling**: `persistence.xml` or programmatic configuration define datasources. Hibernate Envers extension tracks audit history; Validator integrates bean validation annotations.

### JavaScript/TypeScript – TypeORM
- **Schema format**: Decorator-based entities (`@Entity`, `@Column`, `@PrimaryGeneratedColumn`) leverage `reflect-metadata` to infer types at runtime. Migrations are TypeScript/JavaScript files created via CLI (`typeorm migration:create`) containing `up`/`down` methods using the QueryRunner API. Automatic schema synchronization is available but discouraged for production in favor of versioned migrations.  
  Docs: https://typeorm.io/entities  
  Migrations: https://typeorm.io/migrations
- **Architecture**: Supports both Active Record (methods on entity classes) and Data Mapper (Repositories) patterns. The `DataSource` manages connections and metadata. QueryBuilder provides fluent SQL construction with full type support in TypeScript (when using generics). Relations can be lazy (via proxies) or eager; subscribers and entity listeners handle lifecycle events.  
  Docs: https://typeorm.io/repository-api
- **Tooling**: Works with `ts-node`/`esbuild` pipelines; integrates with class-transformer and class-validator for DTO workflows.

### TypeScript – Prisma
- **Schema format**: Authoritative `schema.prisma` DSL comprises `datasource`, `generator`, and `model` blocks. Models define fields, relations, native types, and attributes (`@id`, `@default`, `@relation`). `prisma migrate` maintains a history folder containing SQL scripts and migration metadata.  
  Docs: https://www.prisma.io/docs/reference/api-reference/prisma-schema-reference  
  Migrations: https://www.prisma.io/docs/concepts/components/prisma-migrate
- **Architecture**: Generates a statically typed Prisma Client tailored to the schema; query methods ensure field-level type safety and `select`/`include` projections. Runtime uses a Rust-written query engine invoked via RPC from Node.js or Deno. Supports nested atomic writes, transactional batching, and relation filters.  
  Docs: https://www.prisma.io/docs/concepts/components/prisma-client
- **Tooling**: `prisma generate` outputs client code; introspection reads existing databases into schema DSL; integrates with `nestjs`, Next.js, and other frameworks.

### Go – GORM
- **Schema format**: Struct fields annotated with tags (e.g., ``gorm:"column:user_name;size:255;uniqueIndex"``) describe schema attributes. `AutoMigrate` inspects struct definitions to create/alter tables. For more control, developers use migrations via `Migrator` API or raw SQL files.  
  Docs: https://gorm.io/docs/models.html  
  Migrations: https://gorm.io/docs/migration.html
- **Architecture**: Chainable methods operate on a `gorm.DB` instance. Includes association handling (`Preload`, `Association`), hooks (`BeforeCreate`, `AfterSave`), soft deletes, and polymorphism options. Embraces Go idioms like context propagation, error-first returns, and struct embedding (`gorm.Model`). Prepared statement caching and batch operations are built in.  
  Docs: https://gorm.io/docs/
- **Tooling**: Supports plugins (e.g., for Prometheus metrics), logger customization, and dialects for PostgreSQL, MySQL, SQLite, SQL Server.

### C# – Entity Framework Core
- **Schema format**: POCO entity classes paired with either data annotations (attributes) or Fluent API in `OnModelCreating`. Migrations are generated via `dotnet ef migrations add`, producing C# classes with `Up`/`Down` methods plus a model snapshot to detect future diffs. EF can reverse-engineer models from existing databases (`dotnet ef dbcontext scaffold`).  
  Docs: https://learn.microsoft.com/ef/core/modeling/  
  Migrations: https://learn.microsoft.com/ef/core/managing-schemas/migrations/
- **Architecture**: `DbContext` encapsulates database connection, change tracker, and LINQ query translation pipeline. LINQ expressions compile to provider-specific SQL via expression tree visitors. Supports eager/lazy/explicit loading, concurrency tokens, value converters, owned entity types, and compiled queries for performance.  
  Docs: https://learn.microsoft.com/ef/core/querying/
- **Tooling**: Works across .NET platforms with provider model (SQL Server, SQLite, PostgreSQL, etc.). Design-time services enable code generation and CLI integration.

### Common Themes
- **Declarative schemas**: Across ecosystems, schema definitions live alongside code—Ruby DSLs, Python classes, annotations, or dedicated DSLs—feeding generators and migration diff tools.
- **Migration workflows**: Versioned migration artifacts (`up`/`down` functions, SQL scripts) paired with revision tables keep databases synchronized. Automation ranges from diffing metadata (Alembic autogenerate, EF snapshots) to fully manual SQL.
- **Runtime architecture**: Most ORMs implement identity maps, unit-of-work batching, and lazy loading. Query abstractions vary from fluent builders (TypeORM, GORM) to expression trees (EF) and generated clients (Prisma).
- **Type safety spectrum**: Statically typed languages lean on generics/annotations to infer field types; Prisma and EF push compile-time guarantees end-to-end, whereas Rails/Django rely on runtime validation but increasingly offer Sorbet/MyPy support.
- **Ecosystem tooling**: CLI commands scaffold models, run migrations, and introspect databases. Code generation (Prisma client, EF scaffolding, Rails scaffolds) accelerates schema-to-code workflows—a pattern worth mirroring for a Dart ORM.

