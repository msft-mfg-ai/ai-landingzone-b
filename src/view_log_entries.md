# Log Entries Queries

## App Log Entries

``` sql
ContainerAppConsoleLogs_CL 
| project DTS=TimeGenerated, Container=ContainerName_s, LogEntry=Log_s
| sort by DTS desc
| limit 500
```

## System Log Entries

``` sql
ContainerAppSystemLogs_CL 
| project DTS=TimeGenerated, Reason=Reason_s, Container=ContainerAppName_s, Source=EventSource_s, Level, LogEntry=Log_s
| sort by DTS desc
| limit 500
```
