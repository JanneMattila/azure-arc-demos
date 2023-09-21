# Arc-enabled servers

## Resource move

Resource mover enables you to move Arc-enabled servers resources between resource groups and subscriptions.

However, you might get following error messages if they have related resources:

Error code: `ResourceMovePolicyValidationFailed`

Message: `Resource move policy validation failed. Please see details. Diagnostic information: subscription id 'f9054d67-06ae-43ae-ab57-b2ecc30e1a97', request correlation id '49e7a9bf-719e-428c-815e-35b8b4372f91'.`

Details: 

Code: `ResourceReadFailed`
Target: `Microsoft.HybridCompute/Microsoft.HybridCompute/machines/extensions`

```json
{
  "error": {
    "code": "HCRP404",
    "message": "The requested resource was not found.",
    "target": "f9054d67-06ae-43ae-ab57-b2ecc30e1a97/rg-arc-vm/myarcvm/WindowsOpenSSH"
  }
}
```

You might get these per each extension:

- `MDE.Windows`
- `WindowsOpenSSH`
