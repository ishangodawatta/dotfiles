# Development Guidelines

## Git Commit Standards

### Conventional Commit Format
Use these standardized prefixes for all commits:
- `feat:` - new features or functionality
- `fix:` - bug fixes and issue resolutions
- `chore:` - maintenance, dependencies, tooling
- `refactor:` - code restructuring without behavior changes
- `docs:` - documentation updates
- `style:` - formatting, linting fixes
- `test:` - test additions or modifications
- `perf:` - performance improvements
- `build:` - build system changes
- `ci:` - CI/CD configuration updates

### Commit Best Practices
- Keep commits atomic and focused on single logical changes
- Write concise, short messages (50 chars or less for subject line)
- Explain the "why" briefly, not the "what"
- Use imperative mood: "Add feature" not "Added feature"
- Retry commits if pre-commit hooks make changes
- Never commit spec files (*.spec.md, *-spec.md, spec-*.md, etc.) -- these are working documents and should not be checked into version control
- Store spec files in ~/src/specs/ (outside any repo) to avoid accidental commits

## Security Guidelines

### Secrets Management
- Never commit API keys, passwords, tokens, or credentials
- Use environment variables or secure configuration management
- Scan for accidentally committed secrets before pushing
- Remove secrets from git history if accidentally committed using `git-filter-repo`

### Git History Management with git-filter-repo
Use `git-filter-repo` for all Git history rewriting tasks:

**Removing Sensitive Data:**
```bash
# Remove files containing secrets
git filter-repo --path secrets.txt --invert-paths

# Replace sensitive text across all files and commit messages
git filter-repo --replace-text <(echo 'password123==>xxxxxxxx')
```

**Author/Email Updates:**
```bash
# Update contributor information using mailmap
git filter-repo --mailmap .mailmap

# Direct email changes
git filter-repo --email-callback 'if email == b"old@example.com": email = b"new@example.com"'
```

**Commit Message Updates:**
```bash
# Standardize commit messages
git filter-repo --replace-message <(echo 'typo==>corrected')

# Add consistent prefixes
git filter-repo --message-callback 'message = b"[PROJECT] " + message'
```

**Repository Restructuring:**
```bash
# Extract subdirectory as new repository root
git filter-repo --subdirectory-filter frontend/

# Move files to new directory structure
git filter-repo --path-rename old-folder/:new-folder/
```

### Code Security
- Follow security best practices for the language/framework
- Validate all user inputs
- Use parameterized queries for database operations
- Keep dependencies updated and scan for vulnerabilities

## Code Quality Standards

### General Principles
- Follow existing project conventions and patterns
- Prioritize readability and maintainability
- Use consistent naming conventions
- Add comments only when necessary for complex logic
- Prefer composition over inheritance
- Write self-documenting code
- Never use emojis or decorative symbols (✓, ✗, →, ⚠, etc.) in code, comments, or documentation unless explicitly requested
- Keep print statements and console output simple and text-only
- Use plain ASCII characters for all code output and logging

### Testing Requirements
- Write tests for new functionality
- Maintain existing test coverage
- Run full test suite before committing
- Fix failing tests immediately
