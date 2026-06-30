# GitHub Repository Integration
Project: MyCompanyApp.Wpf

Repository Information
--------------------------------------------------
Repository URL
https://github.com/aechresh-dev/MyCompanyApp.Wpf

Default Branch
main

Remote Name
origin

Repository Type
Private / Development Repository

--------------------------------------------------

Purpose of Repository
--------------------------------------------------

This repository stores the complete source code of the
MyCompanyApp.Wpf enterprise application.

The repository is used for:

• Source Code Version Control
• Architecture Tracking
• Documentation
• CI/CD Pipelines
• Release Management
• Issue Tracking

--------------------------------------------------

Project Architecture Stored in Repository
--------------------------------------------------

Solution Structure

MyCompanyApp.sln

src/
    MyCompanyApp.Domain
    MyCompanyApp.Application
    MyCompanyApp.Infrastructure
    MyCompanyApp.Persistence
    MyCompanyApp.Wpf

Modules/
    Users
    Reports
    Dashboard
    Leave

docs/
    Roadmaps
    Architecture
    Development Guides

tools/
scripts/

--------------------------------------------------

Git Workflow
--------------------------------------------------

Primary Branch
main

Commit Strategy
Feature commits with descriptive messages.

Versioning
Semantic Versioning (SemVer)

Example

v0.1.0
v0.2.0
v1.0.0

--------------------------------------------------

CI/CD (Planned)
--------------------------------------------------

GitHub Actions will automate:

• Build
• Tests
• Artifact Packaging
• Release Creation
• Installer Generation

--------------------------------------------------

Notes
--------------------------------------------------

Large files such as installers, runtime packages,
and compiled outputs are excluded from the repository
via .gitignore.

Installer artifacts will be generated during the
CI/CD pipeline instead of being stored in Git.

--------------------------------------------------

Created
06/30/2026 21:49:15

Author
Project Developer
