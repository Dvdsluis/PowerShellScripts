# Results Directory

This directory contains generated compliance scan reports and remediation logs.

## Folder Structure

Reports are automatically organized by timestamp:

```
Results/
└── Compliance_YYYYMMDD_HHMMSS/
    ├── SubscriptionName_EnvCompliance_YYYYMMDD_HHMMSS.csv
    ├── AnotherSubscription_EnvCompliance_YYYYMMDD_HHMMSS.csv
    └── ScanSummary_YYYYMMDD_HHMMSS.txt
```

## Report Types

- **Compliance CSV**: Detailed per-resource compliance analysis
- **Summary Text**: High-level statistics and overview
- **Remediation Logs**: Changes applied during tag remediation

## File Naming Convention

- Timestamp format: `YYYYMMDD_HHMMSS`
- Subscription-specific reports include subscription name
- All files within a scan session share the same timestamp
