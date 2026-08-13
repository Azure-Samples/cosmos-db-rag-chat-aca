using Microsoft.Azure.Cosmos;

namespace BlazorChatApp.Utils;

public static class CosmosSearchQuery
{
    public const string QueryText =
        "SELECT TOP 5 * FROM c ORDER BY VectorDistance(c.titleVector, @embedding)";

    public static QueryDefinition Create(ReadOnlyMemory<float> embedding)
    {
        return new QueryDefinition(QueryText)
            .WithParameter("@embedding", embedding.ToArray());
    }
}
