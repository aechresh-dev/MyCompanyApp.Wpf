using Microsoft.Extensions.Logging;
using MyCompanyApp.Platform.Core.Services;
using MyCompanyApp.Platform.Core.Results;
using MyCompanyApp.Platform.Core.Guards;
using MyCompanyApp.Modules.Users.DTOs;
using MyCompanyApp.Modules.Users.Commands;

namespace MyCompanyApp.Modules.Users.Services;

public sealed class UserService : ServiceBase<UserService>, IUserService
{
    private static readonly List<UserDto> _users = new();

    public UserService(
        ILogger<UserService> logger,
        IClock clock,
        ICurrentUserService currentUser)
        : base(logger, clock, currentUser)
    {
    }

    public Task<Result<UserDto>> CreateUserAsync(CreateUserCommand command)
    {
        Guard.AgainstNull(command, nameof(command));
        Guard.AgainstNullOrWhiteSpace(command.Username, nameof(command.Username));

        var user = new UserDto
        {
            Id = Guid.NewGuid(),
            Username = command.Username,
            DisplayName = command.DisplayName,
            CreatedAt = Clock.UtcNow
        };

        _users.Add(user);

        Logger.LogInformation("User created {Username}", user.Username);

        return Task.FromResult(Result<UserDto>.Success(user));
    }

    public Task<Result<List<UserDto>>> GetUsersAsync()
    {
        return Task.FromResult(Result<List<UserDto>>.Success(_users));
    }
}
