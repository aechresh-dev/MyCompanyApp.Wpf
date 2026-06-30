using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using MyCompanyApp.Domain.Entities;

namespace MyCompanyApp.Application.Services;

public class EntityFieldSettingsService : IEntityFieldSettingsService
{
    public Task<IReadOnlyList<EntityFieldSetting>> GetEnabledFieldsAsync(string entityName, CancellationToken cancellationToken = default)
    {
        IReadOnlyList<EntityFieldSetting> result = new List<EntityFieldSetting>
        {
            new EntityFieldSetting
            {
                EntityName = entityName,
                FieldName = "OptionalDate1",
                DisplayName = "طھط§ط±غŒط® ط³ظپط§ط±ط´غŒ 1",
                FieldType = "Date",
                IsEnabled = true,
                IsVisibleInForm = true,
                IsVisibleInGrid = true,
                IsVisibleInReport = true,
                DisplayOrder = 1
            }
        };

        return Task.FromResult(result);
    }
}
