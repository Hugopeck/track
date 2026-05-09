# Scan Report

> Markdown / Bash / none | 21.1k LOC | 7 modules | ~190.9k tokens

## Size

| Language | Files | Lines |
|----------|------:|------:|
| Markdown | 131 | 11,227 |
| Bash | 40 | 7,736 |
| YAML | 12 | 1,648 |
| Text | 8 | 276 |
| Other | 5 | 204 |
| **Total** | **196** | **21,091** |

## Token Estimates

| Directory | Est. Tokens | % of Total |
|-----------|------------:|-----------:|
| .track/ | 54,165 | 28.4% |
| skills/ | 48,667 | 25.5% |
| tests/ | 34,368 | 18% |
| (root) | 21,101 | 11.1% |
| .github/ | 9,262 | 4.9% |
| growth/ | 8,781 | 4.6% |
| scripts/ | 8,704 | 4.6% |
| docs/ | 5,598 | 2.9% |
| tools/ | 237 | 0.1% |

## Structure

```text
repo-root/ (208 files)
├── .github/ (7 files)
│   └── workflows/ (7 files)
├── .track/ (102 files)
│   ├── plans/ (9 files)
│   ├── projects/ (10 files)
│   ├── scripts/ (12 files)
│   ├── specs/ (4 files)
│   └── tasks/ (65 files)
├── docs/ (1 files)
├── growth/ (18 files)
│   ├── articles/ (2 files)
│   ├── assets/ (1 files)
│   ├── posts/ (8 files)
│   ├── tracking/ (3 files)
│   └── videos/ (3 files)
├── scripts/ (3 files)
│   ├── lib/ (1 files)
│   └── validate/ (2 files)
├── skills/ (31 files)
│   ├── create/ (1 files)
│   ├── decompose/ (1 files)
│   ├── setup-track/ (15 files)
│   ├── todo/ (2 files)
│   ├── update-track/ (1 files)
│   └── work/ (10 files)
├── tests/ (30 files)
│   └── fixtures/ (4 files)
└── tools/ (1 files)
```

## Modules

| Module | Source Files |
|--------|-------------:|
| scripts | 3 |
| skills/create | 1 |
| skills/decompose | 1 |
| skills/setup-track | 12 |
| skills/todo | 2 |
| skills/update-track | 1 |
| skills/work | 10 |

## README Coverage

| Directory | Source Files | Has README |
|-----------|-------------:|------------|
| . | 46 | Yes |
| skills | 15 | Yes |
| skills/work | 9 | No |
| skills/work/scripts | 8 | No |
| tests | 26 | No |

**3 of 5 directories need READMEs**

## Dependencies

| Manifest | Direct Deps | Dev Deps |
|----------|------------:|---------:|
| None found | 0 | 0 |

## Test Footprint

- Test files: 40
- Source files: 20
- Test-to-source ratio: 2.00
- Frameworks: custom bash harness (`tests/run-all.sh`)

## Git Vitals

- Repo age: 2026-04-02 (first commit)
- Total commits: 97
- Contributors: 3
- Last commit: 2026-04-02
- Remote branches: 71

## Signals

- CI workflows: 7
- Docker: none detected
- TODO/FIXME: 141 total (skills/ 47, tests/ 36, .track/ 30, (root) 20, growth/ 8)
- Entry points: 0
- Large files (>1MB): 0
