using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Razor.TagHelpers;

namespace NabuNet
{
    [HtmlTargetElement("markdown")]
    public class MarkdownTagHelper
        : TagHelper
    {
        public MarkdownTagHelper()
        {
        }

        public string Content { get; set; }

        public override async Task ProcessAsync(TagHelperContext context, TagHelperOutput output)
        {
            output.TagName = "div";
            output.Content.Clear();
            output.Content.AppendHtml(Markdig.Markdown.ToHtml(Content ?? ""));
        }
    }
}