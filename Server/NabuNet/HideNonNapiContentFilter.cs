using System.Linq;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace NabuNet
{
    internal class HideNonNapiContentFilter
        : IDocumentFilter
    {
        public void Apply(OpenApiDocument swaggerDoc, DocumentFilterContext context)
        {
            var pathsToRemove = swaggerDoc.Paths
                .Where(pathItem => !pathItem.Key.Contains("napi/"))
                .ToList();

            foreach (var item in pathsToRemove)
            {
                swaggerDoc.Paths.Remove(item.Key);
            }
        }
    }
}