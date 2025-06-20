# Contributing to Azure Tag Manager

Thank you for your interest in contributing to Azure Tag Manager! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature or bugfix
4. Make your changes
5. Test thoroughly
6. Submit a pull request

## Development Setup

### Prerequisites
- PowerShell 5.1 or later
- Azure PowerShell module (`Install-Module Az`)
- Azure subscription with appropriate permissions

### Testing Your Changes
Before submitting a pull request:

1. Test all modified scripts
2. Verify compliance scanning works correctly
3. Test remediation in WhatIf mode
4. Ensure no breaking changes to existing functionality

## Code Style Guidelines

### PowerShell Conventions
- Use approved PowerShell verbs for function names
- Follow PascalCase for function names
- Use descriptive parameter names
- Include help documentation for all functions
- Use Write-Verbose for debug output

### Module Structure
- Keep modules focused on single responsibilities
- Export only necessary functions
- Include error handling for all external calls
- Use consistent parameter validation

## Submitting Changes

### Pull Request Process
1. Ensure your code follows the style guidelines
2. Update documentation as needed
3. Add tests for new functionality
4. Submit a pull request with a clear description

### Pull Request Template
Please include:
- Description of changes
- Type of change (bugfix, feature, documentation)
- Testing performed
- Any breaking changes

## Reporting Issues

When reporting issues, please include:
- PowerShell version
- Azure PowerShell module version
- Steps to reproduce
- Expected vs actual behavior
- Any error messages

## Feature Requests

Feature requests are welcome! Please:
- Check existing issues first
- Provide detailed use case description
- Explain why the feature would be valuable
- Consider implementation complexity

## Code of Conduct

This project follows a simple code of conduct:
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain professional communication

## Questions?

Feel free to open an issue for any questions about contributing!
