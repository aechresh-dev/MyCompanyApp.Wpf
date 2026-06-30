namespace MyCompanyApp.Platform.Core.Results;

public class Result<T> : Result
{
    public T? Value { get; }

    protected Result(T? value, bool isSuccess, string? error)
        : base(isSuccess, error)
    {
        Value = value;
    }

    public static Result<T> Success(T value)
        => new(value, true, null);

    public new static Result<T> Fail(string error)
        => new(default, false, error);
}
