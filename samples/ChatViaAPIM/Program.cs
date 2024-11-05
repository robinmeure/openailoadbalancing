using Azure;
using Microsoft.Extensions.Configuration;
using Azure.AI.OpenAI;
using OpenAI.Chat;

var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
            .AddJsonFile("appsettings.ignored.json", optional: true, reloadOnChange: true);

IConfigurationRoot configuration = builder.Build();

var endpoint = configuration["OpenAI:EndPoint"];
var key = configuration["OpenAI:Key"];
var deployment = configuration["OpenAI:Deployment"];

if (string.IsNullOrEmpty(key) || string.IsNullOrEmpty(endpoint))
{
    Console.WriteLine("Please provide OpenAI endpoint and key in appsettings.json");
    return;
}

// do magic here to retrieve a clientId or something similar to identify the type of user and their limits (perhaps just a small/medium/large value)
string clientId = "1234";

// setting up a httpclient to pass the clientId as a request header to the APIM -> OpenAI service
var httpClient = new HttpClient();
httpClient.DefaultRequestHeaders.Add("x-client-id", clientId);

// Adding the httpclient to the OpenAI client options
var options = new Azure.AI.OpenAI.AzureOpenAIClientOptions();
if (httpClient != null)
{
    options.Transport = new System.ClientModel.Primitives.HttpClientPipelineTransport(httpClient);
}

var openAIClient = new AzureOpenAIClient(
    new Uri(endpoint),
    new AzureKeyCredential(key),
    options
);

var chatClient = openAIClient.GetChatClient(deployment);
ChatCompletion completion = chatClient.CompleteChat(
[
    // System messages represent instructions or other guidance about how the assistant should behave
    new SystemChatMessage("You are a helpful assistant that talks like a pirate."),
    // User messages represent user input, whether historical or the most recent input
    new UserChatMessage("Hi, can you help me?"),
    // Assistant messages in a request represent conversation history for responses
    new AssistantChatMessage("Arrr! Of course, me hearty! What can I do for ye?"),
    new UserChatMessage("What's the best way to train a parrot?"),
]);

Console.WriteLine($"{completion.Role}: {completion.Content[0].Text}");

