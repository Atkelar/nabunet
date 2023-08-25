using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Razor.TagHelpers;

namespace NabuNet
{
    public class TitleTagHelper
        : TagHelper
    {
        private readonly IServerConfigFactory _config;

        public TitleTagHelper(IServerConfigFactory config)
        {
            _config = config;
        }
        public string SubTitle { get; set; } = string.Empty;
        public override async Task ProcessAsync(TagHelperContext context, TagHelperOutput output)
        {
            var cfg = await _config.GetOrLoad();
            output.Content.Append(cfg.ServerName);
            if (!string.IsNullOrEmpty(SubTitle))
            {
                output.Content.Append(": ");
                output.Content.Append(SubTitle);
            }
        }
    }
}