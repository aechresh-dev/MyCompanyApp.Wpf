namespace MyCompanyApp.Platform.Core.Errors;

public enum ErrorCode
{
    Unknown = 0,

    ValidationError = 100,
    NotFound = 101,
    Conflict = 102,
    Unauthorized = 103,
    Forbidden = 104,
    OperationFailed = 105
}
