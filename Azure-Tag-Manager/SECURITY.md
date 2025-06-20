# Security Policy

## Supported Versions

We support the latest version of Azure Tag Manager with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 1.2.x   | :white_check_mark: |
| 1.1.x   | :white_check_mark: |
| < 1.1   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** create a public GitHub issue
2. Send details to the repository maintainers privately
3. Include steps to reproduce the vulnerability
4. Provide any relevant environment details

## Security Considerations

### Azure Permissions
- Use principle of least privilege
- Grant only necessary Azure RBAC roles
- Consider using Azure Managed Identity when possible

### Authentication
- Never hardcode credentials in scripts
- Use Azure PowerShell's secure authentication methods
- Regularly rotate service principal secrets if used

### Data Handling
- Reports may contain sensitive resource information
- Secure storage of generated compliance reports
- Consider data retention policies for scan results

### Network Security
- Scripts communicate with Azure Resource Manager APIs
- Ensure proper network security controls
- Consider private endpoints for sensitive environments

## Best Practices

1. **Regular Updates**: Keep Azure PowerShell modules updated
2. **Access Review**: Regularly review who has access to run these scripts
3. **Audit Logs**: Monitor script execution through Azure Activity Logs
4. **Testing**: Test security configurations in non-production first

## Disclaimer

This tool is provided as-is for Azure governance purposes. Users are responsible for:
- Proper authentication and authorization
- Compliance with organizational security policies
- Secure handling of generated reports
- Regular security assessments of their implementation
