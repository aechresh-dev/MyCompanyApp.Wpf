using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using MyCompanyApp.Persistence.Database;

namespace MyCompanyApp.Persistence;

public sealed class DesignTimeMyCompanyDbContextFactory : IDesignTimeDbContextFactory<MyCompanyDbContext>
{
    public MyCompanyDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<MyCompanyDbContext>();

        optionsBuilder.UseSqlite(@"Data Source=G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\data\mycompanyapp.db");

        return new MyCompanyDbContext(optionsBuilder.Options);
    }
}
