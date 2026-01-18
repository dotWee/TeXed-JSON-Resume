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

## License

Copyright (c) 2026 Lukas Wolfsteiner <lukas@wolfsteiner.media>

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
