# Define the API key and endpoint
$apiKey = ""
$endpoint = "https://apim-ai-gateway-.azure-api.net/openai/deployments/gpt/chat/completions?api-version=2024-06-01"
$clientId = '7890'

# Define the JSON body
$body = @{
    messages = @(
        @{
            role = "system"
            content = "You are a helpful assistant that talks like a pirate."
        },
        @{
            role = "user"
            content = "Hi, can you help me?"
        },
        @{
            role = "assistant"
            content = "Arrr! Of course, me hearty! What can I do for ye?"
        },
        @{
            role = "user"
            content = "What's the best way to train a parrot?"
        }
    )
    model = "gpt"
} | ConvertTo-Json

# Define the headers
$headers = @{
    "Content-Type" = "application/json"
    "api-key" = $apiKey
    "x-client-id" = $clientId
}

# Make the API call
$response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body

# Output the response
$response