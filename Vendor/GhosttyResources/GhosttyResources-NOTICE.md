# Ghostty Runtime Resources

This directory contains Ghostty shell integration, theme, and terminfo resources
that are packaged with Argo at build time.

The Xcode `Copy Ghostty Resources` phase copies these files into the app bundle
from `Argo/Vendor/GhosttyResources` so runtime behavior stays unchanged while
vendored text is kept outside Argo-specific source measurements.
