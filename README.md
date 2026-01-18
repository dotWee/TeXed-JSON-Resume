# JSON Resume LaTeX Package

A minimal LuaLaTeX package for rendering [JSON Resume](https://jsonresume.org/) data into clean, professional resumes.

## Features

- **Full JSON Resume Schema Support**: All 12 sections (basics, work, volunteer, education, awards, certificates, publications, skills, languages, interests, references, projects)
- **Load from File or URL**: Local JSON files or remote URLs
- **Schema Validation**: Strict mode warns about schema violations
- **Clean FAANG-style Formatting**: Professional typography with no distracting design elements
- **Customizable Section Titles**: Override default section headers

## Requirements

- **LuaLaTeX** (part of TeX Live or MiKTeX)
- **curl** (for URL loading, pre-installed on most systems)

## Installation

1. Copy `jsonresume.sty` and `jsonresume.lua` to your project directory, or
2. Install to your local texmf tree:
   ```bash
   mkdir -p ~/texmf/tex/latex/jsonresume
   cp jsonresume.sty jsonresume.lua ~/texmf/tex/latex/jsonresume/
   ```

## Quick Start

```latex
\documentclass[11pt,letterpaper]{article}
\usepackage[margin=0.5in]{geometry}
\usepackage{jsonresume}

\begin{document}

% Load from URL
\resumefromurl{https://example.com/resume.json}

% Or load from local file
% \resumefromfile{resume.json}

% Render all sections
\renderresume

\end{document}
```

Compile with:
```bash
lualatex --shell-escape yourfile.tex
```

## Commands

### Loading Data

| Command | Description |
|---------|-------------|
| `\resumefromfile{path}` | Load resume from a local JSON file |
| `\resumefromurl{url}` | Load resume from a remote URL |

### Rendering Sections

| Command | Description |
|---------|-------------|
| `\renderresume` | Render all available sections in standard order |
| `\renderresumecore` | Render core sections only (basics, work, education, skills) |
| `\resumebasics` | Render name, contact info, and summary |
| `\resumework[title]` | Render work experience |
| `\resumevolunteer[title]` | Render volunteer experience |
| `\resumeeducation[title]` | Render education |
| `\resumeawards[title]` | Render awards and honors |
| `\resumecertificates[title]` | Render certifications |
| `\resumepublications[title]` | Render publications |
| `\resumeskills[title]` | Render skills |
| `\resumelanguages[title]` | Render languages |
| `\resumeinterests[title]` | Render interests |
| `\resumereferences[title]` | Render references |
| `\resumeprojects[title]` | Render projects |

### Validation Commands

| Command | Description |
|---------|-------------|
| `\resumevalidate` | Manually trigger validation |
| `\resumevalidationsummary` | Print validation summary to document |
| `\resumewarningcount` | Get number of validation warnings |

### Data Access (Advanced)

| Command | Description |
|---------|-------------|
| `\jrget{path}` | Get a value using dot notation (e.g., `\jrget{basics.name}`) |
| `\jrifexists{path}{yes}{no}` | Conditional based on path existence |

## Package Options

### Strict Mode

Enable strict mode to get warnings about schema violations:

```latex
\usepackage[strict]{jsonresume}
```

In strict mode, the package warns about:
- Unknown top-level sections
- Missing required fields (e.g., `basics.name`)
- Invalid date formats (should be YYYY, YYYY-MM, or YYYY-MM-DD)
- Invalid URL formats
- Type mismatches (e.g., string instead of array)

Warnings appear in the LaTeX log file and can be reviewed after compilation.

## Custom Layout Example

```latex
\documentclass[11pt]{article}
\usepackage[strict]{jsonresume}

\begin{document}
\resumefromfile{resume.json}

% Custom order and titles
\resumebasics
\resumeskills[Technical Expertise]
\resumework[Professional Experience]
\resumeprojects[Side Projects]
\resumeeducation[Academic Background]
\resumecertificates[Professional Certifications]
\resumelanguages

\end{document}
```

## JSON Resume Format

This package supports the full [JSON Resume schema](https://jsonresume.org/schema/). Example:

```json
{
  "basics": {
    "name": "Jane Doe",
    "label": "Software Engineer",
    "email": "jane@example.com",
    "phone": "+1-555-123-4567",
    "url": "https://janedoe.dev",
    "summary": "Experienced engineer...",
    "location": {
      "city": "San Francisco",
      "region": "CA",
      "countryCode": "US"
    },
    "profiles": [
      {"network": "GitHub", "username": "janedoe", "url": "https://github.com/janedoe"}
    ]
  },
  "work": [
    {
      "name": "Company",
      "position": "Engineer",
      "startDate": "2020-01",
      "highlights": ["Built things", "Led teams"]
    }
  ],
  "education": [...],
  "skills": [...],
  "volunteer": [...],
  "awards": [...],
  "certificates": [...],
  "publications": [...],
  "languages": [...],
  "interests": [...],
  "references": [...],
  "projects": [...]
}
```

## Running Tests

```bash
cd tests
./run-tests.sh

# Skip network tests (URL loading)
./run-tests.sh --skip-network
```

## Development

### Building Locally

Build the CTAN package locally:

```bash
./scripts/build-ctan.sh 1.0.0
```

This creates:
- `dist/jsonresume.zip` - Package for manual installation
- `dist/jsonresume-ctan.zip` - Package for CTAN submission

### Continuous Integration

The project uses GitHub Actions for CI/CD:

- **CI workflow** (`ci.yml`): Runs tests on every push and PR
- **Release workflow** (`release.yml`): Creates releases when tags are pushed

### Creating a Release

#### Prerequisites

The release workflow requires the following GitHub repository secrets for automatic CTAN submission:

- `CTAN_UPLOADER_NAME` - Your name as the CTAN uploader
- `CTAN_EMAIL` - Your email address for CTAN correspondence

To add these secrets:
1. Go to your repository Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Add both `CTAN_UPLOADER_NAME` and `CTAN_EMAIL`

#### Release Steps

1. Update the version in `jsonresume.sty` if needed
2. Commit all changes
3. Create and push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. The release workflow will automatically:
   - Run tests
   - Build the example PDF
   - Create CTAN package
   - Create a GitHub release with all artifacts
   - Submit the package to CTAN automatically

## Publishing to CTAN

### Automatic Submission (Recommended)

The release workflow automatically submits packages to CTAN when a new version tag is pushed. This requires:

1. **GitHub Secrets Configured** - `CTAN_UPLOADER_NAME` and `CTAN_EMAIL` must be set in repository settings
2. **Package Already on CTAN** - The automatic submission uses `update: "true"` for existing packages

When you create a release (see "Creating a Release" above), the workflow will:
- Build the CTAN package
- Create a GitHub release
- Automatically submit to CTAN with the configured credentials

**Note**: For first-time CTAN submissions, you'll need to use the manual process below to provide additional metadata (author, license, topics, etc.).

### Manual Submission

If you need to submit manually (e.g., first-time submission or to provide additional metadata):

#### Prerequisites

Before submitting to CTAN, ensure:

1. **Package is stable** - All tests pass
2. **Documentation is complete** - README covers all features
3. **License is clear** - MIT license file included
4. **Example works** - Example PDF generates correctly

#### Submission Steps

1. **Build the CTAN package**:
   ```bash
   ./scripts/build-ctan.sh 1.0.0
   ```

2. **Go to CTAN Upload**: https://ctan.org/upload

3. **Fill in the submission form**:

   | Field | Value |
   |-------|-------|
   | **Package name** | `jsonresume` |
   | **Summary** | LuaLaTeX package for rendering JSON Resume data |
   | **Description** | A LuaLaTeX package that parses JSON Resume files (local or remote URL) and renders professional resumes. Supports the full JSON Resume schema with 12 sections, schema validation, and customizable formatting. |
   | **Author** | Your name and email |
   | **License** | MIT |
   | **CTAN directory** | `/macros/luatex/latex/jsonresume` |
   | **Topics** | `curriculum-vitae`, `luatex`, `json` |
   | **Home page** | Your GitHub repository URL |
   | **Bug tracker** | Your GitHub issues URL |
   | **Repository** | Your GitHub repository URL |

4. **Upload the package**: Select `dist/jsonresume-ctan.zip`

5. **Submit and wait**: CTAN volunteers will review your submission (usually 1-3 days)

### After CTAN Acceptance

Once accepted on CTAN:

1. The package will be available at `https://ctan.org/pkg/jsonresume`
2. It will be included in TeX Live and MiKTeX updates
3. Users can install via their TeX distribution's package manager

### Updating the Package

For updates, the automatic submission will handle CTAN updates when you create a new release:

1. Increment version number in `jsonresume.sty`
2. Create and push a new git tag (e.g., `v1.1.0`)
3. The release workflow automatically submits the update to CTAN

For manual updates:
1. Build the package with `./scripts/build-ctan.sh <version>`
2. Go to https://ctan.org/upload
3. In the upload form, select "Update" instead of "New package"

## License

Copyright (c) 2026 Lukas Wolfsteiner <lukas@wolfsteiner.media>

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
