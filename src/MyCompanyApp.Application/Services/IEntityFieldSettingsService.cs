using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using MyCompanyApp.Domain.Entities;

namespace MyCompanyApp.Application.Services;

public interface IEntityFieldSettingsService
{
    Task<IReadOnlyList<EntityFieldSetting>> GetEnabledFieldsAsync(string entityName, CancellationToken cancellationToken = default);
}
