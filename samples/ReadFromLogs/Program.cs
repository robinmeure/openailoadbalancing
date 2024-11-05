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

//string simpleQuery = "AppMetrics " +
//    "| where Name == 'Total Tokens'" +
//    "| project Properties['Client IP'], Name, Sum";

string tokenConsumptionQuery = 
    "AppRequests " +
    "| extend consumedTokens = toint(Properties['Response-consumed-tokens'])" +
    "| extend clientId = tostring(Properties['Request-x-client-id'])" +
    "| extend remainingTokens = toint(Properties['Response-remaining-tokens'])" +
    "| extend promptTokens = toint(Properties['Response-prompt-tokens'])" +
    "| extend rateLimitRemainingRequests = toint(Properties['Response-x-ratelimit-remaining-requests'])" +
    "| extend rateLimitRemainingTokens = toint(Properties['Response-x-ratelimit-remaining-tokens'])" +
    "| extend subscriptionName = tostring(Properties['Subscription Name'])" +
    "| project TimeGenerated, clientId, consumedTokens, remainingTokens, promptTokens, rateLimitRemainingRequests, rateLimitRemainingTokens, subscriptionName"+
    "| order by TimeGenerated desc";

Response<LogsQueryResult> response = await client.QueryWorkspaceAsync(
    workspaceId,
    tokenConsumptionQuery,
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