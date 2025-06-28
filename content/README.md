# Drupal Content Directory

This directory contains static content files that will be deployed to EFS and served by Drupal.

## Structure

- `files/` - Public files accessible via web
- `private/` - Private files (requires authentication)

## Usage

Place your static content files in the appropriate subdirectory:

- **Public files**: Place in `files/` directory
  - Images, documents, videos, etc.
  - Accessible via: `https://your-domain.com/sites/default/files/`

- **Private files**: Place in `private/` directory
  - Sensitive documents, user uploads, etc.
  - Requires authentication to access

## Deployment

Content in this directory will be automatically deployed to EFS when you run the CodeBuild content deployment project.

## Permissions

Files will be automatically set with proper permissions for the Apache user (UID/GID 48).