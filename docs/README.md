# Documentation Guide

This repository has three documentation and presentation layers:

- `docs/`: maintainer and contributor documentation
- `docs/superpowers/`: design specs and implementation plans for agentic work
- `website/`: static landing page source for the public website

## Maintainer docs

Use `docs/` for:

- build and test workflows
- release and packaging notes
- architecture details
- internal feature planning

## Website

Use `website/` for the public Argo landing page. The first version is a no-build static site:

- `website/index.html`: single-page product content
- `website/styles.css`: Aurora Terminal visual system and responsive layout
- `website/assets/app-icon.png`: copied app icon
- `website/assets/hero-workspace.png`: replaceable hero screenshot

When the app UI changes, replace `website/assets/hero-workspace.png` with a new screenshot and keep the file path stable.
