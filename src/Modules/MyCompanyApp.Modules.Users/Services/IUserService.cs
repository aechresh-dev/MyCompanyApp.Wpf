using MyCompanyApp.Platform.Core.Results;
using MyCompanyApp.Modules.Users.DTOs;
using MyCompanyApp.Modules.Users.Commands;

namespace MyCompanyApp.Modules.Users.Services;

public interface IUserService
{
    Task<Result<UserDto>> CreateUserAsync(CreateUserCommand command);
    Task<Result<List<UserDto>>> GetUsersAsync();
}
