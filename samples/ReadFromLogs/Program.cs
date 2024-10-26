//  This sample is documented here
// https://learn.microsoft.com/en-us/dotnet/api/overview/azure/monitor.query-readme?view=azure-dotnet


using Azure;
using Azure.Identity;
using Azure.Monitor.Query;
using Azure.Monitor.Query.Models;
using Microsoft.Extensions.Configuration;

var client = new LogsQueryClient(new DefaultAzureCredential());

var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
            .AddJsonFile("appsettings.ignored.json", optional: true, reloadOnChange: true);

IConfigurationRoot configuration = builder.Build();

var workspaceId = configuration["Workspace:Id"];

Response<LogsQueryResult> response = await client.QueryWorkspaceAsync(
    workspaceId,
    "AppMetrics " +
    "| where Name == 'Total Tokens'" +
    "| project Properties['Client IP'], Name, Sum",
    new QueryTimeRange(TimeSpan.FromDays(31)));

//get the response table
LogsTable table = response.Value.Table;

//write fields
foreach (var column in table.Columns)
{
    Console.Write(column.Name + ";");
}

Console.WriteLine();

//write values
var columnCount = table.Columns.Count;
foreach (var row in table.Rows)
{
    for (int i = 0; i < columnCount; i++)
    {
        Console.Write(row[i] + ";");
    }

    Console.WriteLine();
}