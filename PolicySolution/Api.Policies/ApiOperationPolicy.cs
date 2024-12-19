using Azure.ApiManagement.PolicyToolkit.Authoring;
using Azure.ApiManagement.PolicyToolkit.Authoring.Expressions;

namespace Api.Policies;

[Document]
public class ApiOperationPolicyslfjasldfgjalsdfgjk : IDocument
{
    public void Inbound(IInboundContext context)
    {
        context.SetVariable("clientId", GetClientIdHeader(context.ExpressionContext));
       // context.SetVariable("clientTypesConfig", parameters);
        context.SetVariable("clientType", DetermineClientType(context.ExpressionContext));
    }
    public static string GetClientIdHeader(IExpressionContext context)
    {
        string clientId = context.Request.Headers.GetValueOrDefault("x-client-Id", "");
        return clientId;
    }

    public static string DetermineClientType(IExpressionContext context)
    {
        string clientId = GetClientIdHeader(context);
        Dictionary<string, string> parameters = new Dictionary<string, string>();
        parameters.Add("1234", "small");
        parameters.Add("5678", "large");

        foreach (var item in parameters)
        {
            if (item.Key == clientId)
            {
                return item.Value;
            }
        }
        return "small";
    }


    private static string GetUserId(IExpressionContext context)
        => context.User.Id;
}
