using System;

namespace MyCompanyApp.Platform.Core.Errors;

public class AppException : Exception
{
    public ErrorCode Code { get; }
    public string? Details { get; }

    public AppException(ErrorCode code, string message, string? details = null)
        : base(message)
    {
        Code = code;
        Details = details;
    }
}
